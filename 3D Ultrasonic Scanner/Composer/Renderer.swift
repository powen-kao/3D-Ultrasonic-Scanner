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


class Renderer {
    private let renderDestination: RenderDestinationProvider
    
    // To expose
    private(set) var scnGeometry: SCNGeometry?
    
    private let device: MTLDevice
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private lazy var unprojectionPipelineState = makeUnprojectionPipelineState()!
    private lazy var textureCache: CVMetalTextureCache = makeTextureCache()
    
    // Rendering objects
    private let relaxedStencilState: MTLDepthStencilState
    private let depthStencilState: MTLDepthStencilState
    
    // Voxel parameters
    let voxelSize = simd_int3(100, 100, 100)
    private var voxelCounts: Int32 {
        get{
            voxelSize.x * voxelSize.y * voxelSize.z
        }
    }
    private var voxelStpeSize = 0.00027195 // meter per voxel step
    private var voxelOrigin: Float3?
    private var voxelInfo: VoxelInfo = VoxelInfo()
    
    // ARFrame and CVPixelBuffer
    private var currentARFrame: ARFrame?
    private var currentCVPixelBuffer: CVPixelBuffer?
    private var imageWidth: Int{
        get{
            guard let _buffer = currentCVPixelBuffer else {
                return 0
            }
            return CVPixelBufferGetWidth(_buffer)
        }
    }
    private var imageHeight: Int{
        get{
            guard let _buffer = currentCVPixelBuffer else {
                return 0
            }
            return CVPixelBufferGetHeight(_buffer)
        }
    }
    private var imagePixelCount: Int {imageWidth * imageHeight}
    
    // Buffers
    private var voxelBuffer: MetalBuffer<Voxel>?
    private var gridBuffer: MetalBuffer<SIMD2<Float>>?
    private let frameInfoBuffer: MetalBuffer<FrameInfo>
    private let voxelInfoBuffer: MetalBuffer<VoxelInfo>
    
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

    // debug use
    private let capturer: Capturer
    private let debugInfoBuffer: MTLBuffer

    init(metalDevice: MTLDevice, renderDestination: RenderDestinationProvider) {
        self.renderDestination = renderDestination
        self.device = metalDevice
        self.library = device.makeDefaultLibrary()!
        self.commandQueue = device.makeCommandQueue()!
        self.frameInfoBuffer = .init(device: device, count: 1, index: kFrameInfo.rawValue)
        self.voxelInfoBuffer = .init(device: device, count: 1, index: kVoxelInfo.rawValue)
        self.debugInfoBuffer = device.makeBuffer(length: 100, options: []) as! MTLBuffer
        inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
        
        // rbg does not need to read/write depth
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!
        
        // setup depth test for point cloud
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        // init the max and min points with a extream value
        voxelInfo.axisMax = simd_float3(repeating: Float.leastNormalMagnitude)
        voxelInfo.axisMin = simd_float3(repeating: Float.greatestFiniteMagnitude)
        voxelInfo.state = kVInit
        
        
        capturer = Capturer.create(with: device)
        
        // Init values that require
        checkVoxelBuffer()

        self.scnGeometry = makeSCNGeometry() // init after buffer is created

    }
    
    func prepareForShader(){
        
        checkGridBuffer()
        checkVoxelBuffer()
        
        guard let _frame = currentARFrame else {
            return
        }
        
        // Insert frame info
        var frameInfo = FrameInfo()
        let camera = _frame.camera
//        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let viewMatrix = camera.viewMatrix(for: orientation)
        let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
        frameInfo.viewProjectionMatrix = projectionMatrix * viewMatrix
//        frameInfo.cameraToWorld = viewMatrixInversed * rotateToARCamera
        frameInfo.cameraTransform = camera.transform
        frameInfo.imageWidth = Int32(imageWidth)
        frameInfo.imageHeight = Int32(imageHeight)
        
        let imgfWidth = Float(imageWidth)
        let imgfHeight = Float(imageHeight)
        frameInfo.uIntrinsics = simd_float3x3.init(columns: ([3677, 0, 0],
                                                             [0, 3677, 0],
                                                             [imgfWidth/2.0, imgfHeight/2.0, 1]))
        frameInfo.uIntrinsicsInversed = frameInfo.uIntrinsics.inverse
        frameInfoBuffer.assign(frameInfo)
        
        // Insert Voxel info
        // TODO: modify reference instead of copy-modify-write
        voxelInfo = voxelInfoBuffer[0]
        voxelInfo.size = voxelSize
        voxelInfo.stepSize = Float(voxelStpeSize)
        voxelInfo.count = voxelCounts
        updateVoxelInfoBuffer()
        
    }
    
    /**
    ### Convert captured image into 3D points clouds using transform from frame
     */
    func render (frame: ARFrame, capturedImage: CVPixelBuffer){
        capturer.begin()

        
        // Pipeline: vertex (from 2D pixel to point cloud) -> (point cloud to Voxel) -> fragement (ignore the point with alpha value less than 0.1?)
        
        guard let descriptor = renderDestination.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)else{
            return
        }
        
        // wait for Semaphore
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        
        // overwrite the current frame and buffer
        currentARFrame = frame
        currentCVPixelBuffer = capturedImage
        
        // prepare for buffers and information for shader
        prepareForShader()

        
        // TODO: tryouts and remove later
//        let point = simd_float2(Float(imageWidth)/2.0, Float(imageHeight)/2.0)
//        let fInfo = frameInfoBuffer[0]
//        let local =  fInfo.uIntrinsicsInversed * simd_float3(point, 1)
//        let global = rotateToARCamera * fInfo.cameraTransform * simd_float4(simd_float3(local.x, local.y, 0), 1)
//
//        let tempRLocal = voxelInfo.inversedTransform * global
//        let rLocal = simd_float3(tempRLocal.x, tempRLocal.y, tempRLocal.z)
//
//        let vGridPosition = simd_int3 (rLocal / voxelInfo.stepSize) &+ voxelSize / 2 // shift to center
//
//        let xyArea = voxelSize.x * voxelSize.y;
//        let index = xyArea * vGridPosition.z + vGridPosition.y * voxelSize.x + vGridPosition.x
        
        
//        InfoViewController.shared?.frameInfoText = "\(rLocal.x) \n \(rLocal.y) \n \(rLocal.z) \n        \(vGridPosition) \n index: \(index)"
        

        var kvPairs = [String: Any]()
        kvPairs["Position"] = self.voxelBuffer![Int(self.voxelCounts)/2].position
        kvPairs["color"] = self.voxelBuffer![0].color
        kvPairs["max"] = self.voxelInfoBuffer[0].axisMax
        kvPairs["min"] = self.voxelInfoBuffer[0].axisMin
        
        InfoViewController.shared?.frameInfoText = "\(Tools.pairsToString(items: kvPairs))"
        // TODO: retaining texture?
        imageTexture = makeTexture(fromPixelBuffer: capturedImage, pixelFormat: .bgra8Unorm, planeIndex: 0)!
        var retainingTextures = [imageTexture]
        
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            self?.capturer.end()
            
            // remove all reference to texture
            retainingTextures.removeAll()
            
            // take center of voxels as reference for origin of voxels if is first frame
            if (self!.voxelInfo.state == kVInit){
                let infoBuffer = self!.voxelInfoBuffer[0]
                let center = (infoBuffer.axisMax + infoBuffer.axisMin) / 2.0
                // take the first reliable frame as all voxel's base transform
                self!.voxelInfo.transform = (self!.currentARFrame?.camera.transform)!
                self!.voxelInfo.inversedTransform = self!.voxelInfo.transform.inverse
                self!.voxelInfo.state = kVReady
                self!.updateVoxelInfoBuffer()
                
                // increase the rendering
//                self!.maxInFlightBuffers = 3
            }
            if let self = self {
                self.inFlightSemaphore.signal()
            }
            
            DispatchQueue.main.sync { [self] in
//                InfoViewController.shared?.frameInfoText = "GPU processing time: \((commandBuffer.gpuEndTime-commandBuffer.gpuStartTime)*1000) ms";
                // # WARNING: the message is not sychronous
            }
        }

//        commandEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(Float(viewportSize.width)), height: Double(viewportSize.height), znear: 0, zfar: 1))
        commandEncoder.setDepthStencilState(relaxedStencilState)
        commandEncoder.setRenderPipelineState(unprojectionPipelineState)
        commandEncoder.setVertexBuffer(gridBuffer!)
        commandEncoder.setVertexBuffer(frameInfoBuffer)
        commandEncoder.setVertexBuffer(voxelInfoBuffer)
        commandEncoder.setVertexBuffer(voxelBuffer!)
        commandEncoder.setVertexBuffer(debugInfoBuffer, offset: 0, index: Int(kDebugInfo.rawValue))
        commandEncoder.setVertexTexture(CVMetalTextureGetTexture(imageTexture!), index: Int(kTexture.rawValue))
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridBuffer!.count)
        commandEncoder.endEncoding()
        
        commandBuffer.present(renderDestination.currentDrawable!)
        commandBuffer.commit()
    }
    
    func draw() {
        
        
        
    }
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    

}

private extension Renderer {
    func makeUnprojectionPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "unprojectVertex")
//              let fragmentFunction = library.makeFunction(name: "particleFragment")
        else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
//        descriptor.fragmentFunction = fragmentFunction
//        descriptor.isRasterizationEnabled = true

        descriptor.isRasterizationEnabled = false
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        
        // for fragement
//        descriptor.colorAttachments[0].isBlendingEnabled = true
//        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
//        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch{
            print("\(error)")
            return nil
        }
    }
    
    func makeSCNGeometry() -> SCNGeometry {
        let buffer = voxelBuffer!.buffer
        let vertexSource = SCNGeometrySource(buffer: buffer ,
                                       vertexFormat: .float3,
                                       semantic: .vertex,
                                       vertexCount: Int(self.voxelCounts),
                                       dataOffset: MemoryLayout<Voxel>.offset(of: \Voxel.position)!,
                                       dataStride: voxelBuffer!.stride)
        
        let colorSource = SCNGeometrySource(buffer: buffer,
                                            vertexFormat: .float4,
                                            semantic: .color,
                                            vertexCount: Int(self.voxelCounts),
                                            dataOffset: MemoryLayout<Voxel>.offset(of: \Voxel.color)!,
                                            dataStride: voxelBuffer!.stride)
        
        let element = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: Int(voxelCounts), bytesPerIndex: MemoryLayout<Int>.size)
        element.pointSize = 1
        element.maximumPointScreenSpaceRadius = 10
        element.minimumPointScreenSpaceRadius = 1
        
        
        let geometry = SCNGeometry(sources: [vertexSource, colorSource],
                                   elements: [element])
        
        return geometry
    }
    
    func makeTextureCache() -> CVMetalTextureCache {
        var cache: CVMetalTextureCache!
        let status = CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        return cache
    }
    
    func makeVoxelGrid(size: SIMD3<Int>){
        
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
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
//        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
        return flipYZ
    }
    
    func checkVoxelBuffer() {
        // realloc if nil or shape of voxel changed
        if voxelBuffer == nil || voxelBuffer?.count != Int(voxelCounts){
            voxelBuffer = nil // dealloc
            voxelBuffer = .init(device: device, count: Int(voxelCounts), index: kVoxel.rawValue)
        }
    }
    func checkGridBuffer() {
        // realloc if nil or shape of image changed
        if gridBuffer == nil || gridBuffer?.count != imagePixelCount{
            gridBuffer = nil
            gridBuffer = .init(device: device, count: imagePixelCount, index: kGridPoint.rawValue)
        }
    }
    
    func updateVoxelInfoBuffer() {
        voxelInfoBuffer.assign(voxelInfo)
    }
}

// MARK: - RenderDestinationProvider

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}
extension MTKView: RenderDestinationProvider {
    
}

