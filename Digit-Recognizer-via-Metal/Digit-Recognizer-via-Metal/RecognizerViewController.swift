//
//  RecognizerViewController.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 05.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import UIKit
import MetalKit
import AVFoundation


class RecognizerViewController: UIViewController {

    @IBOutlet weak var metalView: MTKView!
    @IBOutlet weak var recognizeButton: UIButton!
    
    let captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recognizeButton.layer.cornerRadius = recognizeButton.frame.width / 2.0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        AVCaptureDevice.requestAccess(for: .video) { (succeeded) in
            guard succeeded else {
                print("Doesn't got access")
                return
            }
            
            print("Got access")
        }
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.front)
        guard let device = deviceDiscoverySession.devices.first else {
            print("There is no any capture device")
            return
        }
        
        captureDevice = device
        
    }


    @IBAction func recognizeButtonDidTap(_ sender: Any) {
        
    }
    
}

