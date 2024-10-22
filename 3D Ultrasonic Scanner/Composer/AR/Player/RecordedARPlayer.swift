//
//  FakeARPlayer.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/18.
//

import Foundation
import CoreMedia
import ARKit
import os

class RecordedARPlayer: ARPlayer, DisplayLinkable {
        
    private(set) var displayLink: CADisplayLink?
    private(set) var framerate: Int = UIScreen.main.maximumFramesPerSecond
    
    private var fileURL: URL?
    private(set) var buffer = [ARFrameModel]()
    
    private var metaURL: URL?
    private(set) var filemeta: ARMetaModel?
    
    private let decoder = JSONDecoder()
    
    // State
    private var startTime: CFTimeInterval?
    private var lastIndex: Int = -1
    
    init? (folder: URL) {
        // TODO: check why folder check failed
//        guard FileManager.default.fileExists(atPath: folder.absoluteString) else {
//            os_log(.debug, "folder \(folder) doesn't exist")
//            return nil
//        }
        super.init()
        
        self.isFileBased = true
        
        self.fileURL = RecordFiles.getURL(at: folder, with: .ARFrameData)
        self.metaURL = RecordFiles.getURL(at: folder, with: .RecorderMeta)
    }
    
    override func open() -> Bool {
        let _data: Data
        do {
            _data = try Data(contentsOf: fileURL!)
            filemeta = try? decoder.decode(ARMetaModel.self, from: try Data(contentsOf: metaURL!))
        } catch {
            print(error)
            return false
        }
        
        let _elementCount = _data.count / MemoryLayout<ARFrameModel>.stride
        guard _elementCount > 0 else {
            return false
        }
        
        // read data
        buffer = _data.withUnsafeBytes { (_buffer: UnsafeRawBufferPointer) -> Array<ARFrameModel> in
            Array(_buffer.bindMemory(to: ARFrameModel.self))
        }
                
        return true
    }
    
    override func start() {
        // take the staring time
        startTime = CACurrentMediaTime()
        os_log(.info, "fake player with meta: \(self.filemeta.debugDescription)")
        makeDisplayLink(block: nil)
    }
    
    override func stop() {
        removeDisplayLink()
        reset()
    }
    
    override func reset() {
        startTime = nil
        lastIndex = -1
    }
    
    private func getFrame(forItemTime time: CMTime) -> ARFrameModel?{
        
        // TODO: implement timestamp search instead of always return next frame
        let _index = lastIndex + 1
        guard _index < buffer.count else {
            stop()
            delegate?.finished(self)
            return nil
        }
        
        lastIndex = _index
        return buffer[_index]
    }
    
    func makeDisplayLink(block: DisplayLinkCallback?) {
        // setup display link
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkStep))
        displayLink?.preferredFramesPerSecond = Int(filemeta?.frameRate ?? 60)
        self.displayLink?.add(to: .current, forMode: .default)
    }
    
    func removeDisplayLink() {
        self.displayLink?.invalidate()
    }
    
    @objc func displayLinkStep(displaylink: CADisplayLink) {
        
        // get target item time
        guard let _startTime = startTime else {
            return
        }
        let itemTime = CMTime(seconds: CACurrentMediaTime() - _startTime, preferredTimescale: 1)
        
        // get frame of target item time
        guard let frame = getFrame(forItemTime: itemTime) else {
            return
        }
        
        delegate?.player(self, new: frame)
    }
}
