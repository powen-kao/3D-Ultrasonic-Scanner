//
//  SettingViewController.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/11.
//

import Foundation
import UIKit

class SettingViewController: UITableViewController, UIDocumentPickerDelegate {
        
    var delegate: SettingViewDelegate?
    
    var selectedFolder: URL?
    let setting = UserDefaults.standard
    
    @IBOutlet weak var probeSourceSegment: UISegmentedControl!
    @IBOutlet weak var arSourceSegment: UISegmentedControl!
    @IBOutlet weak var folderPathLabel: UILabel!
    
    @IBOutlet weak var timeShiftValueLabel: UILabel!
    @IBOutlet weak var timeShiftSlider: UISlider!
    @IBOutlet weak var fixedDelayValueLabel: UILabel!
    @IBOutlet weak var fixedDelaySlider: UISlider!
    private var sliderStep: Float = 0.1
    
    override func viewWillAppear(_ animated: Bool) {
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
    @IBAction func timeShiftValueChanged(_ sender: Any) {
        let _slider = sender as! UISlider
        updateSlider(slider: _slider, label: timeShiftValueLabel, value: _slider.value)
        setting.timeShift = _slider.value
    }
    @IBAction func fixedDelayValueChanged(_ sender: Any) {
        let _slider = sender as! UISlider
        updateSlider(slider: _slider, label: fixedDelayValueLabel, value: _slider.value)
        setting.fixedDelay = _slider.value
    }
    @IBAction func clearVoxel(_ sender: Any) {
        delegate?.clearVoxelClicked()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        setting.sourceFolder = urls[0]
        updateUI()
    }
    
    private func updateUI() {
        probeSourceSegment.selectedSegmentIndex = setting.probeSource.rawValue
        arSourceSegment.selectedSegmentIndex = setting.arSource.rawValue
        folderPathLabel.text = setting.sourceFolder?.lastPathComponent ?? "Select Folder"
        
        updateSlider(slider: timeShiftSlider, label: timeShiftValueLabel, value: setting.timeShift)
        updateSlider(slider: fixedDelaySlider, label: fixedDelayValueLabel, value: setting.fixedDelay)
    }
    
    
}
extension SettingViewController{
    
    func updateSlider(slider: UISlider, label: UILabel ,value: Float) {
        slider.value = round(value / sliderStep) * sliderStep
        label.text = String(format: "%.1f", value)
    }
}


protocol SettingViewDelegate {
    func clearVoxelClicked()
}
