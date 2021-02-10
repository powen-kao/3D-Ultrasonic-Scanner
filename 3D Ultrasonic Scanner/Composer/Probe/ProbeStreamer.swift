//
//  ProbeStreamer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/6.
//


import Foundation
import CoreVideo

class ProbeStreamer: NSObject {
    override init() {
        // TODO: need API information to implement the protocl

    }
}

protocol ProbeStreamerDelegate {
    func probe(streamer: ProbeStreamer, newFrame: UFrame)
}


/**
 Ultrasonic Image Frame
 */

struct UFrame: UFrameProvider{
    var timestamp: Date?
    var pixelBuffer: CVPixelBuffer{
        didSet{
            timestamp = Date.init(timeIntervalSinceNow: NSTimeIntervalSince1970)
        }
    }
}

protocol UFrameProvider{
    var timestamp: Date? { get }
    var pixelBuffer: CVPixelBuffer { get set }
}
