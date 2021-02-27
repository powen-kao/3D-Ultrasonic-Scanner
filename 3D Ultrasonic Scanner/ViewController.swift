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

class ViewController: UIViewController, ARSCNViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ComposerDelegate, SettingViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var scnView: SCNView!
    @IBOutlet weak var composeButton: UIBarButtonItem!
    @IBOutlet weak var recordButton: UIBarButtonItem!
    
    // Controllers
    private var alertController: UIAlertController?
    private var composer: ComposeController?
    
    // Scene Objects
    private var probeNode: SCNNode?
    
    var observers: [Any?]?

        
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

        // Set the scene to the view
        sceneView.scene = scene
        
        // Add observer
        self.addObservers()

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
    @IBAction func compose(_ sender: Any) {
        switch composer?.composeState {
        case .Idle:
            composer?.startCompose()
        default:
            composer?.stopCompose()
        }
    }
    
    @IBAction func record(_ sender: Any) {
        switch composer?.recorderState {
        case .Ready:
            composer?.startRecording()
            break
        case .Recording:
            composer?.stopRecording()
            break
        default: break
        }
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    // MARK: - SettingViewDelegate
    func clearVoxelClicked() {
        composer?.clearVoxel()
    }
    
    
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
    
    func composer(_ composer: ComposeController, stateChanged: ComposeState) {
        switch stateChanged {
            case .Ready:
                composeButton.image = UIImage(systemName: "stop.fill")
                break
            case .Idle:
                composeButton.image = UIImage(systemName: "play.fill")
                break
            default: break
        }
    }
    
    func recordingState(_ composer: ComposeController, changeTo state: ARRecorderState) {
        switch state {
        case .Ready:
            recordButton.image = UIImage(systemName: "record.circle")
            break
        default:
            recordButton.image = UIImage(systemName: "stop.circle")
            break
        }
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
            UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        )
    }
    
    
    // MARK: Observers
    private func addObservers() {
        
        let _setting = UserDefaults.standard
        
        let sourceFolderObserver = _setting.observe(\.sourceFolder, options: [.initial, .new], changeHandler: { [self] setting, value in
            guard let _sourceFolder = setting.sourceFolder else {
                return
            }
            composer?.recordingURL = _sourceFolder
        })
        
        let probeSourceObserver = _setting.observe(\.probeSource, options: [.initial, .new]  ,changeHandler: { [self] setting, value in
            composer?.switchProbeSource(source: setting.probeSource)
            composer?.startCompose()
        })
        
        let arSourceObserver = _setting.observe(\.arSource, options: [.initial, .new], changeHandler: { [self] setting, value in
            composer?.switchARSource(source: setting.arSource)
            composer?.startCompose()
        })
        

        
        observers = [probeSourceObserver, sourceFolderObserver, arSourceObserver]
    }
}
