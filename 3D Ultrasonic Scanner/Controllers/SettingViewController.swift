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
    
    @IBOutlet weak var probeSourceSegment: UISegmentedControl!
    @IBOutlet weak var arSourceSegment: UISegmentedControl!
    
    var currentProbeSource: ProbeSource{
        ProbeSource.init(rawValue: probeSourceSegment.selectedSegmentIndex)!
    }

    var currentARSource: ARSource{
        ARSource.init(rawValue: arSourceSegment.selectedSegmentIndex)!
    }

    override func viewDidLoad() {
    
    }
    
    @IBAction func arSourceChanged(_ sender: Any) {
        delegate?.arSourceChanged(source: currentARSource)
//        switch currentARSource {
//        case .RealtimeAR: break
//        case .RecordedAR: break
//        }
    }
    
    @IBAction func sourceChanged(_ sender: Any) {
        switch currentProbeSource {
            case .Video, .Image:
                let folderPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
                folderPicker.delegate = self
                present(folderPicker, animated: true, completion: nil)
                
                // call delegate on folder selected
                
                break
            
            case .Streaming:
                delegate?.probeSourceChanged(source: currentProbeSource, folder: nil)
                break
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        delegate?.probeSourceChanged(source: currentProbeSource, folder: urls[0])
    }
}


protocol SettingDelegate {
    func probeSourceChanged(source: ProbeSource, folder: URL?)
    func arSourceChanged(source: ARSource)
}
