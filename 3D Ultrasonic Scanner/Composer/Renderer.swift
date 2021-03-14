//
//  Renderer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/4.
//

import Foundation
import ARKit
import Metal
import MetalKit
import os

class Renderer {    
    // To expose
    private(set) var voxelGeometry: SCNGeometry?
    private(set) var imageVoxelGeometry: SCNGeometry?
    private(set) var state: RendererState = .Initing
    var voxelInfo: VoxelInfo {
        get{
            return voxelInfoBuffer[0]
        }
    }
    var frameInfo: FrameInfo{
        get{
            return frameInfoBuffer[0]
        }
    }
    var delegate: RendererDelegate?
    
    // Required parameters
    var depth: Double?{ // cm
        didSet{
            updateVoxelInfo()
        }
    }
    var pixelDensityX: Double?{
        guard let _lastWidth = imageWidth else {
            return nil
        }
        return Double(_lastWidth) / probeWidth // pixel per meter
    }
    var pixelDensityY: Double?{
        guard let _depth = depth,
              let _lastHeight = imageHeight else {
            return nil
        }
        return Double(_lastHeight) / (_depth / 100.0)  // pixel per meter
    }
    
    // last unprojected dimension
    private var imageWidth: Int?
    private var imageHeight: Int?
    
    // Basic Metal objects
    private let device: MTLDevice
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private lazy var unprojectionPipelineState = makeComputePipelineState(name: "unproject")
    private lazy var fillingPipelineState = makeFillingPipelineState()!
    private lazy var previewPipelineState = makePreviewPiplineState()!
    private lazy var taskExecutionPipelineState = makeTaskExecutionPiplineState()!

    private lazy var textureCache: CVMetalTextureCache = makeTextureCache()
    
    // Rendering objects
    private let relaxedStencilState: MTLDepthStencilState
    private let depthStencilState: MTLDepthStencilState
    
    // Voxel parameters
    var voxelSize: simd_uint3?{
        didSet{
            checkVoxelBuffer()
        }
    }
    private var voxelCounts: UInt32 {
        get{
            guard voxelSize != nil else {
                return 0
            }
            return voxelSize!.x * voxelSize!.y * voxelSize!.z
        }
    }
    var voxelScale: Double = 1.0{
        didSet{
            updateVoxelInfo()
        }
    }
    var voxelStpeSize: Double? {
        // take the width density as voxel density since it's a constant
        if pixelDensityX != nil{
            return (1 / pixelDensityX!) * voxelScale // meter per voxel step
        }
        return nil
    }
    private var voxelOrigin: Float3?
    
    // Buffers
    private var voxelBuffer: MetalBuffer<Voxel>?
    private var voxelCopyBuffer: MetalBuffer<Voxel>?
    private var previewVoxelBuffer: MetalBuffer<Voxel>?
    private let frameInfoBuffer: MetalBuffer<FrameInfo>
    private var voxelInfoBuffer: MetalBuffer<VoxelInfo> // can be modified internally
    private var taskBuffer: MetalBuffer<Task>?
    
    // Textures
    private var imageTexture: CVMetalTexture?
            
    // Viewport related
    private var viewportSize = CGSize()
    private let orientation = UIInterfaceOrientation.portrait
    private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
    
    // Constrains
    private let inFlightSemaphore: DispatchSemaphore
    private var maxInFlightBuffers = 1
    private let maxPoints = 500000

    // Constant
    private var probeWidth = 0.047 // meter
    
    // debug use
    private let capturer: Capturer
    
    
    enum RendererState {
        case Initing
        case Ready
        case Processing
    }

    init(metalDevice: MTLDevice, voxelSize: simd_uint3?=nil) {
        self.device = metalDevice
        self.library = device.makeDefaultLibrary()!
        self.commandQueue = device.makeCommandQueue()!
        self.frameInfoBuffer = .init(device: device, count: 1, index: kFrameInfo.rawValue)
        self.voxelInfoBuffer = .init(device: device, count: 1, index: kVoxelInfo.rawValue)
        self.voxelSize = voxelSize
        inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
        capturer = Capturer.create(with: device)
        
        // rbg does not need to read/write depth
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!
        
        // setup depth test for point cloud
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        // init info
        voxelInfoBuffer.assign(makeDefautVoxelInfo())
    }
    
    
    /// Prepare buffer and redering info for specific image and configuration
    func prepare(for image: CVPixelBuffer, depth: Double, voxelSize: simd_uint3?=nil) -> Bool{
        
        // update input info
        self.depth = depth
        self.imageWidth = image.width()
        self.imageHeight = image.height()
        
        if voxelSize != nil{
            self.voxelSize = voxelSize
        }
        
        guard self.voxelSize != nil else {
            os_log("Preparation failed due to uninited voxel size.")
            return false
        }
        
        updateVoxelInfo()
    
        // Post-operations
        clearVoxel()
        
        return true
    }
    
    /**
    ### Convert captured image into 3D points clouds using transform from frame
     */
    func unproject (frame: ARFrameModel, image: CVPixelBuffer, finish: RenderCompleteCallback?){
                
        guard let _commandBuffer = commandQueue.makeCommandBuffer(),
              let _commandEncoder = _commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        
        // wait for Semaphore
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        state = .Processing
        
        // prepare for buffers and information for shader
        checkPreviewBuffer(image: image)
        checkVoxelBuffer()
        
        // Insert frame info
        frameInfoBuffer.assign(makeDefaultFrameInfo(frame: frame, image: image))
        
        // MARK: debug info printing for unprojection
        var kvPairs = [String: Any]()
        kvPairs["Position"] = self.voxelBuffer![Int(self.voxelCounts)/2].position
        kvPairs["color"] = self.voxelBuffer![0].color
        kvPairs["max"] = self.voxelInfoBuffer[0].axisMax
        kvPairs["min"] = self.voxelInfoBuffer[0].axisMin
        InfoViewController.shared?.frameInfoText = "\(Tools.pairsToString(items: kvPairs))"
        
        
        imageTexture = makeTexture(fromPixelBuffer: image, pixelFormat: .bgra8Unorm, planeIndex: 0)!
        var retainingTextures = [imageTexture]
        
        _commandBuffer.addCompletedHandler { [self] commandBuffer in
            state = .Ready
            
            // remove all reference to texture
            retainingTextures.removeAll()
            
            inFlightSemaphore.signal()
            
            finish?()
            // TODO: clean up
//            DispatchQueue.main.sync { [self] in
////                InfoViewController.shared?.frameInfoText = "GPU processing time: \((commandBuffer.gpuEndTime-commandBuffer.gpuStartTime)*1000) ms";
//                // # WARNING: the message is not sychronous
//            }
        }
        
        // TODO: replace frameInfo, ARFrame, gridBuffer with matching result
        // compute thread size
        let width = Int(frameInfo.imageWidth)
        let height = Int(frameInfo.imageHeight)
        
        let threadGroupSize = MTLSize(width: 1, height: 1, depth: 1)
        let threadGroupCount = getThreadGroupCount(threadGroupSize: threadGroupSize, gridSize: MTLSize(width: width, height: height, depth: 1))

        _commandEncoder.setComputePipelineState(unprojectionPipelineState!)
        _commandEncoder.setBuffer(frameInfoBuffer)
        _commandEncoder.setBuffer(voxelInfoBuffer)
        _commandEncoder.setBuffer(voxelBuffer!)
        _commandEncoder.setTexture(CVMetalTextureGetTexture(imageTexture!), index: Int(kTexture.rawValue))
        _commandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        _commandEncoder.endEncoding()
        
        _commandBuffer.commit()
    }
    
    /// Render image preview
    func renderPreview(frame: ARFrameModel, image: CVPixelBuffer, mode: PreviewDrawMode){
        
        guard let _commandBuffer = commandQueue.makeCommandBuffer(),
              let _commandEncoder = _commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        if (checkNeedUpdate(buffer: previewVoxelBuffer, idealCount: image.pixelCount())){
            previewVoxelBuffer = .init(device: device, count: image.pixelCount(), index: kImageVoxel.rawValue)
            
            self.imageVoxelGeometry = makeVoxelSCNGeometry(buffer: previewVoxelBuffer!)
            delegate?.renderer(self, imageGeometryUpdate: imageVoxelGeometry!)
            
            setARFrameAsReference(frame: frame)
        }
        
        // create FrameInfoBuffer from real-time AR frame (preview)
        let _previewFrameInfoBuffer = MetalBuffer<FrameInfo>.init(device: device, count: 1, index: kPreviewFrameInfo.rawValue)
    
        // create infomation for shader
        var _frameInfo = makeDefaultFrameInfo(frame: frame, image: image)!
        _frameInfo.mode = mode
        _previewFrameInfoBuffer.assign(_frameInfo)
        
        let _imageTexture = makeTexture(fromPixelBuffer: image, pixelFormat: .bgra8Unorm, planeIndex: 0)!
        // holder reference to texture to avoid delloac
        var retainingTextures = [_imageTexture]
        
        _commandBuffer.addCompletedHandler({_ in
            retainingTextures.removeAll()
        })
        
        // compute thread size
        let threadGroupSize = MTLSize(width: 8,height: 8, depth: 1)
        let threadGroupCount = getThreadGroupCount(threadGroupSize: threadGroupSize, gridSize: MTLSize(width: image.width(), height: image.height(), depth: 1))

        
        _commandEncoder.setComputePipelineState(previewPipelineState)
        _commandEncoder.setBuffer(previewVoxelBuffer!)
        _commandEncoder.setBuffer(_previewFrameInfoBuffer)
        _commandEncoder.setBuffer(voxelInfoBuffer)
        _commandEncoder.setTexture(CVMetalTextureGetTexture(_imageTexture), index: Int(kPreviewTexture.rawValue))
        _commandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        _commandEncoder.endEncoding()
        _commandBuffer.commit()
        
    }
    
    func fillHoles() {
        
        // make a copy of voxel metal buffer
        voxelCopyBuffer = .init(device: device, from: voxelBuffer!, index: kCopyVoxel.rawValue)
        
        // MARK: uncomment trigger() to enable frame capture on called
//        capturer.trigger()
        
        capturer.begin()
        
        
        guard let _commandBuffer = commandQueue.makeCommandBuffer(),
              let _commandEncoder = _commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        state = .Processing
        
        _commandBuffer.addCompletedHandler({ [self]_ in
            state = .Ready
            capturer.end()
            print("Filling Finished [\((_commandBuffer.gpuEndTime - _commandBuffer.gpuStartTime)*1000) ms]")
        })

        
        // compute thread size
        let threadGroupSize = MTLSize(width: 8,height: 8, depth: 8)
        let threadGroupCount = getThreadGroupCount(threadGroupSize: threadGroupSize,
                                                   gridSize: MTLSize(width: Int(voxelInfo.size.x),
                                                                     height: Int(voxelInfo.size.y),
                                                                     depth: Int(voxelInfo.size.z)))
        
        _commandEncoder.setComputePipelineState(fillingPipelineState)
        _commandEncoder.setBuffer(voxelBuffer!)
        _commandEncoder.setBuffer(voxelCopyBuffer!)
        _commandEncoder.setBuffer(voxelInfoBuffer)
        _commandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        _commandEncoder.endEncoding()
        _commandBuffer.commit()
    }
    
    func execute(task: Task, finish: RenderCompleteCallback? = nil) {
        guard let _commandBuffer = commandQueue.makeCommandBuffer(),
              let _commandEncoder = _commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        _commandBuffer.addCompletedHandler { _ in
            finish?()
        }
        
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 8)
        let threadGroupCount = getThreadGroupCount(threadGroupSize: threadGroupSize, gridSize: MTLSize(width: Int(voxelInfo.size.x),
                                                                                                       height: Int(voxelInfo.size.y),
                                                                                                       depth: Int(voxelInfo.size.z)))
        taskBuffer = .init(device: device, count: 1, index: kTask.rawValue)
        taskBuffer?.assign(task)
        
        
        _commandEncoder.setComputePipelineState(taskExecutionPipelineState)
        _commandEncoder.setBuffer(voxelBuffer!)
        _commandEncoder.setBuffer(taskBuffer!)
        _commandEncoder.setBuffer(frameInfoBuffer)
        _commandEncoder.setBuffer(voxelInfoBuffer)
        _commandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        _commandEncoder.endEncoding()
        
        _commandBuffer.commit()
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    
    func clearVoxel() {
        self.state = .Processing
        execute(task: Task(type: kT_ResetVoxels)){
            self.state = .Ready
        }
    }
}

private extension Renderer {
    func getThreadGroupCount(threadGroupSize: MTLSize, gridSize: MTLSize) -> MTLSize{
        var threadGroupCount = MTLSize()
        threadGroupCount.width  = (Int(gridSize.width) + threadGroupSize.width -  1) / threadGroupSize.width;
        threadGroupCount.height  = (Int(gridSize.height) + threadGroupSize.height -  1) / threadGroupSize.height;
        threadGroupCount.depth  = (Int(gridSize.depth) + threadGroupSize.depth -  1) / threadGroupSize.depth;
        return threadGroupCount
    }
    
    func makeComputePipelineState(name: String) -> MTLComputePipelineState?{
        guard let vertexFunction = library.makeFunction(name: name)
        else {
                return nil
        }
        return try? device.makeComputePipelineState(function: vertexFunction)
    }
    
    func makeFillingPipelineState() -> MTLComputePipelineState? {
        guard let vertexFunction = library.makeFunction(name: "holeFilling")
        else {
                return nil
        }
        return try? device.makeComputePipelineState(function: vertexFunction)
    }
    
    func makePreviewPiplineState() -> MTLComputePipelineState? {
        guard let vertexFunction = library.makeFunction(name: "renderPreview")
        else {
                return nil
        }
        return try? device.makeComputePipelineState(function: vertexFunction)
    }
    
    func makeTaskExecutionPiplineState() -> MTLComputePipelineState? {
        guard let vertexFunction = library.makeFunction(name: "executeTask")
        else {
                return nil
        }
        return try? device.makeComputePipelineState(function: vertexFunction)
    }
    
    
    func makeVoxelSCNGeometry(buffer: MetalBuffer<Voxel>) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(buffer: buffer.buffer,
                                       vertexFormat: .float3,
                                       semantic: .vertex,
                                       vertexCount: buffer.count,
                                       dataOffset: MemoryLayout<Voxel>.offset(of: \Voxel.position)!,
                                       dataStride: voxelBuffer!.stride)
        
        let colorSource = SCNGeometrySource(buffer: buffer.buffer,
                                            vertexFormat: .float4,
                                            semantic: .color,
                                            vertexCount: buffer.count,
                                            dataOffset: MemoryLayout<Voxel>.offset(of: \Voxel.color)!,
                                            dataStride: voxelBuffer!.stride)
        
        let element = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: buffer.count, bytesPerIndex: MemoryLayout<Int>.size)
        element.pointSize = 1
        element.maximumPointScreenSpaceRadius = 10
        element.minimumPointScreenSpaceRadius = 1
        
        
        let geometry = SCNGeometry(sources: [vertexSource, colorSource],
                                   elements: [element])
        
        return geometry
    }
    
    func makeTextureCache() -> CVMetalTextureCache {
        var cache: CVMetalTextureCache!
        _ = CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        return cache
    }
    
    func makeTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, 0, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }
    
    private func makeDefaultFrameInfo(frame: ARFrameModel, image: CVPixelBuffer) -> FrameInfo? {
        
        // Insert frame info
        var frameInfo = FrameInfo()
        let camera = frame.camera
        frameInfo.transform = camera.transform
        frameInfo.imageWidth = Int32(image.width())
        frameInfo.imageHeight = Int32(image.height())
        frameInfo.uIntrinsics = simd_float3x3.init(columns: ([Float(pixelDensityX ?? 3677), 0, 0],
                                                             [0, Float(pixelDensityY ?? 3677), 0],
                                                             [Float(image.width())/2.0, Float(image.height())/2.0, 1]))
        // transform that convert color to black and white
        frameInfo.colorSpaceTransform = simd_float4x4.init([0.333, 0.333, 0.333, 1],
                                                           [0.333, 0.333, 0.333, 1],
                                                           [0.333, 0.333, 0.333, 1],
                                                           [0, 0, 0, 1])
        frameInfo.uIntrinsicsInversed = frameInfo.uIntrinsics.inverse
        frameInfo.flipY = matrix_float4x4(
                            [1, 0, 0, 0],
                            [0, -1, 0, 0],
                            [0, 0, 1, 0],
                            [0, 0, 0, 1] )
        
        return frameInfo
    }
    
    private func makeDefautVoxelInfo() -> VoxelInfo {
        var voxelInfo = VoxelInfo()
        voxelInfo.axisMax = simd_float3(repeating: Float.leastNormalMagnitude)
        voxelInfo.axisMin = simd_float3(repeating: Float.greatestFiniteMagnitude)
        voxelInfo.state = kVInit
        voxelInfo.inversedTransform = matrix_identity_float4x4
        voxelInfo.transform = matrix_identity_float4x4
        voxelInfo.rotateToARCamera = rotateToARCamera
        voxelInfo.inversedRotateToARCamera = rotateToARCamera.inverse
        return voxelInfo
    }
    
    private func updateVoxelInfo() {
        guard voxelSize != nil,
              voxelStpeSize != nil else {
            return
        }
        
        voxelInfoBuffer[0].size = voxelSize!
        voxelInfoBuffer[0].stepSize = Float(voxelStpeSize!)
        voxelInfoBuffer[0].count = voxelCounts
        voxelInfoBuffer[0].centerizeTransform = simd_float4x4([1, 0, 0, -Float(voxelSize!.x)/2],
                                                              [0, 1, 0, -Float(voxelSize!.y)/2],
                                                              [0, 0, 1, 0],
                                                              [0, 0, 0, 1])
        voxelInfoBuffer[0].inversedCenterizeTransform = voxelInfo.centerizeTransform.inverse
    }
    
    static func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .landscapeLeft:
            return 180
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return -90
        default:
            return 0
        }
    }
    
    static func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        // flip to ARKit Camera's coordinate

        let rotationAngle = Float(cameraToDisplayRotation(orientation: .portrait)) * .degreesToRadian
        return matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
    
    func checkVoxelBuffer() {
        // realloc if nil or shape of voxel changed
        if voxelBuffer == nil || voxelBuffer?.count != Int(voxelCounts){
            voxelBuffer = nil // dealloc
            voxelBuffer = .init(device: device, count: Int(voxelCounts), index: kVoxel.rawValue)
            
            // update geometry
            self.voxelGeometry = makeVoxelSCNGeometry(buffer: voxelBuffer!)
            delegate?.renderer(self, voxelGeometryUpdate: voxelGeometry!)
        }
    }
    
    func checkPreviewBuffer(image: CVPixelBuffer) {
        if previewVoxelBuffer == nil || previewVoxelBuffer?.count != image.pixelCount(){
            previewVoxelBuffer = nil // dealloc
            previewVoxelBuffer = .init(device: device, count: image.pixelCount(), index: kImageVoxel.rawValue)
            
            // update geometry
            self.imageVoxelGeometry = makeVoxelSCNGeometry(buffer: previewVoxelBuffer!)
            delegate?.renderer(self, imageGeometryUpdate: imageVoxelGeometry!)
        }
    }
    
    func checkNeedUpdate(buffer: MetalBuffer<Voxel>?, idealCount: Int) -> Bool {
        guard buffer != nil,
              buffer!.count == idealCount else {
            return true
        }
        return false
    }
}

protocol RendererDelegate {
    func renderer(_ renderer: Renderer, voxelGeometryUpdate voxelGeometry: SCNGeometry)
    func renderer(_ renderer: Renderer, imageGeometryUpdate imageGeometry: SCNGeometry)
}

extension Renderer{
    func setARFrameAsReference(frame: ARFrameModel) {
        
        // take the current frame as all voxel's base transform
        self.voxelInfoBuffer[0].transform = frame.camera.transform
        self.voxelInfoBuffer[0].inversedTransform = frame.camera.transform.inverse
        self.voxelInfoBuffer[0].state = kVReady
    }
}

typealias RenderCompleteCallback = ()->()
