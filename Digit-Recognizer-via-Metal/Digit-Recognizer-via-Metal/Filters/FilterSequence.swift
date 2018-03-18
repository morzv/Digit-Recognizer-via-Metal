//
//  FilterSequence.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 09.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import Foundation
import MetalPerformanceShaders


class FilterSequence {
    var filters = [MPSUnaryImageKernel]()
    var temporaryTextures = [MTLTexture]()
    let textureDescriptor: MTLTextureDescriptor
    let metalDevice: MTLDevice
    
    var isEmpty: Bool {
        return filters.isEmpty
    }
    
    init(metalDevice device: MTLDevice, textureSize: (width: Int, height: Int)) {
        metalDevice = device
        textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                     width: textureSize.width,
                                                                     height: textureSize.height,
                                                                     mipmapped: false)
        textureDescriptor.usage.insert(.shaderWrite)
    }
    
    func add(filter: MPSUnaryImageKernel) {
        if !filters.isEmpty {
            temporaryTextures.append(temporaryTexture())
        }
        
        filters.append(filter)
    }
    
    func remove(filter: MPSUnaryImageKernel) {
        filters = filters.filter { $0 !== filter }
        
        _ = temporaryTextures.popLast()
    }
    
    func encode(to commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        var lastTemporaryTexture = sourceTexture
        
        for (index, filter) in filters.enumerated() {
            if index == filters.count - 1 {
                filter.encode(commandBuffer: commandBuffer, sourceTexture: lastTemporaryTexture, destinationTexture: destinationTexture)
            } else {
                let currentTemporaryTexture = temporaryTextures[index]
                filter.encode(commandBuffer: commandBuffer, sourceTexture: lastTemporaryTexture, destinationTexture: currentTemporaryTexture)
                lastTemporaryTexture = currentTemporaryTexture
            }
        }
    }
    
    private func temporaryTexture() -> MTLTexture {
        return metalDevice.makeTexture(descriptor: textureDescriptor)!
    }
}
