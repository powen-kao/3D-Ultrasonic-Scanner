//
//  SettingViewController.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/2/11.
//

import Foundation
import UIKit

class SettingViewController: UITableViewController, UIDocumentPickerDelegate, UITextViewDelegate {
        
    var delegate: SettingViewDelegate?
    
    var selectedFolder: URL?
    let setting = UserDefaults.standard
    
    private var keyboardResponder: KeyboardResponder?
    
    @IBOutlet var scrollView: UITableView!
    
    // Slider setting
    private var sliderStep: Float = 0.1
    
    // Source section
    @IBOutlet weak var probeSourceSegment: UISegmentedControl!
    @IBOutlet weak var arSourceSegment: UISegmentedControl!
    @IBOutlet weak var folderPathLabel: UILabel!
    @IBOutlet weak var imageDepthSlider: UISlider!
    @IBOutlet weak var imageDepthValueLabel: UILabel!
    
    // Probe to AR section
    @IBOutlet weak var timeShiftValueLabel: UILabel!
    @IBOutlet weak var timeShiftSlider: UISlider!
    @IBOutlet weak var fixedDelayValueLabel: UILabel!
    @IBOutlet weak var fixedDelaySlider: UISlider!
    
    
    // Voxel
    @IBOutlet weak var dimensionXTextField: UITextField!
    @IBOutlet weak var dimensionYTextField: UITextField!
    @IBOutlet weak var dimensionZTextField: UITextField!
    @IBOutlet weak var stepSizeSlider: UISlider!
    @IBOutlet weak var stepSizeValueLabel: UILabel!
    
    
    override func viewDidLoad() {
        // add touch gesture recognizer
        keyboardResponder = KeyboardResponder(viewController: self, scrollView: scrollView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
        keyboardResponder?.addObservation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        keyboardResponder?.removeObservation()
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
    @IBAction func imageDepthChanged(_ sender: UISlider) {
        update(label: imageDepthValueLabel, value: sender.value)
        setting.imageDepth = sender.value
    }
    
    /// MARK: Probe to AR
    @IBAction func timeShiftValueChanged(_ sender: Any) {
        let _slider = sender as! UISlider
        update(slider: _slider, label: timeShiftValueLabel, value: _slider.value)
        setting.timeShift = _slider.value
    }
    @IBAction func fixedDelayValueChanged(_ sender: Any) {
        let _slider = sender as! UISlider
        update(slider: _slider, label: fixedDelayValueLabel, value: _slider.value)
        setting.fixedDelay = _slider.value
    }
    
    /// MARK: Voxel
    @IBAction func dimensionXEndEditing(_ sender: UITextField) {
        guard let value = Int(sender.text!) else {
            return
        }
        setting.dimension.x = Int32(value)
    }
    @IBAction func dimensionYEndEditing(_ sender: UITextField) {
        guard let value = Int(sender.text!) else {
            return
        }
        setting.dimension.y = Int32(value)
    }
    @IBAction func dimensionZEndEditing(_ sender: UITextField) {
        guard let value = Int(sender.text!) else {
            return
        }
        setting.dimension.z = Int32(value)
    }
    @IBAction func stepSizeChanged(_ sender: Any) {
        update(label: stepSizeValueLabel, value: stepSizeSlider.value)
        setting.stepSize = stepSizeSlider.value
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        setting.sourceFolder = urls[0]
        updateUI()
    }
    

}

private extension SettingViewController{
    func updateUI() {
        probeSourceSegment.selectedSegmentIndex = setting.probeSource.rawValue
        arSourceSegment.selectedSegmentIndex = setting.arSource.rawValue
        folderPathLabel.text = setting.sourceFolder?.lastPathComponent ?? "Select Folder"
                
        update(textField: dimensionXTextField, value: Int(setting.dimension.x))
        update(textField: dimensionYTextField, value: Int(setting.dimension.y))
        update(textField: dimensionZTextField, value: Int(setting.dimension.z))
        
        update(slider: timeShiftSlider, label: timeShiftValueLabel, value: setting.timeShift)
        update(slider: fixedDelaySlider, label: fixedDelayValueLabel, value: setting.fixedDelay)
        update(slider: imageDepthSlider, label: imageDepthValueLabel, value: setting.imageDepth)
        update(slider: stepSizeSlider, label: stepSizeValueLabel, value: setting.stepSize)
    }
    
    func update(textField: UITextField, value: Int, format: String? = "%d") {
        textField.text = String(format: format!, value)
    }
    
    func update(label: UILabel, value: Float, format: String?="%.1f", unit: String?=nil) {
        var text = String(format: format!, value)
        if unit != nil{
            text.append(" " + unit!)
        }
        label.text = text
    }
    
    func update(slider: UISlider, label: UILabel ,value: Float) {
        slider.value = round(value / sliderStep) * sliderStep
        label.text = String(format: "%.1f", value)
    }
}

internal extension SettingViewController{
    func textViewDidBeginEditing(_ textView: UITextView) {
//        keyboardResponder?.focus(view: textView)
    }
}


protocol SettingViewDelegate {
    func clearVoxelClicked()
}
