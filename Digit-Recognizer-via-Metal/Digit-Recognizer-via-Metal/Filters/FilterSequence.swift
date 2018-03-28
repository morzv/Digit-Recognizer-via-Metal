//
//  FilterSequence.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 09.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import Foundation
import MetalPerformanceShaders


/// Collection of filters, which can be applied for MTLTexture
class FilterSequence {
    private var filters = [MPSUnaryImageKernel]()
    private var temporaryTextures = [MTLTexture]()
    private let textureDescriptor: MTLTextureDescriptor
    private let metalDevice: MTLDevice
    
    /// True, if collection contains zero filters. Otherwise - false.
    public var isEmpty: Bool {
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
    
    /// Add new filter to collection.
    ///
    /// - Parameter filter: New filter.
    func add(filter: MPSUnaryImageKernel) {
        if !filters.isEmpty {
            temporaryTextures.append(temporaryTexture())
        }
        
        filters.append(filter)
    }
    
    /// Remove filter from collection.
    ///
    /// - Parameter filter: Filter, which will be deleted
    func remove(filter: MPSUnaryImageKernel) {
        filters = filters.filter { $0 !== filter }
        
        _ = temporaryTextures.popLast()
    }
    
    /// Remove all filters from collection.
    func clear() {
        filters.removeAll()
    }
    
    /// Apply all filters, which contains in the collection.
    ///
    /// - Parameters:
    ///   - commandBuffer: Buffer for computations.
    ///   - sourceTexture: Origin texture.
    ///   - destinationTexture: Final texture after filters processing.
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
