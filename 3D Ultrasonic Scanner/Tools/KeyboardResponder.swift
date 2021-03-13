//
//  KeyboardResponder.swift
//  UltrasoundScanner
//
//  Created by Po-Wen on 2021/3/11.
//

import Foundation
import UIKit
/// A reponder that helps to handle scroll view when keyboard is present and dismissed. Tap in the view of viewController will dismiss keyboard.
class KeyboardResponder {
    
    private let viewController: UIViewController
    private let scrollView: UIScrollView
    
    private lazy var view = viewController.view
    
    private var tapRecognizer: UITapGestureRecognizer?
    
    
    // for restortation
    var scrollYOffset: CGFloat = 0

    
    init(viewController: UIViewController, scrollView: UIScrollView) {
        self.viewController = viewController
        self.scrollView = scrollView
        
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(KeyboardResponder.dismissKeyboard))
    }
    
    func addObservation() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        view?.addGestureRecognizer(tapRecognizer!)
    }
    
    
    func removeObservation() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        
        view?.removeGestureRecognizer(tapRecognizer!)
    }
    
}



fileprivate extension KeyboardResponder{
    @objc func keyboardWillShow(notification: NSNotification){
        // save current offset
        scrollYOffset = scrollView.contentOffset.y
        
        let frame = (notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: frame.height - scrollView.blankSpace(), right: 0)
        scrollView.setContentOffset(CGPoint(x: 0, y: 20), animated:true)
    }
    
    @objc func keyboardWillHide(){
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollYOffset), animated: true)
        scrollView.contentInset = .zero
    }
    
    @objc func dismissKeyboard() {
        view?.endEditing(true)
    }
    
}
