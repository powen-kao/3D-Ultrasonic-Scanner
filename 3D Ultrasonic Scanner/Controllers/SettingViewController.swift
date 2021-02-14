//
//  SettingViewController.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/11.
//

import Foundation
import UIKit

class SettingViewController: UITableViewController {
    
    var global = GlobalSetting.shared
    
    override func viewDidLoad() {
    
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let _key = Setting(rawValue: indexPath.row)!
        let _setting = global.settings[_key]
        
        let cell =  tableView.dequeueReusableCell(withIdentifier: (_setting?.identifier.rawValue)!, for: indexPath)
        
        cell.textLabel?.text = _setting?.title
        cell.detailTextLabel?.text = _setting?.subtitle
        cell.selectionStyle = .none
                
        switch _key{
            case .UseFakeProbe:
                let _check = _setting as! CheckSettingContext
                cell.accessoryType = _check.checked ? .checkmark: .none
                break
            case .FakeProbeFile:
                let _action = _setting as! ActionSettingContext
                cell.imageView?.image = _action.image
                cell.isUserInteractionEnabled = _setting!.enabled
                cell.contentView.alpha = cell.isUserInteractionEnabled ? 1 : 0.2
                break
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        global.settings.count
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    // MARK: selection handler
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let _key = Setting(rawValue: indexPath.row)!
        let _setting = global.settings[_key]
        
        let _row = tableView.cellForRow(at: indexPath)
        
        switch _key {
        case .FakeProbeFile:
            // trigger function
            let _action = _setting as! ActionSettingContext
            _action.function(self, tableView, indexPath)
            break
        
        case .UseFakeProbe:
            if (_row?.accessoryType == UITableViewCell.AccessoryType.none){
                _row?.accessoryType = UITableViewCell.AccessoryType.checkmark
                global.settings[.FakeProbeFile]?.enabled = true
            }else{
                _row?.accessoryType = UITableViewCell.AccessoryType.none
                global.settings[.FakeProbeFile]?.enabled = false
            }
                        
            let _nextIndexPath = IndexPath(row: indexPath.row + 1, section: 0)
            tableView.reloadRows(at: [_nextIndexPath], with: .none)
            break
        }
        
    }
    enum Identifier: String {
        case CheckRowType = "checkedRow"
    }

}
