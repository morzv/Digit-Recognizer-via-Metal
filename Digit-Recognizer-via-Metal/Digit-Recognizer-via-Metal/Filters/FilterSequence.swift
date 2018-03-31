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
    private let textureSize: (width: Int, height: Int)
    private let metalService: MetalService
    
    /// True, if collection contains zero filters. Otherwise - false.
    public var isEmpty: Bool {
        return filters.isEmpty
    }
    
    init(metalService: MetalService, textureSize: (width: Int, height: Int)) {
        self.metalService = metalService
        self.textureSize = textureSize
    }
    
    /// Add new filter to collection.
    ///
    /// - Parameter filter: New filter.
    func add(filter: MPSUnaryImageKernel) {
        if !filters.isEmpty {
            temporaryTextures.append(metalService.createTexture(for: .rgba8Unorm, size: textureSize)!)
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
}
