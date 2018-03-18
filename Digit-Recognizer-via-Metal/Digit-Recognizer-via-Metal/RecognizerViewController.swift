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
    
    var cnn: CNN!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let blurEffect = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = filtersCollectionView.frame
        filtersCollectionView.backgroundColor = .clear
        filtersCollectionView.backgroundView = blurView
        
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
                                                                 width: session.size.width,
                                                                 height: session.size.height,
                                                                 mipmapped: false)
        textDescr.usage.insert(.shaderWrite)
        filterFinalTexture = metalDevice!.makeTexture(descriptor: textDescr)
        
        cnn = CNN(metalDevice: metalDevice!)
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
        filterSequence.clear()
    
        if sender.isSelected {
            componentsView.clear()
            session.start()
            for index in 0..<filterLibrary.count {
                let indexPath = IndexPath(item: index, section: 0)
                filtersCollectionView.deselectItem(at: indexPath, animated: false)
                self.collectionView(filtersCollectionView, didDeselectItemAt: indexPath)
            }
        } else {
            shouldRecognize = true
            session.stop()
            for index in 0..<filterLibrary.count {
                let indexPath = IndexPath(item: index, section: 0)
                filtersCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
                self.collectionView(filtersCollectionView, didSelectItemAt: indexPath)
            }
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
            
            let builder = ComponentBuilder(imageData: alphaChannelData, imageWidth: self.session.size.width, imageHeight: self.session.size.height)
            let components = builder.findComponents()
            
            DispatchQueue.main.async {
                self.componentsView.draw(components: components)
            }
            
            let imageProvider = ImageProvider(rawData: alphaChannelData, imageWidth: self.session.size.width, imageHeight: self.session.size.height, cropSize: CGSize(width: 24, height: 24))
            let alphaChannelImage = imageProvider.createImage()
//            let debugAlpaImage = UIImage(cgImage: alphaChannelImage!)
            
            for component in components {
                guard let croppedImage = alphaChannelImage?.cropping(to: component) else {
                    continue
                }
//                let debugCropppedImage = UIImage(cgImage: croppedImage)
                
                let cnnImage = imageProvider.imageForCNN(from: croppedImage)
//                let debugCNNImage = UIImage(cgImage: cnnImage)
                
//                let debugCNNImage2 = UIImage(cgImage: cnnImage)
                
                let textDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 28, height: 28, mipmapped: false)
                let texture = self.metalDevice?.makeTexture(descriptor: textDescr)
                
                let inputImage = MPSImage(texture: texture!, featureChannels: 1)
                
                inputImage.texture.replace(region: MTLRegionMake2D(0, 0, 28, 28), mipmapLevel: 0,
                                           withBytes: CFDataGetBytePtr(cnnImage.dataProvider!.data!), bytesPerRow: 28)
                
                self.cnn.recognizeDigit(in: inputImage, completionHandler: { (digit) in
                    print("RECOGNIZED: \(String(describing: digit))")
                    DispatchQueue.main.async {
                        self.componentsView.draw(digit: digit, in: component)
                    }
                })
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
        let filterTitle = filterLibrary[indexPath.row].name
        cell.titleLabel.text = filterTitle
        
        return cell
    }
}

extension RecognizerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let kernel = filterLibrary[indexPath.row].kernel
        filterSequence.add(filter: kernel)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let kernel = filterLibrary[indexPath.row].kernel
        filterSequence.remove(filter: kernel)
    }
}
