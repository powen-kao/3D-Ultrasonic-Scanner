//
//  Capturer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/21.
//


import Foundation
import Metal

class Capturer {
    
    var device: MTLDevice?
    
    static var shared: Capturer?
    
    private var captureManager: MTLCaptureManager?
    private(set) var state: State = State.Free
    
    enum State {
        case Free // free to capture
        case Wait // Waiting for begin() call
        case Capturing // Capturing
    }
    
    init(device: MTLDevice) {
        self.device = device
        self.captureManager = MTLCaptureManager.shared()
    }
    
    static func create(with device: MTLDevice) -> Capturer {
        Capturer.shared = Capturer(device: device)
        return Capturer.shared!
    }
    
    func trigger() {
        if state == .Free{
            state = .Wait
        }
    }
    
    func begin() {
        if state == .Wait{
            state = .Capturing
            let captureDescriptor = MTLCaptureDescriptor()
            captureDescriptor.captureObject = self.device
            do {
                try captureManager?.startCapture(with: captureDescriptor)
            }
            catch
            {
              fatalError("error when trying to capture: \(error)")
            }
        }
    }
    
    func end() {
        if state == .Capturing{
            captureManager?.stopCapture()
            state = .Free
        }
    }
}
