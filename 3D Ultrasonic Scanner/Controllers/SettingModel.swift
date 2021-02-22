//
//  SettingModel.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/12.
//

import Foundation
import UIKit


public enum Setting: String {
    case ProbeSorceKey
    case ARSourceKey
    case SourceFolderKey
}


/// Global setting
class GS: NSObject {
    static let shared = GS()
    
    @objc dynamic
    var probeSource: ProbeSource{
        get{
            getValue(for: .ProbeSorceKey)
        }
        set{
            setValue(value: newValue.rawValue , for: .ProbeSorceKey)
        }
    }
    
    @objc dynamic
    var arSource: ARSource{
        get{
            getValue(for: .ARSourceKey)
        }
        set{
            setValue(value: newValue.rawValue , for: .ARSourceKey)
        }
    }
    
    @objc dynamic
    var sourceFolder: URL{
        get {
            getUrl(for: .SourceFolderKey)! // TODO: consider the case that default folder is not given
        }
        set{
            setUrl(url: newValue, for: .SourceFolderKey)
        }
    }
    
    override init() {
        UserDefaults.standard.register(defaults: [Setting.ProbeSorceKey.rawValue: ProbeSource.Streaming.rawValue,
                                                  Setting.ARSourceKey.rawValue: ARSource.RealtimeAR.rawValue, Setting.SourceFolderKey.rawValue: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                                    .appendingPathComponent("Recordings") // default file path
                                                ])
    }
    

    
    func getValue<T: RawRepresentable>(for key: Setting) -> T {
        T.init(rawValue: UserDefaults.standard.value(forKey: key.rawValue) as! T.RawValue)!
    }
    func setValue(value: Any, for key: Setting) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }
    
    func getUrl(for key: Setting) -> URL? {
        UserDefaults.standard.url(forKey: key.rawValue) ?? nil
    }
    func setUrl(url: URL?, for key: Setting) {
        UserDefaults.standard.set(url, forKey: key.rawValue)
    }
    
}

