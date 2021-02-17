//
//  SettingViewController.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/11.
//

import Foundation
import UIKit

class SettingViewController: UITableViewController, UIDocumentPickerDelegate {
    
    var delegate: SettingDelegate?
    
    @IBOutlet weak var sourceSegment: UISegmentedControl!
    
    var currentSource: ComposerSource{
        ComposerSource.init(rawValue: sourceSegment.selectedSegmentIndex)!
    }

    override func viewDidLoad() {
    
    }
    
    @IBAction func sourceChanged(_ sender: Any) {
        switch currentSource {
            case .Recording, .StaticImage:
                let folderPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
                folderPicker.delegate = self
                present(folderPicker, animated: true, completion: nil)
                
                // call delegate on folder selected
                
                break
            
            case .Streaming:
                delegate?.sourceChanged(source: currentSource, folder: nil)
                break
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        delegate?.sourceChanged(source: currentSource, folder: urls[0])
    }
}


protocol SettingDelegate {
    func sourceChanged(source: ComposerSource, folder: URL?)
}
