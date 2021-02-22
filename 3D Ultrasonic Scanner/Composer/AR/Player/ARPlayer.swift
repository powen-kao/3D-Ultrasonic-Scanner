//
//  ARPlayer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//

import Foundation
import ARKit
class ARPlayer: NSObject ,ARPlayerInterface {
    
    var delegate: ARPlayerDelegate?
    var isFileBased: Bool = false // need to be explictly assigned when subclassing

    func open() -> Bool{
        return false
    }
    func start() {
    }
    
    func stop() {
    }
    
    func close() {
    }
    func reset() {
    }
    
    
}

protocol ARPlayerInterface {
    
    var isFileBased: Bool { get }
    
    func open() -> Bool
    func start()
    func stop()
    func close()
    func reset()
    
}


protocol ARPlayerDelegate {
    func player(_ player: ARPlayer, new frame: ARFrameModel)
    func finished(_ player: ARPlayer)
}
