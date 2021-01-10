//
//  InfoViewController.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/9.
//


import Foundation
import UIKit

class InfoViewController: UIViewController{
    static var shared: InfoViewController?
    
    @IBOutlet weak var frameInfoTextView: UITextView!
    @IBOutlet weak var voxelInfoTextView: UITextView!
    
    var frameInfoText: String = ""{
        didSet{
            frameInfoTextView?.text = frameInfoText
        }
    }
    
    override func viewDidLoad() {
        frameInfoTextView.text = frameInfoText
        
        if InfoViewController.shared != self{
            InfoViewController.shared = self
        }
    }
    

    
    
}
