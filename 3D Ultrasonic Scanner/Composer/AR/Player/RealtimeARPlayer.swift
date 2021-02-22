//
//  RealtimeARPlayer.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/18.
//

import Foundation
import ARKit

class RealtimeARPlayer: ARPlayer, ARSessionDelegate {
    private(set) var session: ARSession
    private var state: State = .Stop
    
    init(session: ARSession) {
        self.session = session
        super.init()
        session.delegate = self
    }
    
    override func open() -> Bool {
        return true
    }
    override func start() {
        self.state = .Streaming
    }
    override func stop() {
        self.state = .Stop
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if (state == .Streaming){
            delegate?.player(self, new: ARFrameModel(frame: frame))
        }
    }
    
    private enum State{
        case Stop
        case Streaming
    }
}
