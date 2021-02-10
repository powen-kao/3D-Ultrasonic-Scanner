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
import ModelIO
import SceneKit.ModelIO

/**
 Composer does the frames matching between AR session and Ultrasonic probe.
 The matched frames are sent to (Metal) render for point cloud conversion.
 */

class ComposeController: NSObject, ARSessionDelegate, MTKViewDelegate, ProbeStreamerDelegate, RendererDelegate, ARRecorderDelegate{
    
    // delegate
    var delegate: ComposerDelegate?
    
    // Data sources
    private let arSession: ARSession
    private let probeStreamer: ProbeStreamer = ProbeStreamer()
    private var imagePixelBuffer: CVPixelBuffer?
    
    // device
    private var device: MTLDevice?
    
    // Renderer
    // WARNING: do not modifiy renderer from other controllers
    private(set) var renderer: Renderer?
    
    // output
    private var destination: MTKView?
    private var outputAssest: MDLAsset?
    private var scnView: SCNView
    
    // current infos
    private var currentARFrame: ARFrame?
    private var viewportSize = CGSize()
    private let voxelNode = SCNNode()
    private let imageVoxelNode = SCNNode()
    
    // Recorder and Player
    internal let recorder: ARRecorder = ARRecorder()
    internal var recorderState: ARRecorderState = .Init
    var recordingURL: URL{
        didSet{
            recorderURLChangedHandler()
        }
    }
    private let player: ARPlayer = ARPlayer()
    
    // capturing
    private var captureScope: MTLCaptureScope?
    private var shouldCapture = false;

    init(arSession: ARSession, destination: RenderDestinationProvider, scnView: SCNView) {
        self.arSession = arSession
        self.scnView = scnView
        self.recordingURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recording.txt") // defualt file path
        super.init()

        
        // Get default device
        guard let _device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        self.device = _device
        
        // Capturer for GPU tracing
        captureScope = MTLCaptureManager.shared().makeCaptureScope(device: device!)
        captureScope?.label = String.init(describing: self)


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
            renderer = Renderer(metalDevice: device!, renderDestination: view)
            renderer?.delegate = self
            renderer?.drawRectResized(size: view.bounds.size)
            self.destination = view
        }
        
        // Rest of the settings

        // Add geometries into SCNScene
        let scene = scnView.scene!
        scene.rootNode.addChildNode(voxelNode)
        scene.rootNode.addChildNode(imageVoxelNode)
        
        // Add gemeotry
        voxelNode.geometry = renderer?.voxelGeometry

        // Add contrains
        let cameraNode = scene.rootNode.childNode(withName: "camera", recursively: true)
        cameraNode?.constraints = [SCNLookAtConstraint(target: voxelNode)]
        
        
        // Open recording file
        recorder.open(folder: recordingURL, size: nil)
        recorder.delegate = self
        recorderState = .Ready
    }
    
    func startRecording() {
        recorderState = .Recording
        recorder.save(completeHandler: nil)
    }
    
    func stopRecording() {
        recorderState = .Busy
        recorder.save { [self] (recorder, success) in
            print("[Save success: \(success)] \(recorder)")
            recorder.close()
            recorderState = .Ready
        }
    }
    func replay() {
        player.read(folder: recordingURL)
    }
    
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
        self.delegate?.composer?(self, didUpdate: frame)
    }
    
    // MARK: - Probe Streamer
    func probe(streamer: ProbeStreamer, newFrame: UFrame) {
        
    }
    
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("will resize")
    }
    
    func draw(in view: MTKView) {
        // TODO: add offset between camera and probe
        guard let _frame = self.currentARFrame else {
            return
        }
        
        if (imagePixelBuffer != nil) {
            guard let _buffer = imagePixelBuffer else{
                return
            }
            captureScope?.begin()
            renderer?.render(frame: _frame, capturedImage: _buffer)
            if (recorderState == .Recording){
                recorder.append(frame: _frame)
            }
            captureScope?.end()
            if (self.shouldCapture){
                self.shouldCapture = false
                startCapture()
            }
        }
    }
    
    func postProcess() {
        // fill holes
        renderer?.fillHoles()
        
        // smoothing surface?
        
        // TODO: save file
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
    
    func recorderURLChangedHandler() {
        // Open file for recorder
        recorder.open(folder: recordingURL, size: nil)
    }
    
    // public functions
    func restOrigin() {
        self.renderer?.setCurrentARFrameAsReference()
    }
    
    // debug
    func captureNextFrame() {
        self.shouldCapture = true
    }
    private func startCapture(){
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = captureScope
        do {
            try captureManager.startCapture(with:captureDescriptor)
            captureManager.stopCapture()
        }
        catch
        {
            fatalError("error when trying to capture: \(error)")
        }
    }
    
    // MARK: Renderer delegate
    
    func renderer(_ renderer: Renderer, voxelGeometryUpdate voxelGeometry: SCNGeometry) {
        voxelNode.geometry = voxelGeometry
    }
    
    func renderer(_ renderer: Renderer, imageGeometryUpdate imageGeometry: SCNGeometry) {
        imageVoxelNode.geometry = imageGeometry
    }
    
    // MARK: Recorder delegate
    func recorder(_ recorder: ARRecorder, fullness: Float) {
        // TODO: remove later
        InfoViewController.shared?.progressBar.progress = fullness;
    }
    
}

enum ARRecorderState {
    case Init
    case Ready
    case Recording
    case Busy // writing or reading files
}


@objc protocol ComposerDelegate {
    @objc optional func composer(_ composer: ComposeController, didUpdate arFrame: ARFrame)
}

protocol ComposerObserver{
    func composer(message: String)
}

protocol ComposerInfoProvider {
    var recorder: ARRecorder {get}
    var recorderState: ARRecorderState {get}
}

extension ComposeController: ComposerInfoProvider{
    
}

