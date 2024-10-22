//
//  FileMeta.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/10.
//

import Foundation

struct ARMetaModel: Codable, Equatable {
    var begin: TimeInterval = TimeInterval(0)
    var frameRate: Float = 0
    var duration: TimeInterval = 0// seconds
}
