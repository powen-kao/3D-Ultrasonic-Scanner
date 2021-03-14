//
//  SettingModel.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/12.
//

import Foundation
import UIKit


/// Global setting
public enum Setting: String {
    case sKeyProbeSorce
    case sKeyARSource
    case sKeySourceFolder
    case sKeyImageDepth
    
    // AR to probe
    case sKeyTimeShift
    case sKeyFixedDelay
    
    // Voxel
    case sKeyDimension
    case sKeyStepScale
    
    // Displacement
    case sKeyVerticalDisp
    case sKeyHorizontalDisp

}

extension UserDefaults{
    
    func value<T: RawRepresentable>(for key: Setting) -> T {
        T.init(rawValue: UserDefaults.standard.value(forKey: key.rawValue) as! T.RawValue)!
    }
    func set(_ value: Any, for key: Setting) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }
    
    @objc dynamic
    var probeSource: ProbeSource{
        get{
            value(for: Setting.sKeyProbeSorce)
        }
        set{
            set(newValue.rawValue, for: Setting.sKeyProbeSorce)
        }
    }
    
    @objc dynamic
    var arSource: ARSource{
        get{
            value(for: Setting.sKeyARSource)
        }
        set{
            set(newValue.rawValue, for: Setting.sKeyARSource)
        }
    }
    
    @objc dynamic
    var sourceFolder: URL?{
        get {
            guard let data = data(forKey: Setting.sKeySourceFolder.rawValue) else {
                return nil
            }
            var stale = false
            return try? URL.init(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
        }
        set{
            guard newValue != nil else {
                return
            }
            set(try? newValue!.bookmarkData(), forKey: Setting.sKeySourceFolder.rawValue)
        }
    }
    
    @objc dynamic
    var imageDepth: Float{
        get{
            value(forKey: Setting.sKeyImageDepth.rawValue) as! Float
        }
        set{
            set(newValue, forKey: Setting.sKeyImageDepth.rawValue)
        }
    }
    
    @objc dynamic
    var timeShift: Float{
        get{
            value(forKey: Setting.sKeyTimeShift.rawValue) as! Float
        }
        set{
            set(newValue, forKey: Setting.sKeyTimeShift.rawValue)
        }
    }
    
    @objc dynamic
    var fixedDelay: Float{
        get{
            value(forKey: Setting.sKeyFixedDelay.rawValue) as! Float
        }
        set{
            set(newValue, forKey: Setting.sKeyFixedDelay.rawValue)
        }
    }
    
    @objc dynamic
    var dimension: simd_uint3{
        get{
            (value(forKey: Setting.sKeyDimension.rawValue) as! Data).uint3()!
        }
        set{
            set(newValue.data(), forKey: Setting.sKeyDimension.rawValue)
        }
    }
    
    @objc dynamic
    var stepScale: Float{
        get{
            value(forKey: Setting.sKeyStepScale.rawValue) as! Float
        }
        set{
            set(newValue, forKey: Setting.sKeyStepScale.rawValue)
        }
    }
    
    
    @objc dynamic
    var verticalDisplacement: Float{
        get{
            value(forKey: Setting.sKeyVerticalDisp.rawValue) as! Float
        }
        set{
            setValue(newValue, forKey: Setting.sKeyVerticalDisp.rawValue)
        }
    }
    
    @objc dynamic
    var horizontalDisplacement: Float{
        get{
            value(forKey: Setting.sKeyHorizontalDisp.rawValue) as! Float
        }
        set{
            setValue(newValue, forKey: Setting.sKeyHorizontalDisp.rawValue)
        }
    }
    
}
