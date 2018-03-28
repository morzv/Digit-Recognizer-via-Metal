//
//  TextureConverter.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 08.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import Foundation
import AVFoundation

/// Responds for coverting image from camera to metal texure.
class TextureConverter {
    
    func convert(sampleBuffer buffer: CMSampleBuffer, with cameraTextureCache: CVMetalTextureCache) -> MTLTexture? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        var texture: CVMetalTexture?
        let textureWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let textureHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  cameraTextureCache,
                                                  pixelBuffer,
                                                  nil,
                                                  MTLPixelFormat.bgra8Unorm,
                                                  textureWidth,
                                                  textureHeight,
                                                  0,
                                                  &texture)
        
        guard let cameraTexture = texture else { return nil }
        
        return CVMetalTextureGetTexture(cameraTexture)
    }
}
