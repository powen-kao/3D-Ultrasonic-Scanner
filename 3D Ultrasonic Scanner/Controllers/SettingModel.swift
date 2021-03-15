//
//  SettingModel.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/12.
//

import Foundation
import UIKit


/// Global setting
public enum SettingKey: String {
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
    case sKeyDisplacement

}

extension UserDefaults{
    
    func value<T: RawRepresentable>(for key: SettingKey) -> T {
        T.init(rawValue: UserDefaults.standard.value(forKey: key.rawValue) as! T.RawValue)!
    }
    func set(_ value: Any, for key: SettingKey) {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }
    
    @objc dynamic
    var probeSource: ProbeSource{
        get{
            value(for: SettingKey.sKeyProbeSorce)
        }
        set{
            set(newValue.rawValue, for: SettingKey.sKeyProbeSorce)
        }
    }
    
    @objc dynamic
    var arSource: ARSource{
        get{
            value(for: SettingKey.sKeyARSource)
        }
        set{
            set(newValue.rawValue, for: SettingKey.sKeyARSource)
        }
    }
    
    @objc dynamic
    var sourceFolder: URL?{
        get {
            guard let data = data(forKey: SettingKey.sKeySourceFolder.rawValue) else {
                return nil
            }
            var stale = false
            return try? URL.init(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
        }
        set{
            guard newValue != nil else {
                return
            }
            set(try? newValue!.bookmarkData(), forKey: SettingKey.sKeySourceFolder.rawValue)
        }
    }
    
    @objc dynamic
    var imageDepth: Float{
        get{
            value(forKey: SettingKey.sKeyImageDepth.rawValue) as! Float
        }
        set{
            set(newValue, forKey: SettingKey.sKeyImageDepth.rawValue)
        }
    }
    
    @objc dynamic
    var timeShift: Float{
        get{
            value(forKey: SettingKey.sKeyTimeShift.rawValue) as! Float
        }
        set{
            set(newValue, forKey: SettingKey.sKeyTimeShift.rawValue)
        }
    }
    
    @objc dynamic
    var fixedDelay: Float{
        get{
            value(forKey: SettingKey.sKeyFixedDelay.rawValue) as! Float
        }
        set{
            set(newValue, forKey: SettingKey.sKeyFixedDelay.rawValue)
        }
    }
    
    @objc dynamic
    var dimension: simd_uint3{
        get{
            (value(forKey: SettingKey.sKeyDimension.rawValue) as! Data).uint3()!
        }
        set{
            set(newValue.data(), forKey: SettingKey.sKeyDimension.rawValue)
        }
    }
    
    @objc dynamic
    var stepScale: Float{
        get{
            value(forKey: SettingKey.sKeyStepScale.rawValue) as! Float
        }
        set{
            set(newValue, forKey: SettingKey.sKeyStepScale.rawValue)
        }
    }
    
    @objc dynamic
    var displacement: simd_float3{
        get{
            (value(forKey: SettingKey.sKeyDisplacement.rawValue) as! Data).float3()!
        }
        set{
            setValue(newValue.data(), forKey: SettingKey.sKeyDisplacement.rawValue)
        }
    }

}

class Setting: ObservableObject {
    static let standard = Setting()

    private let userDefault = UserDefaults.standard

    @Published var displacement: simd_float3 = UserDefaults.standard.displacement

    func set(depth: Float) {
        userDefault.imageDepth = depth
    }

    func set(displacement: simd_float3) {
        userDefault.displacement = displacement
        self.displacement = displacement
    }
}
