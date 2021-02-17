//
//  StaticProbe.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/14.
//

import Foundation
import AVFoundation
import UIKit

class StaticProbe: Probe {
    
    private let image: CVPixelBuffer?
    private(set) var file: URL?
    
    init(file: URL) {
        self.file = file
        self.image = UIImage(contentsOfFile: file.absoluteString)?.toCVPixelBuffer()
        super.init()
    }
    override func open() -> Bool {
        return true
    }
    override func close() {
        
    }
    override func start() {
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
        guard let _image = image else {
            return
        }
        delegate?.probe(self, new: UFrameModel(buffer: _image))
    }
    
}
