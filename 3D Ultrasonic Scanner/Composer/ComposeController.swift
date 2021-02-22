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
import os

/**
 Composer does the frames matching between AR session and Ultrasonic probe.
 The matched frames are sent to (Metal) render for point cloud unprojection.
 The frame composition is ultrasound-image-driven rather than ARFrame.
 */

class ComposeController: NSObject, ARSessionDelegate, ProbeDelegate, RendererDelegate, ARRecorderDelegate, ARPlayerDelegate{
    
    // Public properties
    var delegate: ComposerDelegate?
    private(set) var probeSource: ProbeSource = .Streaming // TODO: read from setting
    private(set) var arSource: ARSource = .RealtimeAR
    private(set) var composeState: ComposeState = .Idle {
        willSet (newState){
            if composeState != newState {
                delegate?.composer?(self, stateChanged: newState)
            }
        }
        didSet{
            if composeState == .Idle {
                self.arPlayer?.stop()
                self.probe?.stop()
                clear()
            }
        }
    }

    private var estimateDelay: Double = 0.1 // second
        
    // Data sources
    private let arSession: ARSession
    private(set) var probe: Probe?
    
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
    private var currentARFrame: ARFrameModel?
    private var currentPixelBuffer: CVPixelBuffer?
    private var viewportSize = CGSize()
    private let voxelNode = SCNNode()
    private let imageVoxelNode = SCNNode()

    
    // Recorder and Player
    internal let recorder: ARRecorder = ARRecorder()
    internal var recorderState: ARRecorderState = .Ready {
        willSet(newState){
            if newState != recorderState{
                delegate?.recordingState?(self, changeTo: newState)
            }
        }
    }

    var recordingURL: URL{
        didSet{
            recorderURLChangedHandler()
        }
    }
    private var arPlayer: ARPlayer?
    
    // capturing
    private var captureScope: MTLCaptureScope?
    private var shouldCapture = false;

    init(arSession: ARSession, scnView: SCNView) {
        self.arSession = arSession
        self.scnView = scnView
        self.recordingURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings") // default file path
        super.init()
        
//        switchARSource(source: arSource)
//        switchProbeSource(source: probeSource, folder: nil)
        
        // Get default device
        guard let _device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        self.device = _device
        
        // Create renderer with device
        renderer = Renderer(metalDevice: device!)
        
        // Capturer for GPU tracing
        captureScope = MTLCaptureManager.shared().makeCaptureScope(device: device!)
        captureScope?.label = String.init(describing: self)

        // Rest of the settings
        
        
        // Set delegate
        renderer?.delegate = self

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
//        recorderState = .Ready

    }
    
    /// Switch between different source. The folder parameter is only used in Static and Recording source
    func switchProbeSource(source: ProbeSource, folder: URL?){
        self.probeSource = source

        composeState = .Idle
        
        switch source {
            case .Video:
                guard let _file = folder?.appendingPathComponent("video.mov") else {
                    os_log(.debug, "Recording Probe load failed due to invalid path")
                    return
                }
                // Setup probe
                // TODO: use the fake probe now, but replace with real probe streamer in the future
                self.probe = RecorderProbe(file: _file)

            case .Image:
                guard let _file = folder?.appendingPathComponent("image.jpg") else {
                    os_log(.debug, "Static Probe load failed due to invalid path")
                    return
                }
                self.probe = StaticProbe(file: _file)

                break
            case .Streaming:
                // TODO: implement real-time streaming
                self.probe = StreamingProbe()
                break
        }
        
        os_log(.info, "Probe loaded from source : \(String(reflecting: source))")

        probe?.delegate = self
        // open probe
        guard probe?.open() == true else {
            os_log(.info, "Probe open failed")
            return
        }
        
        os_log(.info, "Probe opened success")
    }
    
    func switchARSource(source: ARSource) {
        arSource = source
        
        composeState = .Idle
        
        switch source {
            case .RealtimeAR:
                arPlayer = RealtimeARPlayer(session: arSession)
            case .RecordedAR:
                arPlayer = RecordedARPlayer(folder: recordingURL)
                break
        }
        
        guard arPlayer!.open() else {
            os_log("AR player open failed")
            return
        }
        
        os_log(.info, "AR player open success")
        arPlayer?.delegate = self
    }
    
    func postProcess() {
        // fill holes
        renderer?.fillHoles()
        
        // smoothing surface?
        
        // TODO: save file
    }
    
    
    func startRecording() {
//        arPlayer?.start()
        recorderState = .Recording
    }
    
    func stopRecording() {
//        arPlayer?.stop()
        recorderState = .Busy
        recorder.save { [self] (recorder, success) in
            print("[Save success: \(success)] \(recorder)")
            recorder.clear()
            recorderState = .Ready
        }
    }
    
    func startCompose(){
        probe?.start()
        arPlayer?.start()

        composeState = .WaitForFirstFrame
    }
    
    func stopCompose() {
        probe?.stop()
        arPlayer?.stop()
        clear()
        
        composeState = .Idle
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
    
    private func recorderURLChangedHandler() {
        // Open file for recorder
        recorder.open(folder: recordingURL, size: nil)
    }
    
    // public functions
    func restOrigin() {
        guard let _frame = currentARFrame else {
            return
        }
        self.renderer?.setARFrameAsReference(frame: _frame)
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
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("will resize")
    }
    
    // MARK: Renderer delegate
    func renderer(_ renderer: Renderer, voxelGeometryUpdate voxelGeometry: SCNGeometry) {
        voxelNode.geometry = voxelGeometry
    }
    
    func renderer(_ renderer: Renderer, imageGeometryUpdate imageGeometry: SCNGeometry) {
        imageVoxelNode.geometry = imageGeometry
    }
    
    // MARK: - Probe Delegate
    func probe(_ probe: Probe, new frame: UFrameProvider) {
        currentPixelBuffer = frame.pixelBuffer

        guard let _frame = self.currentARFrame else{
            return
        }
        
        if (composeState == .Ready){
            renderer?.unproject(frame: _frame, image: frame.pixelBuffer)
        }
    }
    
    func finished(_ probe: Probe) {
        composeState = .Idle
    }
    
    // MARK: ARPlayer delegate
    func player(_ player: ARPlayer, new frame: ARFrameModel) {
        currentARFrame = frame
        
        if (recorderState == .Recording){
            recorder.append(frame: frame)
        }
        
        guard let _pixelBuffer = currentPixelBuffer else {
            return
        }
        
        switch composeState {
            case .WaitForFirstFrame:
                restOrigin()
                composeState = .Ready
            case .Ready:
                renderer?.renderPreview(frame: frame, image: _pixelBuffer)
            default: break
        }
    }
    
    func finished(_ player: ARPlayer) {
        composeState = .Idle
    }
    
    // MARK: Recorder delegate
    func recorder(_ recorder: ARRecorder, fullness: Float) {
        // TODO: remove later
        InfoViewController.shared?.progressBar.progress = fullness;
    }
    
    private func clear(){
        // TODO: flush images in buffer
        self.currentARFrame = nil
        self.currentPixelBuffer = nil
    }
}

enum ProbeSource: Int {
    // keep the same order as in storyboard
    case Streaming
    case Video
    case Image
}

enum ARSource: Int {
    case RealtimeAR
    case RecordedAR
}

@objc enum ARRecorderState: Int {
//    case Init
    case Ready
    case Recording
    case Busy // writing or reading files
}

@objc enum ComposeState: Int {
    case Idle
    case WaitForFirstFrame  // waiting for first frame to take as reference frame
    case Ready
    case HoleFilling
}


@objc protocol ComposerDelegate {
    @objc optional func composer(_ composer: ComposeController, didUpdate arFrame: ARFrame)
    @objc optional func composer(_ composer: ComposeController, stateChanged: ComposeState)
    @objc optional func recordingState(_ composer: ComposeController, changeTo state: ARRecorderState)
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

