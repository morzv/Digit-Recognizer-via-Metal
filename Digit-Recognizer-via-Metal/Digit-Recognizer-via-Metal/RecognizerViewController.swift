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
    
    private var renderService: RenderService!
    
//    private var sourceTexture: MTLTexture?
//    private var filterFinalTexture: MTLTexture!

    private var cnn: CNN!
    private var filterLibrary: FilterLibrary!
    private var filterSequence: FilterSequence!
    private var shouldRecognize: Bool = false
    private var recognizedResults = [RecognizedResult]()

    private let detailsSegueID = "ShowResults"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recognizeButton.layer.cornerRadius = recognizeButton.frame.width / 2.0
        configureFiltersCollectionView()
        configureSwipe()
        
        guard let metalService = MetalService() else { print("Can't create metal device."); return }
        
        guard let recognizeService = RenderService(metalService: metalService) else { return }
        self.renderService = recognizeService
        
        configureMetalView()
        filterLibrary = FilterLibrary(metalDevice: metalService.device)
        filterSequence = FilterSequence(metalDevice: metalService.device, textureSize: recognizeService.session.size)
        
        cnn = CNN(metalDevice: metalService.device)
        recognizeService.session.start()
    }

    @IBAction func recognizeButtonDidTap(_ sender: UIButton) {
        filterSequence.clear()
        recognizedResults.removeAll()
        
        if sender.isSelected {
            componentsView.clear()
            renderService.session.start()
            for index in 0..<filterLibrary.count {
                let indexPath = IndexPath(item: index, section: 0)
                filtersCollectionView.deselectItem(at: indexPath, animated: false)
                self.collectionView(filtersCollectionView, didDeselectItemAt: indexPath)
            }
        } else {
            shouldRecognize = true
            renderService.session.stop()
            for index in 0..<filterLibrary.count {
                let indexPath = IndexPath(item: index, section: 0)
                filtersCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
                self.collectionView(filtersCollectionView, didSelectItemAt: indexPath)
            }
        }
        
        sender.isSelected = !sender.isSelected
        sender.backgroundColor = sender.isSelected ? .gray : .red
    }
    
    @objc func showDetailsViewController() {
        performSegue(withIdentifier: detailsSegueID, sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == detailsSegueID,
            let resultsVC = segue.destination as? RecognizingResultViewController else { return }
        
        resultsVC.results = recognizedResults
    }
    
    private func configureFiltersCollectionView() {
        let blurEffect = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = filtersCollectionView.frame
        filtersCollectionView.backgroundColor = .clear
        filtersCollectionView.backgroundView = blurView
        filtersCollectionView.dataSource = self
        filtersCollectionView.delegate = self
        filtersCollectionView.allowsMultipleSelection = true
    }
    
    private func configureSwipe() {
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(showDetailsViewController))
        swipe.direction = .up
        metalView.addGestureRecognizer(swipe)
    }
    
    private func configureMetalView() {
        metalView.device = renderService.metalService.device
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = false
    }
}

extension RecognizerViewController : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {

        renderService.render(view: view, with: filterSequence) { (buffer) in
            guard buffer.status == .completed, self.shouldRecognize == true else {
                return
            }
            
            let bytePerPixel = 4
            let bytesPerRow = self.renderService.session.size.width * bytePerPixel
            let imageBytesSize = self.renderService.session.size.width * self.renderService.session.size.height * bytePerPixel
            var pixelData = [UInt8](repeating: 0, count: imageBytesSize)
            let region = MTLRegionMake2D(0, 0, self.renderService.session.size.width, self.renderService.session.size.height)
            pixelData.withUnsafeMutableBytes {
                self.renderService.filterFinalTexture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            }
            
            var pixelIndex = 0
            let alphaChannelData = pixelData.filter { _ in
                defer { pixelIndex += 1 }
                return pixelIndex % 4 == 0
            }
            
            let builder = ComponentBuilder(imageData: alphaChannelData, imageWidth: self.renderService.session.size.width, imageHeight: self.renderService.session.size.height)
            let components = builder.findComponents()
            
            DispatchQueue.main.async {
                self.componentsView.draw(components: components)
            }
            
            let imageProvider = ImageProvider(rawData: alphaChannelData,
                                              imageSize: self.renderService.session.size,
                                              cropSize: CGSize(width: 24, height: 24))
            let alphaChannelImage = imageProvider.createImage()
            
            for component in components {
                guard let croppedImage = alphaChannelImage?.cropping(to: component),
                    let cnnImage = imageProvider.imageForCNN(from: croppedImage)  else { continue }

//                let debugCropppedImage = UIImage(cgImage: croppedImage)
//                let debugCNNImage = UIImage(cgImage: cnnImage)
//                let debugCNNImage2 = UIImage(cgImage: cnnImage)
                
                let texture = self.renderService.metalService.createTexture(for: .r8Unorm, size: (width: 28, height: 28))
                
                let inputImage = MPSImage(texture: texture!, featureChannels: 1)
                inputImage.texture.replace(region: MTLRegionMake2D(0, 0, 28, 28),
                                           mipmapLevel: 0,
                                           withBytes: CFDataGetBytePtr(cnnImage.dataProvider!.data!),
                                           bytesPerRow: 28)
                
                self.cnn.recognizeDigit(in: inputImage, completionHandler: { digit in
                    DispatchQueue.main.async {
                        self.componentsView.draw(digit: digit, in: component)
                    }
                    
                    let result = RecognizedResult(digit: digit, image: UIImage(cgImage: cnnImage))
                    self.recognizedResults.append(result)
                })
            }
            
            self.shouldRecognize = false
            self.renderService.session.stop()
        }
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
