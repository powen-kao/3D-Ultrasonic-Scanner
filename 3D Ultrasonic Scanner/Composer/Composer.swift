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
import NIO
import os

/**
 Composer does the frames matching between AR session and Ultrasonic probe.
 The matched frames are sent to (Metal) render for point cloud unprojection.
 The frame composition is ultrasound-image-driven rather than ARFrame.
 */

class Composer: NSObject, ARSessionDelegate, ProbeDelegate, RendererDelegate, ARRecorderDelegate, ARPlayerDelegate{
    
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
    
    // Device
    private var device: MTLDevice?

    // Delay between probe and AR frame
    // TODO: remove this later when frame matching is applied
    private var delay: Double = 0.1 // seconds
    
    // Buffers that allows smooth streaming
    private let bufferSize = 5  // frames
    private var bufferDelay: Float { // seconds
        Float(bufferSize) / Float(framerate)
    }
    private lazy var bufferDelayCompensationSize: Int = { [self] in
        Int(delay / Double(framerate)) + 1
    }()
    private lazy var probeFrameBuffer = CircularBuffer<UFrameModel>(initialCapacity: bufferSize)
    private lazy var arFrameBuffer = CircularBuffer<ARFrameModel>(initialCapacity: bufferSize + bufferDelayCompensationSize)
    private var baseTimestamp: TimeInterval?
    
    // Data sources
    let arSession: ARSession
    private var probe: Probe?
    private var arPlayer: ARPlayer?
    
    // DisplayLink
    var displayLink: CADisplayLink?
    var framerate: Int = UIScreen.main.maximumFramesPerSecond  // frames per second
        
    // Renderer
    private(set) var renderer: Renderer?
    var voxelSize: simd_uint3?{
        didSet{
            renderer?.voxelSize = self.voxelSize
        }
    }
    var voxelStepScale = 1.0{
        didSet{
            renderer?.voxelScale = self.voxelStepScale
        }
    }
    var imageDepth: Double? {
        didSet{
            renderer?.depth = self.imageDepth
        }
    }
    var displacement: simd_float3 = simd_float3(0, 0, 0){
        didSet{
            renderer?.displacement = self.displacement
        }
    }
    
    var timeShift: Float = 0
    var fixedDelay: Float = 0
    
    // output
    private var outputAssest: MDLAsset?
    private var scnView: SCNView
    
    // current infos
    private var currentARFrame: ARFrameModel?
    private var currentPixelBuffer: CVPixelBuffer?
    private var viewportSize = CGSize()
    private let voxelNode = SCNNode()
    private let imageVoxelNode = SCNNode()
    
    // Recorder
    internal let recorder: ARRecorder = ARRecorder()
    internal var recorderState: ARRecorderState = .Ready {
        willSet(newState){
            if newState != recorderState{
                delegate?.recordingState?(self, changeTo: newState)
            }
        }
    }
    var recordingURL: URL?{
        didSet{
            recorderURLChangedHandler()
        }
    }
    
    // capturing
    private var captureScope: MTLCaptureScope?
    private var shouldCapture = false;
    

    init(arSession: ARSession, scnView: SCNView) {
        self.arSession = arSession
        self.scnView = scnView
        super.init()
        
        // Get default device
        guard let _device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        self.device = _device
        
        // Create renderer with device
        renderer = Renderer(metalDevice: device!, voxelSize: voxelSize)
        
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
        recorder.delegate = self

    }
    
    /// Switch between different source. The folder parameter is only used in Static and Recording source
    func switchProbeSource(source: ProbeSource){
        self.probeSource = source
        
        guard let _url = recordingURL,
              let _path = URL(string: _url.absoluteString) else {
                os_log(.debug, "Probe load failed due to invalid path")
                return
        }

        composeState = .Idle
        
        switch source {
            case .Video:
                // Setup probe
                // TODO: use the fake probe now, but replace with real probe streamer in the future
                self.probe = RecorderProbe(file: _path.appendingPathComponent("video.mov"))

            case .Image:
                self.probe = StaticProbe(file: _path.appendingPathComponent("image.jpg"))

                break
            case .Streaming:
                // TODO: implement real-time streaming
                self.probe = StreamingProbe()
                break
        }
        
        guard self.probe != nil else {
            os_log(.debug, "Probe init failed")
            return
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
        
        guard let _url = recordingURL else {
            os_log(.debug, "AR Source load failed due to invalid path")
            return
        }
        
        switch source {
            case .RealtimeAR:
                arPlayer = RealtimeARPlayer(session: arSession)
            case .RecordedAR:
                arPlayer = RecordedARPlayer(folder: _url)
                break
        }
        guard arPlayer != nil else {
            os_log("AR player init failed")
            return
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
        recorderState = .Recording
    }
    
    func stopRecording() {
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
        
        makeDisplayLink(block: nil)
    }
    
    func stopCompose() {
        composeState = .Idle
        
        removeDisplayLink()
        
        clear()
    }
    
    private func compose() {
        // State check
        guard composeState == .Ready,
              arFrameBuffer.count > 0,
              probeFrameBuffer.count > 0 else {
            return
        }
        
        // Stage: Drop image frames that is not possible to match
        var uFrame: UFrameModel?
        var itemTime: TimeInterval?
        while probeFrameBuffer.count > 0 {
            uFrame = probeFrameBuffer.first
            itemTime = uFrame?.itemTime!
            
            guard let imageTs = probeTimestamp(itemTime: itemTime!),
                  let arTs = arFrameBuffer.first?.timestamp else {
                break
            }

            if imageTs < arTs {
                // not possible to match, so drop frame
                probeFrameBuffer.removeFirst()
            }else{
                break // continue to matching stage
            }
        }
                
        // Stage: Match frame
        guard let _uFrame = uFrame,
              let index = findARFrameIndex(with: _uFrame, itemTime: itemTime!) else {
            // no image to match
            // no match frame found
            return
        }
                
        // Stage: Send to unprojection
        let frame = arFrameBuffer[offset: index]
        
        renderer?.unproject(frame: frame, image: _uFrame.pixelBuffer, finish: {
            // Remove the ARFrames that are ealier than current ARFrame
            // TODO: will this invalidate the image buffer?
        })
        
        if arFrameBuffer.count > index{
            self.arFrameBuffer.removeFirst(index)
        }
        
        if probeFrameBuffer.count > 0 {
            self.probeFrameBuffer.removeFirst()
        }
  
    }
    
    /// FInd the closest ARFrame that match the timestamp of Ultrasound image.
    /// Returns the index of found image in buffer, otherwise nil is returned
    private func findARFrameIndex(with uframe: UFrameModel, itemTime: TimeInterval) -> Int?{
        var minDistance: Double = .greatestFiniteMagnitude
        var index: Int? = nil
        for (_index, _frame) in arFrameBuffer.enumerated() {
            // TODO: check iteration starting point
            let distance = abs(_frame.timestamp - probeTimestamp(itemTime: itemTime)!)
            if distance < minDistance{
                // check whether is close enough
                minDistance = distance
                index = _index
            } else{
                // the distance should be decreasing and then increase again.
                // therefore we break right after we relize that the current distance is larger than minimun distance which indicate that we are on the up hill of the curve
                break
            }
        }
        
        if index != nil {
            // distance is larger than a frame interval
            // then match not found
            return index
        }
        
        // frame not found
        return nil
        
    }
    
    /// TImstamps that consider the fixed delay and time shift between probe streaming and AR frames
    private func probeTimestamp(itemTime: TimeInterval) -> TimeInterval?{
        // compute the timestamp based on timestamp of first ARPlayer frame
        guard baseTimestamp != nil else {
            return nil
        }
        return baseTimestamp! + TimeInterval(fixedDelay) + TimeInterval(timeShift) + itemTime
        
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

extension Composer: DisplayLinkable{
    func makeDisplayLink(block: DisplayLinkCallback?) {
        if probe != nil {
            framerate = probe!.framerate
        }
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkStep))
        self.displayLink?.preferredFramesPerSecond = framerate
        self.displayLink?.add(to: .current, forMode: .default)
    }
    
    func removeDisplayLink() {
        self.displayLink?.invalidate()
    }
    
    @objc
    func displayLinkStep(){
        compose()
    }
}


extension Composer{
    
    private func recorderURLChangedHandler() {
        guard let _url = recordingURL else {
            return
        }
        
        // Open file for recorder
        recorder.open(folder: _url, size: nil)
        
        // switch source will reopen probe and AR with new URL
        switchProbeSource(source: probeSource)
        switchARSource(source: arSource)
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

        if probeFrameBuffer.capacity <= 0 {
            os_log(.error, "Probe frame buffer is full")
        }
        
        probeFrameBuffer.append(frame as! UFrameModel)
        switch composeState {
            case .Buffering:
                checkReady()
                break
            case .Ready:
                break
            default: break
        }
    }
    
    func finished(_ probe: Probe) {
        composeState = .Idle
    }
    
    // MARK: - ARPlayer delegate
    func player(_ player: ARPlayer, new frame: ARFrameModel) {

        currentARFrame = frame

        if arFrameBuffer.capacity <= 0{
            os_log(.error, "AR frame buffer is full")
        }
        arFrameBuffer.append(frame)
        
        // Recorder update
        if (recorderState == .Recording){
            recorder.append(frame: frame)
        }
        
        // Draw preview
        guard let _pixelBuffer = currentPixelBuffer else {
            return
        }
        if probeSource == .Streaming {
            renderer?.renderPreview(frame: frame, image: _pixelBuffer, mode: kPD_TransparentBlack)
        } else{
            renderer?.renderPreview(frame: frame, image: _pixelBuffer, mode: kPD_DrawAll)
        }
        
        // State switching
        switch composeState {
            case .WaitForFirstFrame:
                
                restOrigin()
                baseTimestamp = frame.timestamp
                
                let success = renderer?.prepare(for: _pixelBuffer, depth: imageDepth!, voxelSize: voxelSize)
                if success ?? false{
                    composeState = .Buffering
                }
            case .Buffering:
                checkReady()
                break
            case .Ready: break

            default: break
        }
    }
    
    
    func clearVoxel() {
        renderer?.clearVoxel()
    }
    
    private func checkReady(){
        guard arFrameBuffer.count > bufferDelayCompensationSize,
              probeFrameBuffer.count > 1 else {
            return
        }
        
        composeState = .Ready
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
        self.arFrameBuffer.removeAll()
        self.probeFrameBuffer.removeAll()
    }
}


@objc enum ProbeSource: Int, Codable {
    // keep the same order as in storyboard
    case Streaming
    case Video
    case Image
}

@objc enum ARSource: Int, Codable {
    case RealtimeAR
    case RecordedAR
}



@objc enum ARRecorderState: Int {
    case Ready
    case Recording
    case Busy // writing or reading files
}

@objc enum ComposeState: Int {
    case Idle
    case WaitForFirstFrame  // waiting for first frame to take as reference frame
    case Buffering // collecting some frame to guarentee smooth frame matching
    case Ready // composer is ready to match frame
    case HoleFilling // filling holes
}


@objc protocol ComposerDelegate {
    @objc optional func composer(_ composer: Composer, didUpdate arFrame: ARFrame)
    @objc optional func composer(_ composer: Composer, stateChanged: ComposeState)
    @objc optional func recordingState(_ composer: Composer, changeTo state: ARRecorderState)
}

protocol ComposerObserver{
    func composer(message: String)
}

protocol ComposerInfoProvider {
    var recorder: ARRecorder {get}
    var recorderState: ARRecorderState {get}
}

extension Composer: ComposerInfoProvider{
    
}

