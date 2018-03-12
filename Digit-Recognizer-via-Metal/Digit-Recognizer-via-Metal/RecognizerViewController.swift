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
import MetalPerformanceShaders

class RecognizerViewController: UIViewController {

    @IBOutlet weak var metalView: MTKView!
    @IBOutlet weak var recognizeButton: UIButton!
    @IBOutlet weak var filtersCollectionView: UICollectionView!
    @IBOutlet weak var componentsView: ComponentsView!
    
    var camera: CaptureDevice!
    var session: CaptureSession!
    
    var metalDevice = MTLCreateSystemDefaultDevice()
    var sourceTexture: MTLTexture?
    var commandQueue: MTLCommandQueue!
    
    var renderPipelineState: MTLRenderPipelineState?
    
    var filterLibrary: FilterLibrary!
    var filterSequence: FilterSequence!
    var shouldRecognize: Bool = false
    var filterFinalTexture: MTLTexture!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        filtersCollectionView.dataSource = self
        filtersCollectionView.delegate = self
        filtersCollectionView.allowsMultipleSelection = true
        
        commandQueue = metalDevice?.makeCommandQueue()
        camera = CaptureDevice(deviceType: .builtInWideAngleCamera, mediaType: .video, devicePosition: .back)
        session = CaptureSession(metalDevice: metalDevice!, captureDevice: camera)
        session.delegate = self
        
        recognizeButton.layer.cornerRadius = recognizeButton.frame.width / 2.0
        
        filterLibrary = FilterLibrary(metalDevice: metalDevice!)
        filterSequence = FilterSequence(metalDevice: metalDevice!, textureSize: session.size)
        initializeRenderPipelineState()
        
        let textDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                 width: Int(session.size.width),
                                                                 height: Int(session.size.height),
                                                                 mipmapped: false)
        textDescr.usage.insert(.shaderWrite)
        filterFinalTexture = metalDevice!.makeTexture(descriptor: textDescr)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        metalView.device = self.metalDevice
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = false
        
        session.start()
//        let imageData: [UInt8]=[255, 0, 0, 255, 255,
//                                  0, 255, 0, 0  , 0  ,
//                                  0, 0  , 0, 255, 255,
//                                  0, 255, 0, 255, 0  ,
//                                255, 0  , 0, 255, 255]
//        let builder = ComponentBuilder(imageData: imageData, imageWidth: 5, imageHeight: 5)
//        let components = builder.findComponents()
//        componentsView.draw(components: components)
    }


    @IBAction func recognizeButtonDidTap(_ sender: UIButton) {
        if sender.isSelected {
            componentsView.clear()
            session.start()
        } else {
            shouldRecognize = true
            session.stop()
        }
        
        sender.isSelected = !sender.isSelected
        sender.backgroundColor = sender.isSelected ? .gray : .red
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
        filterSequence.encode(to: commandBuffer, sourceTexture: texture, destinationTexture: filterFinalTexture)
        
        let renderTexture = filterSequence.isEmpty ? sourceTexture : filterFinalTexture
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)!
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(renderTexture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        
        commandBuffer.addCompletedHandler { (buffer) in
            guard buffer.status == .completed, self.shouldRecognize == true else {
                return
            }
            
            let bytePerPixel: CGFloat = 4.0
            let bytesPerRow = Int(self.session.size.width * bytePerPixel)
            let imageBytesSize = Int(self.session.size.width * self.session.size.height * bytePerPixel)
            var pixelData = [UInt8](repeating: 0, count: imageBytesSize)
            let region = MTLRegionMake2D(0, 0, Int(self.session.size.width), Int(self.session.size.height))
            pixelData.withUnsafeMutableBytes {
                self.filterFinalTexture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            }
            
            var pixelIndex = 0
            let alphaChannelData = pixelData.filter { _ in
                defer { pixelIndex += 1 }
                return pixelIndex % 4 == 0
            }
            
//            FileWriter.write(data: alphaChannelData, to: "alphaChannelData")
            
            let builder = ComponentBuilder(imageData: alphaChannelData, imageWidth: Int(self.session.size.width), imageHeight: Int(self.session.size.height))
            let components = builder.findComponents()
            
            DispatchQueue.main.async { 
                self.componentsView.draw(components: components)
            }
            
            self.shouldRecognize = false
            self.session.stop()
        }
        
        commandBuffer.commit()
    }
}

extension RecognizerViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filterLibrary.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell", for: indexPath) as! FilterCollectionViewCell
        let filterTitle = filterLibrary.filterTitle(at: indexPath.row)
        cell.titleLabel.text = filterTitle
        
        return cell
    }
}

extension RecognizerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! FilterCollectionViewCell
        cell.refreshTitleLabel()
        
        let kernel = filterLibrary.filterKernel(at: indexPath.row)
        filterSequence.add(filter: kernel)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! FilterCollectionViewCell
        cell.refreshTitleLabel()
        
        let kernel = filterLibrary.filterKernel(at: indexPath.row)
        filterSequence.remove(filter: kernel)
    }
}
