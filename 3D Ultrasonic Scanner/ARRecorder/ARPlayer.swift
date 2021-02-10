//
//  ARPlayer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//


import Foundation

class ARPlayer: ARRecorderBase {
    var delegate: ARPlayerDelegate?
    
    private var fileURL: URL?
    private(set) var buffer = [ARFrameModel]()
    
    private var metaURL: URL?
    private(set) var filemeta: RecorderMeta?
    
    private let decoder = JSONDecoder()
    
    /// Read to buffer
    func read(folder: URL) {
        
        self.fileURL = RecordFiles.getURL(at: folder, with: .ARFrameData)
        self.metaURL = RecordFiles.getURL(at: folder, with: .RecorderMeta)
        
        let _data: Data
        do {
            _data = try Data(contentsOf: fileURL!)
            filemeta = try? decoder.decode(RecorderMeta.self, from: try Data(contentsOf: metaURL!))
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
