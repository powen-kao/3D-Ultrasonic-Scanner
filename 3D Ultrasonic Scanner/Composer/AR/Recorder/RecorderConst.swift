//
//  RecorderConst.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/10.
//

import Foundation

enum RecordFiles: String {
    case ARFrameData
    case RecorderMeta
    
    static func getNameWithExtension(fileType: RecordFiles) -> String {
        var ext: String = "unknown"
        switch fileType {
        case .ARFrameData:
            ext = "arfile"
            break
        case .RecorderMeta:
            ext = "json"
            break
        }
        return fileType.rawValue.appending(".\(ext)")
    }
    
    static func getURL(at url: URL, with fileType: RecordFiles) -> URL{
        var _url  = URL(fileURLWithPath: url.absoluteString)
        _url.appendPathComponent(getNameWithExtension(fileType: fileType))
        return _url
    }
}
