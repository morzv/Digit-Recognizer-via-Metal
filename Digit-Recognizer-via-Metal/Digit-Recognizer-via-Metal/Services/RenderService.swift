//
//  RecognizeService.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 29.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import MetalKit

/// Incapsulate logic of rendering captured data from device
/// and applying selected filters.
class RenderService {
    let metalService: MetalService
    let session: CaptureSession
    
    private var camera: CaptureDevice
    private var sourceTexture: MTLTexture?
    private var filterFinalTexture: MTLTexture
    
    init?(metalService: MetalService) {
        guard let captureDevice = CaptureDevice(deviceType: .builtInWideAngleCamera, mediaType: .video, devicePosition: .back) else { return nil }
        
        self.metalService = metalService
        camera = captureDevice
        session = CaptureSession(metalDevice: metalService.device, captureDevice: camera)
        filterFinalTexture = metalService.createTexture(for: .bgra8Unorm, size: session.size)!
        session.delegate = self
    }
    
    /// Render captured data from device to view and apply filters to that.
    ///
    /// - Parameters:
    ///   - view: Target for rendering.
    ///   - filterSequence: Filters which should be applied to result texture.
    ///   - completionHandler: Block which will be called after rendering.
    func render(view: MTKView, with filterSequence: FilterSequence, completionHandler: @escaping (MTLTexture) -> Void) {
        guard let texture = sourceTexture,
            let currentRenderPassDescriptor = view.currentRenderPassDescriptor,
            let currentDrawable = view.currentDrawable else { return }
        
        let commandBuffer = metalService.commandQueue.makeCommandBuffer()!
        filterSequence.encode(to: commandBuffer, sourceTexture: texture, destinationTexture: filterFinalTexture)
        
        let renderTexture = filterSequence.isEmpty ? sourceTexture : filterFinalTexture
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)!
        encoder.setRenderPipelineState(metalService.renderPipeline)
        encoder.setFragmentTexture(renderTexture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.addCompletedHandler { (buffer) in
            guard buffer.status == .completed else { return }
            completionHandler(self.filterFinalTexture)
        }
        commandBuffer.commit()
    }
}

extension RenderService: CaptureSessionDelegate {
    func captureSession(_: CaptureSession, didReceiveTexture texture: MTLTexture) {
        sourceTexture = texture
    }
}
