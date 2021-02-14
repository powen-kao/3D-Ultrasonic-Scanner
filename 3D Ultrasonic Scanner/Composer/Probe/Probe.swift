//
//  DeviceBase.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/10.
//

import Foundation
import ARKit


/// Abstract class of  Probe device
class Probe: NSObject, ProbeInterface{
    
    // compatiable attributes
    static let defaultPixelBufferAttributes: [CFString: Any?] =
                [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
    
    var avPlayer: AVPlayer?
    var delegate: ProbeDelegate? = nil
    
    func open() -> Bool{
        producePreconditionError(sender: self.open)
        return false
    }
    
    func close() {
        producePreconditionError(sender: self.close)
    }
    func start() {
        producePreconditionError(sender: self.start)
        return
    }
    func stop() {
        producePreconditionError(sender: self.stop)
    }
}

extension Probe{
    private func producePreconditionError(sender: Any){
        preconditionFailure("need to override this function \(sender)")
    }
}

protocol ProbeInterface {

    var delegate: ProbeDelegate? { get set }
    var avPlayer: AVPlayer? { get }
    
    func open() -> Bool
    func close()
    
    func start()
    func stop()
    
}

protocol ProbeDelegate {
    func probe(_ probe: Probe, new frame: UFrameProvider)
}


/**
 Ultrasonic Image Frame
 */

class UFrameModel: UFrameProvider{
    var timestamp: TimeInterval?
    var pixelBuffer: CVPixelBuffer{
        didSet{
            timestamp = Date().timeIntervalSince1970
        }
    }
    
    init(buffer: CVPixelBuffer) {
        pixelBuffer = buffer
    }
}

protocol UFrameProvider{
    var timestamp: TimeInterval? { get }
    var pixelBuffer: CVPixelBuffer { get set }
}
