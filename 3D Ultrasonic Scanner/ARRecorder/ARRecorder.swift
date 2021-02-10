//
//  ARRecorder.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//


import Foundation
import ARKit
import UIKit

class ARRecorder: NSObject{
    
    var dataSource: ARRecoderDataSource?
    var delegate: ARRecorderDelegate?
    
    private let defaultEstimateSize =  60 * 60 * 3 // approximately 10 mins
    private var buffer = [ARFrameModel]()
    
    private(set) var fileURL: URL?
    
    var bufferFullness: Float {
        return Float(buffer.count) / Float(defaultEstimateSize)
    }
    
    typealias SaveCompleteHandler = (_ recorder: ARRecorder, _ success: Bool) -> Void
    

    func open(file: URL, size: Int?){
        self.fileURL = file
        
        // TODO: check whethrer the folder is writable
        
        buffer.removeAll()
        if let _size = size {
            buffer.reserveCapacity(_size)
        }else{
            buffer.reserveCapacity(defaultEstimateSize)
        }
        
    }
    
    
    /// Append frame in buffer, only avalialble in pushing mode
    func append(frame: ARFrame) {
        let frameModel = ARFrameModel(frame: frame)
        self.append(frame: frameModel)
    }
    
    func append(frame: ARFrameModel) {
        buffer.append(frame)
        delegate?.recorder!(self, fullness: bufferFullness)
        
        if (bufferFullness > 0.8){
            delegate?.recorder!(self, almostFull: bufferFullness)
        }
    }
    
    func close() {
        // TODO: add close complete handler
        
        // clean buffer
        buffer.removeAll()
    }
    
    func save(completeHandler: SaveCompleteHandler?) {
        // TODO: write file in background thread
        let data = Data(bytesNoCopy: &buffer, count: buffer.count * MemoryLayout<ARFrameModel>.stride, deallocator: .none)
        
        guard let _url = self.fileURL else {
            print("URL of recorder cannot be nil")
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                try data.write(to: _url)
            } catch {
                completeHandler?(self, false)
                print(error)
            }
            completeHandler?(self, true)
        }
    }
    
}

extension ARRecorder{

}


@objc protocol ARRecorderDelegate {
    @objc optional func recorder(_ recorder: ARRecorder, fullness: Float)
    @objc optional func recorder(_ recorder: ARRecorder, almostFull: Float)
}

protocol ARRecoderDataSource {
    func recoder(_ recorder: ARRecorder, frameWhen: Date) -> ARFrame
}
