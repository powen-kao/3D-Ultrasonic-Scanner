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
    
    private let device: MTLDevice
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private lazy var unprojectionPipelineState = makeUnprojectionPipelineState()!
    
    
    // Rendering objects
    private let relaxedStencilState: MTLDepthStencilState
    private let depthStencilState: MTLDepthStencilState
    
    
    // Buffers
    private var voxelBuffer: MetalBuffer<Voxel>?
            
    // Viewport related
    private var viewportSize = CGSize()
    private let orientation = UIInterfaceOrientation.portrait
    private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
    
    
    private let inFlightSemaphore: DispatchSemaphore
    private let maxInFlightBuffers = 3
    private let maxPoints = 500000
    private let voxelSize = SIMD3<Int>(100, 100, 100)
    private lazy var voxelCounts = voxelSize.x * voxelSize.y * voxelSize.z
    

    init(metalDevice: MTLDevice, renderDestination: RenderDestinationProvider) {
        device = metalDevice
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
                
        self.renderDestination = renderDestination
        
        // rbg does not need to read/write depth
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!
        
        // setup depth test for point cloud
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
    }
    
    /**
    ### Convert captured image into 3D points clouds using transform from frame
     */
    func render (frame: ARFrame, capturedImage: CVPixelBuffer){
        // Pipeline: vertex (from 2D pixel to point cloud) -> (point cloud to Voxel) -> fragement (ignore the point with alpha value less than 0.1?)
        
        guard let descriptor = renderDestination.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)else{
            return
        }
        let imgWidth = CVPixelBufferGetWidth(capturedImage)
        let imgHeight = CVPixelBufferGetHeight(capturedImage)
        let imgPixelCount = imgWidth * imgHeight

        let gridBuffer: MetalBuffer<SIMD2<Float>> = .init(device: device, count: imgPixelCount, index: kGridPoint.rawValue)
        let frameInfoBuffer: MetalBuffer<FrameInfo> = .init(device: device, count: 1, index: kFrameInfo.rawValue)
        
        if voxelBuffer == nil || voxelBuffer?.count != imgPixelCount{
            voxelBuffer = nil // dealloc
            voxelBuffer = .init(device: device, count: imgPixelCount, index: kVoxel.rawValue)
        }
        
        // Coordinate conversion
        var frameInfo = FrameInfo()
        let camera = frame.camera
//        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let viewMatrix = camera.viewMatrix(for: orientation)
        let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
        frameInfo.viewProjectionMatrix = projectionMatrix * viewMatrix
        frameInfo.localToWorld = viewMatrixInversed * rotateToARCamera
        frameInfo.imageWidth = Int32(imgWidth)
        frameInfo.imageHeight = Int32(imgHeight)
        frameInfoBuffer.assign(frameInfo)
        
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
            
            DispatchQueue.main.sync { [self] in
                InfoViewController.shared?.frameInfoText = "GPU processing time: \((commandBuffer.gpuEndTime-commandBuffer.gpuStartTime)*1000) ms";
            }
        }
        
//        let manager = MTLCaptureManager.shared()
//        do {
//            let d = MTLCaptureDescriptor.init()
//            d.captureObject = device
//            try manager.startCapture(with: d)
//        } catch{
//            print("\(error)")
//        }
        commandEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(Float(viewportSize.width)), height: Double(viewportSize.height), znear: 0, zfar: 1))
        commandEncoder.setDepthStencilState(relaxedStencilState)
        commandEncoder.setRenderPipelineState(unprojectionPipelineState)
        commandEncoder.setVertexBuffer(gridBuffer)
        commandEncoder.setVertexBuffer(frameInfoBuffer)
        commandEncoder.setVertexBuffer(voxelBuffer!)
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridBuffer.count)
        commandEncoder.endEncoding()
        
        commandBuffer.present(renderDestination.currentDrawable!)
        commandBuffer.commit()
        
//        manager.stopCapture()
    }
    
    func draw() {
        
        
        
    }
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    

}

private extension Renderer {
    func makeUnprojectionPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "unprojectVertex"),
              let fragmentFunction = library.makeFunction(name: "particleFragment") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.isRasterizationEnabled = true

//        descriptor.isRasterizationEnabled = false
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        
        // for fragement
//        descriptor.colorAttachments[0].isBlendingEnabled = true
//        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
//        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)

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
        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
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

