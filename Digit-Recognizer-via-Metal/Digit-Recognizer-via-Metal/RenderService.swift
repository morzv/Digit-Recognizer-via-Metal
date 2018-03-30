//
//  RecognizeService.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 29.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import MetalKit

class RenderService {
    let metalService: MetalService
    let session: CaptureSession
    
    private var camera: CaptureDevice
    var sourceTexture: MTLTexture?
    var filterFinalTexture: MTLTexture
    
    init?(metalService: MetalService) {
        guard let captureDevice = CaptureDevice(deviceType: .builtInWideAngleCamera, mediaType: .video, devicePosition: .back) else { return nil }
        
        self.metalService = metalService
        camera = captureDevice
        session = CaptureSession(metalDevice: metalService.device, captureDevice: camera)
        filterFinalTexture = metalService.createTexture(for: .bgra8Unorm, size: session.size)!
        session.delegate = self
    }
    
    func render(view: MTKView, with filterSequence: FilterSequence, should: Bool, completionHandler: @escaping ([UInt8]) -> Void) {
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
//        commandBuffer.addCompletedHandler(completionHandler)
        commandBuffer.addCompletedHandler { (buffer) in
            guard buffer.status == .completed, should == true else { return }
            let bytePerPixel = 4
            let bytesPerRow = self.session.size.width * bytePerPixel
            let imageBytesSize = self.session.size.width * self.session.size.height * bytePerPixel
            var pixelData = [UInt8](repeating: 0, count: imageBytesSize)
            let region = MTLRegionMake2D(0, 0, self.session.size.width, self.session.size.height)
            pixelData.withUnsafeMutableBytes {
                self.filterFinalTexture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            }
            
            var pixelIndex = 0
            let alphaChannelData = pixelData.filter { _ in
                defer { pixelIndex += 1 }
                return pixelIndex % 4 == 0
            }
            
            completionHandler(alphaChannelData)
        }
        commandBuffer.commit()
    }
}

extension RenderService: CaptureSessionDelegate {
    func captureSession(_: CaptureSession, didReceiveTexture texture: MTLTexture) {
        sourceTexture = texture
    }
}
