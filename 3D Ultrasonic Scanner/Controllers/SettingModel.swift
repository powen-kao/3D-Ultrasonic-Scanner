//
//  SettingModel.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/12.
//

import Foundation
import UIKit
import Combine
import os

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


class Store {
    static let std = Store()
    var references: [Cancellable] = []
}

class Setting: ObservableObject {
    static let standard = Setting()

    private var userDefault = UserDefaults.standard
    private var sinks: [Any]?

    // Source
    @Published(key: SettingKey.sKeyARSource.rawValue, rawRepresentableType: ARSource.self)
    var arSource: ARSource
    
    @Published(key: SettingKey.sKeyProbeSorce.rawValue, rawRepresentableType: ProbeSource.self)
    var probeSource: ProbeSource
    
    @Published(key: SettingKey.sKeySourceFolder.rawValue, urlType: URL.self)
    var sourceFolder: URL?
    
    @Published(key: SettingKey.sKeyImageDepth.rawValue, type: Float.self)
    var imageDepth: Float
    
    
    // AR to Probe delay
    @Published(key: SettingKey.sKeyTimeShift.rawValue, type: Float.self)
    var timeShift: Float
    
    @Published(key: SettingKey.sKeyFixedDelay.rawValue, type: Float.self)
    var fixedDelay: Float
    
    
    // Voxel
    @Published(key: SettingKey.sKeyDimension.rawValue, type: simd_uint3.self)
    var dimension: simd_uint3
    
    @Published(key: SettingKey.sKeyStepScale.rawValue, type: Float.self)
    var stepScale: Float

    
    // Displacement
    @Published(key: SettingKey.sKeyDisplacement.rawValue, type: simd_float3.self)
    var displacement: simd_float3
    
    // Reset settings
    func reset() {
        // Override point for customization after application launch.
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
}

extension Published{
    
    // Constructor for URL
    init <T>(key: String, urlType: T.Type){
        let data = UserDefaults.standard.value(forKey: key) as! Data
        
        var stale = false
        let url = try? URL.init(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
            
        self.init(wrappedValue: (url ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) as! Value)
        Store.std.references.append(
            projectedValue.sink(receiveValue: {(value) in
                let _value = value as! URL
                UserDefaults.standard.setValue(try? _value.bookmarkData(), forKey: key)
            })
        )
    }

    // Constructor for Enum (RawRepresentable)
    init<T: RawRepresentable & Codable>(key: String, rawRepresentableType: T.Type?=nil){
        let value = UserDefaults.standard.value(forKey: key)
        let enumValue =  T.init(rawValue: value as! T.RawValue)
        self.init(wrappedValue: enumValue as! Value)
        Store.std.references.append(
            projectedValue.sink(receiveValue: {(value) in
                let _value = value as! T
                UserDefaults.standard.setValue(_value.rawValue, forKey: key)
            })
        )
    }
    
    
    // Constructor for PropertyList serializable properties
    init<T: Codable>(key: String, type: T.Type?=nil){
        var value = UserDefaults.standard.value(forKey: key)
        if let data = value as? Data{
            value = data.decode(as: T.self)
        }
        
        self.init(wrappedValue: value as! Value)
        addUserDefaultsUpdater(type: T.self, key: key)
    }
    
    mutating func addUserDefaultsUpdater<T: Codable>(type: T.Type, key: String) {
        Store.std.references.append(
            projectedValue.sink { (value) in
                let _value = value as! T
                var _data: Data?
                if !PropertyListSerialization.propertyList(value, isValidFor: .xml){
                    _data = try? PropertyListEncoder().encode(_value)
                    guard _data != nil else {
                        os_log(.error, "\(T.Type.self) can neither be serialized to property list nor encooded to Data")
                        return
                    }
                    UserDefaults.standard.setValue(_data , forKey: key)
                    return
                }
                UserDefaults.standard.setValue(_value , forKey: key)
                return
            }
        )
    }
}

extension Data{
    func decode<T: Decodable>(as type: T.Type) -> T? {
        try? PropertyListDecoder().decode(type, from: self)
    }
}
