//
//  ARPlayer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//


import Foundation

class ARPlayer {
    var delegate: ARPlayerDelegate?
    var buffer: [ARFrameModel]?
    
    init() {
        
    }
    
    /// Read to buffer
    func read(file: URL) {
        let _data: Data
        do {
            _data = try Data(contentsOf: file)
        } catch {
            print(error)
            return
        }
        
        let _elementCount = _data.count / MemoryLayout<ARFrameModel>.stride
        guard _elementCount > 0 else {
            return
        }
        
        // read data
        buffer = _data.withUnsafeBytes { (_buffer: UnsafeRawBufferPointer) -> Array<ARFrameModel> in
            Array(_buffer.bindMemory(to: ARFrameModel.self))
        }
    }
}

protocol ARPlayerDelegate {
    func arPlayer(new frame: ARFrameModel)
}
