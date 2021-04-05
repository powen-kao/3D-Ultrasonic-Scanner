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

class ViewController: UIViewController, ARSCNViewDelegate, UINavigationControllerDelegate, ComposerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var scnView: SCNView!
    @IBOutlet weak var composeButton: UIBarButtonItem!
    
    // Controllers
    private var alertController: UIAlertController?
    private var actionController: UIAlertController?
    private var composer: Composer?
    
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
        scnView.showsStatistics = true
        
        // Get nodes
        self.probeNode = pointCloudScene.rootNode.childNode(withName: "probe", recursively: true)

        // Create composer
        self.composer = Composer(arSession: sceneView.session, scnView: scnView)
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
            // assign self as destination delegate
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
    }

    @IBAction func action(_ sender: Any) {
        let alertSheet = UIAlertController(title: "Actions", message: "Choose action to perform", preferredStyle: .actionSheet)
        makeActions(alertController: alertSheet)
        present(alertSheet, animated: true, completion: nil)
    }
    
    @IBAction func showInfo(_ sender: Any) {
    }

    @IBAction func compose(_ sender: Any) {
        switch composer?.composeState {
        case .Idle:
            composer?.startCompose()
        default:
            composer?.stopCompose()
        }
    }
    @IBAction func clearVoxel(_ sender: Any) {
        makeAlert(title: "Clear Voxels", message: "Are you sure to clear voxels? This action is DESTRUCTIVE",
                       acceptContext: AlertActionContext(message: "CLEAR", action: { [self] in
                                                            composer?.clearVoxel()
                       }),
                       declineContext: AlertActionContext(message: "Cancel", action: nil))
        
        present(alertController!, animated: true, completion: nil)
    }

    // MARK: - ARSCNViewDelegate
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    // MARK: - ARSessionObserver
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
    func composer(_ composer: Composer, didUpdate arFrame: ARFrame) {
        switch arFrame.camera.trackingState {
        case .normal:
            actionController?.dismiss(animated: true, completion: nil)
            actionController = nil
            
            // Update probe transform
            self.probeNode?.transform =  SCNMatrix4(arFrame.camera.transform * (self.composer?.renderer?.voxelInfo.rotateToARCamera ?? matrix_identity_float4x4))
        default:
            if actionController == nil{
                actionController = UIAlertController()
                actionController?.title = "Warning AR tracking state"
                present(actionController!, animated: true, completion: nil)
            }
            actionController?.message = "\(arFrame.camera.trackingState)"
            
        }
    }
    
    func composer(_ composer: Composer, stateChanged: ComposeState) {
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
    
    func recordingState(_ composer: Composer, changeTo state: ARRecorderState) {
        // handle recording state chagne
    }
    
}

extension ViewController{
    struct AlertActionContext {
        let message: String
        let action: AlertAction?
    }
    
    @discardableResult
    func makeAlert(title: String, message: String, acceptContext: AlertActionContext? = nil, declineContext: AlertActionContext? = nil) -> UIAlertController{

        alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if acceptContext != nil{
            alertController?.addAction(.init(title: "Clear", style: .destructive, handler: { _ in
                acceptContext!.action?()
            }))
        }
        if declineContext != nil{
            alertController?.addAction(.init(title: "Cancel", style: .default, handler: { _ in
                declineContext!.action?()
            }))
        }

        return alertController!
    }
        
    func makeActions(alertController: UIAlertController) {
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
                    self.composer?.stopRecording { [self] (recorder, success) in
                        if (!success){
                            let alert = makeAlert(title: "Recording Failed", message: "Unknown Error")
                            present(alertController: alert, completion: nil, delay: 2)
                        }else{
                            let alert = makeAlert(title: "Recording Success", message: "AR tracking file saved to folder: \(String(describing: composer?.recordingURL?.lastPathComponent))")
                            present(alertController: alert, completion: nil, delay: 2)
                        }
                    }
                })
            )
        }
        alertController.addAction(
            UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        )
    }
    
    
    // MARK: Observers
    private func addObservers() {
        
        let _setting = Setting.standard
        
        observers = [
            _setting.$probeSource.sink(receiveValue: { [self] (value) in
                composer?.switchProbeSource(source: value)
                composer?.startCompose()
            }),
            _setting.$arSource.sink(receiveValue: { [self] (value) in
                composer?.switchARSource(source: value)
                composer?.startCompose()
            }),
            _setting.$sourceFolder.sink(receiveValue: { [self] (value) in
                guard let _sourceFolder = value else {
                    return
                }
                composer?.recordingURL = _sourceFolder
            }),
            _setting.$imageDepth.sink(receiveValue: { (value) in
                self.composer?.imageDepth = Double(value)
            }),
            
            
            _setting.$timeShift.sink(receiveValue: { (value) in
                self.composer?.timeShift = value
            }),
            _setting.$fixedDelay.sink(receiveValue: { (value) in
                self.composer?.fixedDelay = value
            }),
            
            
            _setting.$dimension.sink(receiveValue: { (value) in
                self.composer?.voxelSize = value
            }),
            _setting.$stepScale.sink(receiveValue: { (value) in
                self.composer?.voxelStepScale = Double(value)
            }),

            
            _setting.$displacement.sink(receiveValue: { (value) in
                self.composer?.displacement = value
            }),
            
        ]
    }
    
    
    typealias AlertAction = () -> ()
}
