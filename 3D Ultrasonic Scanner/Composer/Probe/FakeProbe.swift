//
//  ProbeStreamer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/6.
//


import Foundation
import AVFoundation
import OSLog

/// Fake probe tha stream from a file instead of real-time video from scanner
class FakeProbe: Probe, AVPlayerItemOutputPullDelegate{
    
    // Assets
    private(set) var asset: AVAsset?
    private var itemOutput: AVPlayerItemVideoOutput?
    private var file: URL
    
    // Display link
    private var displayLink: CADisplayLink?
    private var framerate: Float = 60 // framerate of source
    var frameInterval: TimeInterval {
        TimeInterval(1 / framerate)
    }
    var playbackRate: Float = 1.0 {
        didSet{
            displayLink?.preferredFramesPerSecond = Int(playbackRate * Float(framerate))
        }
    }
    
    init(file: URL) {
        self.file = file
        self.asset = AVAsset(url: file)
        super.init()
        
        // extract video information
        let videoTrack = self.asset?.tracks(withMediaType: .video)[0]
        self.framerate = videoTrack!.nominalFrameRate
        
        os_log(.debug, "read vidoe file with framerate at \(self.framerate)")
    }
    
    override func open() -> Bool{
        guard let _asset = self.asset else {
            return false
        }
        
        // create new player output
        let avPlayerItem = AVPlayerItem(asset: _asset)
        itemOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: Probe.defaultPixelBufferAttributes as [String: Any])
        itemOutput!.setDelegate(self, queue: nil)
        avPlayerItem.add(itemOutput!)
        
        avPlayer = AVPlayer(playerItem: avPlayerItem)
        
        // setup display link
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkStep))
        self.displayLink?.add(to: .current, forMode: .default)
        
        return true
    }
    
    override func close() {
        
    }
    
    override func start(){
    
    }
    
    override func stop() {
        self.displayLink?.invalidate()
    }
    
    func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        
    }
    
    @objc func displayLinkStep(displaylink: CADisplayLink) {
        guard let _output = itemOutput else {
            return
        }
        
        let time = _output.itemTime(forHostTime: CACurrentMediaTime())
        if (_output.hasNewPixelBuffer(forItemTime: time)){
            guard let _buffer = _output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else {
                return
            }
            delegate?.probe(self, new: UFrameModel(buffer: _buffer))
        }
    }
    
}

