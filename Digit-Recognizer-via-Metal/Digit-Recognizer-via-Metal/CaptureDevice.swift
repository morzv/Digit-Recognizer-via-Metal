//
//  Camera.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 07.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import Foundation
import AVFoundation

class CaptureDevice {
    let position: AVCaptureDevice.Position
    let mediaType: AVMediaType
    let device: AVCaptureDevice
    
    init?(deviceType: AVCaptureDevice.DeviceType, mediaType: AVMediaType, devicePosition position: AVCaptureDevice.Position) {
        self.mediaType = mediaType
        self.position = position
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [deviceType], mediaType: mediaType, position:position)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            return nil
        }
        
        self.device = captureDevice
    }
    
    func requestAccess(completionHandler handler: @escaping ((Bool) -> Void)) {
        AVCaptureDevice.requestAccess(for: mediaType, completionHandler: handler)
    }
}
