//
//  ARRecorder.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//


import Foundation
import ARKit
import UIKit

class ARRecorder: ARRecorderBase{
    
    var dataSource: ARRecoderDataSource?
    var delegate: ARRecorderDelegate?
    
    private let defaultEstimateSize =  60 * 60 * 3 // approximately 10 mins
    
    private var fileURL: URL?
    private(set) var buffer = [ARFrameModel]()
    
    private var metaURL: URL?
    private(set) var filemeta: RecorderMeta?
    
    var bufferFullness: Float {
        return Float(buffer.count) / Float(defaultEstimateSize)
    }
    
    private let encoder = JSONEncoder()
    
    typealias SaveCompleteHandler = (_ recorder: ARRecorder, _ success: Bool) -> Void
    
    override init() {
        super.init()
        encoder.outputFormatting = .prettyPrinted
    }
    

    func open(folder: URL, size: Int?){
        filemeta = RecorderMeta(begin: Date().timeIntervalSince1970)
        filemeta?.frameRate = 60 // default replay framerate
        
        // create folder if doesn't exist
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)

        
        self.fileURL = RecordFiles.getURL(at: folder, with: .ARFrameData)
        self.metaURL = RecordFiles.getURL(at: folder, with: .RecorderMeta)
        
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
        
        guard buffer.count > 0 else {
            return // nothing to save
        }
        
        filemeta?.duration = buffer.last!.timestamp - buffer.first!.timestamp
        
        // TODO: write file in background thread
        let data = Data(bytesNoCopy: &buffer, count: buffer.count * MemoryLayout<ARFrameModel>.stride, deallocator: .none)
        let metaData = try! encoder.encode(filemeta)
        
        guard let _fileUrl = self.fileURL,
              let _metaUrl = self.metaURL else {
            print("URL of recorder cannot be nil")
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                try data.write(to: _fileUrl)
                try metaData.write(to: _metaUrl)
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
