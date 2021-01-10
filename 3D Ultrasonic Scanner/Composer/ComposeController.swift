//
//  Composer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/4.
//

import Foundation
import ARKit
import Metal
import MetalKit

/**
 Composer does the frames matching between AR session and Ultrasonic probe.
 The matched frames are sent to (Metal) render for point cloud conversion.
 */

class ComposeController: NSObject, ARSessionDelegate, ProbeStreamerDelegate, MTKViewDelegate{
    
    // Data sources
    private let arSession: ARSession
    private let probeStreamer: ProbeStreamer = ProbeStreamer()
    private var imagePixelBuffer: CVPixelBuffer?
    
    // Renderer
    private var renderer: Renderer?
    
    // output
    private var destination: MTKView?
    
    private var currentARFrame: ARFrame?
    private var viewportSize = CGSize()
    

    init(arSession: ARSession, destination: RenderDestinationProvider) {
        self.arSession = arSession
        super.init()

        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        arSession.delegate = self
        
        // Set the view to use the default device
        if let view = destination as? MTKView {
            view.device = device
            
            view.backgroundColor = UIColor.clear
            // we need this to enable depth test
            view.depthStencilPixelFormat = .depth32Float
            view.contentScaleFactor = 1
            view.delegate = self

            // Configure the renderer to draw to the view
            renderer = Renderer(metalDevice: device, renderDestination: view)
            if (renderer == nil){
                // call observer
                return
            }
            renderer?.drawRectResized(size: view.bounds.size)
            self.destination = view
        }
    }
    
    //    func findClosestARFrame() -> ARFrame{
    //        return nil
    //    }
    
    
    func loadImage(image: UIImage) {
        self.imagePixelBuffer = image.toCVPixelBuffer()
    }
    
    func testRender() {
        guard let _buffer = imagePixelBuffer else {
            return
        }
        renderer?.render(frame: arSession.currentFrame!, capturedImage: _buffer)
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.currentARFrame = frame
    }
    
    // MARK: - Probe Streamer
    func probe(streamer: ProbeStreamer, newFrame: UFrame) {
        
    }
    
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("will resize")
    }
    
    func draw(in view: MTKView) {
        if (imagePixelBuffer != nil) {
            guard let _buffer = imagePixelBuffer,
                  let _frame = self.currentARFrame
            else{
                return
            }
            
            renderer?.render(frame: _frame, capturedImage: _buffer)
        }
    }

}

extension ARFrame: Comparable{
    public static func < (lhs: ARFrame, rhs: ARFrame) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
    public static func > (lhs: ARFrame, rhs: ARFrame) -> Bool{
        return lhs.timestamp > rhs.timestamp
    }
}


extension ComposeController{
    

}

protocol ComposerObserver{
    func composer(message: String)
}


