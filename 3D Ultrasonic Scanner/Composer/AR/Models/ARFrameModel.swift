//
//  ARModel.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//


import Foundation
import ARKit

struct ARFrameModel : Codable{
    let timestamp: TimeInterval
    let camera: ARCameraModel
    init(transform: float4x4, timestamp: TimeInterval) {
        self.camera = ARCameraModel(transform: transform)
        self.timestamp = timestamp
    }
    init(frame: ARFrame) {
        self.camera = ARCameraModel(transform: frame.camera.transform)
        timestamp = NSDate.now.timeIntervalSince1970
    }
}

struct ARCameraModel: Codable {
    var transform: float4x4
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
