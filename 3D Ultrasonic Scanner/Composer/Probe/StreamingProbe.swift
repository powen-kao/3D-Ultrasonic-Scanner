//
//  StreamingProbe.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/22.
//

import Foundation
import AVFoundation
import UIKit

class StreamingProbe: Probe {
    
    var image: CVPixelBuffer?
    
    private var startTimestamp:TimeInterval?

    override func open() -> Bool{
        guard let _image = UIImage(named: "ar_placeholder")?.toCVPixelBuffer() else {
            return false
        }
        image = _image
        return true
    }
    
    override func close() {
        removeDisplayLink()
    }
    
    override func start(){
        startTimestamp = Date().timeIntervalSince1970

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
    
    @objc func displayLinkStep(displaylink: CADisplayLink) {
        // provide static placeholder
        delegate?.probe(self, new: UFrameModel(buffer: image!, itemTime: Date().timeIntervalSince1970 - startTimestamp!))
    }
}
