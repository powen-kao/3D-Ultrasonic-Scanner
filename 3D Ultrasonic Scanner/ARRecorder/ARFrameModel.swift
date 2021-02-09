//
//  ARModel.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//


import Foundation
import ARKit

struct ARFrameModel : Codable{
    let transform: float4x4
    let timestamp: TimeInterval
    init(transform: float4x4, timestamp: TimeInterval) {
        self.transform = transform
        self.timestamp = timestamp
    }
    init(frame: ARFrame) {
        transform = frame.camera.transform
        timestamp = NSDate.now.timeIntervalSince1970
    }
    
}

extension float4x4: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode([SIMD4<Float>].self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode([columns.0,columns.1, columns.2, columns.3])
    }
}
