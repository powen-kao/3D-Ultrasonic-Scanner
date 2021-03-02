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
class RecorderProbe: Probe, AVPlayerItemOutputPullDelegate{
    
    // Assets
    private(set) var asset: AVAsset?
    private var itemOutput: AVPlayerItemVideoOutput?
    private var file: URL
    
    
    private var player: AVPlayer?

    
    var frameInterval: TimeInterval {
        TimeInterval(1 / Double(framerate))
    }
    
    init? (file: URL) {
        self.file = file
        self.asset = AVAsset(url: file)
        super.init()
        
        guard asset!.isReadable else {
            return nil
        }
        
        self.isFileBased = true
        
        // extract video information
        let videoTrack = self.asset?.tracks(withMediaType: .video)[0]
        self.framerate = Int(videoTrack!.nominalFrameRate)

        os_log(.info, "read vidoe file with framerate at \(self.framerate)")
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
        
        player = AVPlayer(playerItem: avPlayerItem)

        return true
    }
    
    override func close() {
        removeDisplayLink()
    }
    
    override func start(){
        player?.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
        player?.play()
        
        makeDisplayLink(block: nil)
    }
    
    override func stop() {
        removeDisplayLink()
    }
    
    override func makeDisplayLink(block: Probe.DisplayLinkCallback?) {
        // setup display link
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkStep))
        self.displayLink?.add(to: .current, forMode: .default)
    }

    override func removeDisplayLink() {
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
            delegate?.probe(self, new: UFrameModel(buffer: _buffer, itemTime: TimeInterval(time.seconds)))
        }
    }
    
}

