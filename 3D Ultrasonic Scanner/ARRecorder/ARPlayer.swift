//
//  ARPlayer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//


import Foundation

class ARPlayer: ARRecorderBase {
    var delegate: ARPlayerDelegate?
    
    internal var fileURL: URL?
    internal var buffer = [ARFrameModel]()
    
    internal var metaURL: URL?
    internal var filemeta: RecorderMeta?
    
    private let decoder = JSONDecoder()
    
    /// Read to buffer
    func read(folder: URL) {
        self.fileURL = URL(fileURLWithPath: RecordFiles.getNameWithExtension(fileType: .ARFrameData), relativeTo: folder)
        self.metaURL = URL(fileURLWithPath: RecordFiles.getNameWithExtension(fileType: .RecorderMeta), relativeTo: folder)
        
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
