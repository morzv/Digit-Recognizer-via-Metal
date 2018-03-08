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
    
    var camera: CaptureDevice!
    var session: CaptureSession!
    
    var metalDevice = MTLCreateSystemDefaultDevice()
    var sourceTexture: MTLTexture?
    var commandQueue: MTLCommandQueue!
    
    var renderPipelineState: MTLRenderPipelineState?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        commandQueue = metalDevice?.makeCommandQueue()
        camera = CaptureDevice(deviceType: .builtInWideAngleCamera, mediaType: .video, devicePosition: .back)
        session = CaptureSession(metalDevice: metalDevice!, captureDevice: camera)
        session.delegate = self
        
        recognizeButton.layer.cornerRadius = recognizeButton.frame.width / 2.0
        
        initializeRenderPipelineState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        metalView.device = self.metalDevice
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        
        session.start()
    }


    @IBAction func recognizeButtonDidTap(_ sender: Any) {
        
    }
    
    private func initializeRenderPipelineState() {
        guard let device = metalDevice,
            let library = device.makeDefaultLibrary() else {
                return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        
        do {
            try renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch {
            assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
            return
        }
    }
    
}

extension RecognizerViewController : CaptureSessionDelegate {
    func captureSession(_: CaptureSession, didReceiveTexture texture: MTLTexture) {
        sourceTexture = texture
    }
}

extension RecognizerViewController : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        guard let texture = sourceTexture,
            let currentRenderPassDescriptor = metalView.currentRenderPassDescriptor,
            let currentDrawable = metalView.currentDrawable,
            let renderPipelineState = renderPipelineState else {
                return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)!
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
