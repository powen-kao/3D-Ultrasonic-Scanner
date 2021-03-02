//
//  StaticProbe.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/14.
//

import Foundation
import AVFoundation
import UIKit
import os

class StaticProbe: Probe {
    
    private(set) var file: URL?
    private var image: UIImage?
    private var pixelBuffer: CVPixelBuffer?
    
    private var startTimestamp:TimeInterval?
    
    init?(file: URL) {
        self.file = file

        super.init()

        guard let _data = try? Data(contentsOf: file) else {
            os_log("[File not found] \(file)")
            return nil
        }
        self.isFileBased = true
        self.image = UIImage(data: _data)
        self.pixelBuffer = self.image?.toCVPixelBuffer()
    }
    
    override func open() -> Bool {
        return pixelBuffer != nil
    }
    
    override func close() {
        
    }
    override func start() {
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
        guard let _image = pixelBuffer else {
            return
        }
        delegate?.probe(self, new: UFrameModel(buffer: _image, itemTime: Date().timeIntervalSince1970 - startTimestamp!))
    }
    
}
