//
//  DeviceBase.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/10.
//

import Foundation
import ARKit


/// Abstract class of  Probe device
class Probe: NSObject, ProbeInterface, DisplayLinkableProbe{

    // MARK: ProbeInterface
    // compatiable attributes
    static let defaultPixelBufferAttributes: [CFString: Any?] =
                [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
    
    var delegate: ProbeDelegate? = nil
    var isFileBased: Bool = false // need to be explictly assigned when subclassing
        
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
    
    
    // MARK: DisplayLinkableProbe
    var displayLink: CADisplayLink?
    var framerate: Int = UIScreen.main.maximumFramesPerSecond

    func makeDisplayLink(block: DisplayLinkCallback?) {
    }
    
    func removeDisplayLink() {
    }
    
}

extension Probe{
    private func producePreconditionError(sender: Any){
        preconditionFailure("need to override this function \(sender)")
    }
}

protocol ProbeInterface {

    var delegate: ProbeDelegate? { get set }
    
    var isFileBased: Bool { get }
    
    func open() -> Bool
    func close()
    
    func start()
    func stop()
    
}
protocol DisplayLinkable {
    // Display link
    var displayLink: CADisplayLink? { get }
    var framerate: Int { get } // framerate of source
    
    func makeDisplayLink(block: DisplayLinkCallback?)
    func removeDisplayLink()
    
    typealias DisplayLinkCallback = () -> Void
}
typealias DisplayLinkableProbe = DisplayLinkable


protocol ProbeDelegate {
    func probe(_ probe: Probe, new frame: UFrameProvider)
    func finished(_ probe: Probe)
}


/**
 Ultrasound Image Frame
 */

class UFrameModel: UFrameProvider{
    var itemTime: TimeInterval?
//    var itemTime: CMTime?
    var pixelBuffer: CVPixelBuffer{
        didSet{
            itemTime = Date().timeIntervalSince1970
        }
    }
    
    init(buffer: CVPixelBuffer, itemTime: TimeInterval? = nil) {
        self.pixelBuffer = buffer
        self.itemTime = itemTime
    }
}

protocol UFrameProvider{
    var itemTime: TimeInterval? { get }
//    var itemTime: CMTime? { get }
    var pixelBuffer: CVPixelBuffer { get set }
}

