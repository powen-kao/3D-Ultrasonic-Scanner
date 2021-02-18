//
//  ViewController.swift
//  3D Ultrasonic Scanner
//
//  Created by Po-Wen Kao on 2021/1/4.
//

import UIKit
import SceneKit
import ARKit
import MetalKit
import AVKit

class ViewController: UIViewController, ARSCNViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ComposerDelegate, SettingDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var scnView: SCNView!
    
    // Controllers
    private var alertController: UIAlertController?
    private var composer: ComposeController?
    private var composerInfo: ComposerInfoProvider?
    
    // Scene Objects
    private var probeNode: SCNNode?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Load scene for rendering point cloud
        let pointCloudScene = SCNScene(named: "art.scnassets/pointCloud.scn")!
        scnView.scene = pointCloudScene
        scnView.debugOptions = [.showBoundingBoxes, .showCameras, .showWorldOrigin, .showFeaturePoints]
        scnView.rendersContinuously = true
        
        // Get nodes
        self.probeNode = pointCloudScene.rootNode.childNode(withName: "probe", recursively: true)

        // Create composer
        self.composer = ComposeController(arSession: sceneView.session, scnView: scnView)
        self.composer?.delegate = self
        self.composerInfo = composer
                

        // Set the scene to the view
        sceneView.scene = scene

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
        

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "sInfo"{
//            let dst = segue.destination as! InfoViewController
        }
        if segue.identifier == "sSetting"{
            let dst = segue.destination as! SettingViewController
            dst.delegate = self
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
    }
    @IBAction func action(_ sender: Any) {
        let alertSheet = UIAlertController(title: "Actions", message: "Choose action to perform", preferredStyle: .actionSheet)
        makeAlertActions(alertController: alertSheet)
        present(alertSheet, animated: true, completion: nil)
    }
    @IBAction func selectAsset(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func showInfo(_ sender: Any) {
    }
    @IBAction func capture(_ sender: Any) {
        Capturer.shared?.trigger()
    }
    @IBAction func preview(_ sender: Any) {
        self.composer?.start()
    }
    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    // MARK: - Composer Delegate
    func composer(_ composer: ComposeController, didUpdate arFrame: ARFrame) {
        switch arFrame.camera.trackingState {
        case .normal:
            alertController?.dismiss(animated: true, completion: nil)
            alertController = nil
            
            // Update probe transform
            self.probeNode?.transform =  SCNMatrix4(arFrame.camera.transform * (self.composer?.renderer?.voxelInfo.rotateToARCamera ?? matrix_identity_float4x4))
        default:
            if alertController == nil{
                alertController = UIAlertController()
                alertController?.title = "Warning AR tracking state"
                present(alertController!, animated: true, completion: nil)
            }
            alertController?.message = "\(arFrame.camera.trackingState)"
            
        }
    }
    
    // MARK: - Setting Delegate
    func probeSourceChanged(source: ProbeSource, folder: URL?) {
        composer?.switchProbeSource(source: source, folder: folder)
    }
    func arSourceChanged(source: ARSource) {
        composer?.switchARSource(source: source)
    }
    
    
}

extension ViewController{
    func makeAlertActions(alertController: UIAlertController) {
        alertController.addAction(
            UIAlertAction(title: "Set As Origin", style: .default, handler: {_ in
                self.composer?.restOrigin()
            })
        )
        alertController.addAction(
            UIAlertAction(title: "Finish", style: .default, handler: {_ in
                self.composer?.postProcess()
            })
        )
        
        if self.composer?.recorderState == .Ready {
            alertController.addAction(
                UIAlertAction(title: "Start Recording", style: .default, handler: {_ in
                    self.composer?.startRecording()
                })
            )
        } else{
            alertController.addAction(
                UIAlertAction(title: "Stop Recording", style: .default, handler: {_ in
                    self.composer?.stopRecording()
                })
            )
        }
        alertController.addAction(
            UIAlertAction(title: "Replay", style: .default, handler: {_ in
                self.composer?.replay()
            })
        )
        alertController.addAction(
            UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        )
    }
}
