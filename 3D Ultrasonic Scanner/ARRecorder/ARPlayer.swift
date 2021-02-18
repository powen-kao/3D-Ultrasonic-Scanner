//
//  ARPlayer.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/2/1.
//

import Foundation
import ARKit
class ARPlayer: NSObject ,ARPLayerInterface {
    
    var delegate: ARPlayerDelegate?

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

protocol ARPLayerInterface {
    
    func open() -> Bool
    func start()
    func stop()
    func close()
    func reset()
    
}


protocol ARPlayerDelegate {
    func player(_ player: ARPlayer, new frame: ARFrameModel)
}
