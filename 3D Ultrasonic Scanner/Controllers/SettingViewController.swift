//
//  SettingViewController.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/11.
//

import Foundation
import UIKit

class SettingViewController: UITableViewController, UIDocumentPickerDelegate {
        
    var selectedFolder: URL?
    let setting = GS.shared
    
    @IBOutlet weak var probeSourceSegment: UISegmentedControl!
    @IBOutlet weak var arSourceSegment: UISegmentedControl!
    @IBOutlet weak var folderPathLabel: UILabel!
    
    override func viewDidLoad() {
        updateUI()
    }
    
    @IBAction func arSourceChanged(_ sender: Any) {
        setting.arSource = ARSource.init(rawValue: arSourceSegment.selectedSegmentIndex)!
    }
    
    @IBAction func probeSourceChanged(_ sender: Any) {
        setting.probeSource = ProbeSource.init(rawValue: probeSourceSegment.selectedSegmentIndex)!
    }
    @IBAction func selectFolder(_ sender: Any) {
        let folderPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        folderPicker.delegate = self
        present(folderPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        setting.sourceFolder = urls[0]
        updateUI()
    }
    
    private func updateUI() {
        probeSourceSegment.selectedSegmentIndex = setting.probeSource.rawValue
        arSourceSegment.selectedSegmentIndex = setting.arSource.rawValue
        folderPathLabel.text = setting.sourceFolder.absoluteString
    }
}
