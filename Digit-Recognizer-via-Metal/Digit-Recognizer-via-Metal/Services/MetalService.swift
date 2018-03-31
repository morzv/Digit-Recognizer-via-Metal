//
//  MetalService.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 29.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import MetalKit

/// Responsible for access to main Metal components.
class MetalService {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let renderPipeline: MTLRenderPipelineState
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary() else { return nil }
        
        self.device = device
        commandQueue = queue
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        
        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Cannot create a render pipeline.")
            return nil
        }
    }
    
    /// Create new metal texture with shaderWrite usage option.
    ///
    /// - Parameters:
    ///   - type: Pixel format.
    ///   - size: Size of new texture.
    /// - Returns: New metal texture.
    func createTexture(for type: MTLPixelFormat, size: (width: Int, height: Int)) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: type,
                                                                 width: size.width,
                                                                 height: size.height,
                                                                 mipmapped: false)
        descriptor.usage.insert(.shaderWrite)
        
        return device.makeTexture(descriptor: descriptor)
    }
}
