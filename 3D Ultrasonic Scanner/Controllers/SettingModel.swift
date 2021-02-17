//
//  SettingModel.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/12.
//

import Foundation
import UIKit

//
//class GlobalSetting {
//    static let shared = GlobalSetting()
//    
//    var settings: [Setting: SettingContext] = [
//        .UseFakeProbe: CheckSettingContext(title: "Use Fake Probe", subtitle: "Read from file instead of streaming from probe", identifier: .CheckRowType, checked: true),
//        .FakeProbeFile: ActionSettingContext(enabled: true, title: "Import", subtitle: "Select the file to use as fake source", identifier: .CheckRowType, function:{ sender ,tableview, indexPath in
//    }, image: UIImage(systemName: "folder.circle.fill")!)
//    ]
//    
//}
//
//
//enum Setting: Int {
//    case UseFakeProbe
//    case FakeProbeFile
//}
//
//
//struct CheckSettingContext: SettingContext {
//    var enabled: Bool = true
//    var title: String
//    var subtitle: String
//    var identifier: Identifier
//    
//    // checked
//    var checked: Bool = false
//}
//
//struct ActionSettingContext: SettingContext {
//    var enabled: Bool = true
//    var title: String
//    var subtitle: String
//    var identifier: Identifier
//    
//    
//    // actions
//    var function: (_ sender: SettingViewController ,_ tableView: UITableView, _ indexPath: IndexPath) -> Void
//    var image: UIImage
//}
//
//
//protocol SettingContext{
//    var title: String { get }
//    var subtitle: String { get }
//    var identifier: Identifier { get }
//    var enabled: Bool {set get}
//    
//    typealias Identifier = SettingViewController.Identifier
//}
