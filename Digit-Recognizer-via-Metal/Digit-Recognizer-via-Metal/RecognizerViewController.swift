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
    private var recognizeService: RecognizeService!
    private var shouldRecognize: Bool = false
    
    private var filterLibrary: FilterLibrary!
    private var filterSequence: FilterSequence!
    private var recognizedResults = [RecognizedResult]()
    
    private let detailsSegueID = "ShowResults"
    private let filterCellID = "FilterCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recognizeButton.layer.cornerRadius = recognizeButton.frame.width / 2.0
        configureFiltersCollectionView()
        configureSwipe()
        
        guard let metalService = MetalService() else { print("Can't create metal device."); return }
        
        recognizeService = RecognizeService(metalService: metalService)
        recognizeService.delegate = self
        
        guard let renderSevice = RenderService(metalService: metalService) else { return }
        self.renderService = renderSevice
        
        configureMetalView()
        filterLibrary = FilterLibrary(metalDevice: metalService.device)
        filterSequence = FilterSequence(metalDevice: metalService.device, textureSize: renderSevice.session.size)
        
        renderSevice.session.start()
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
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    func draw(in view: MTKView) {
        renderService.render(view: view, with: filterSequence) { (finalTexture) in
            guard self.shouldRecognize else { return }
            
            self.shouldRecognize = false
            self.renderService.session.stop()
            
            self.recognizeService.recognizeDigit(in: finalTexture, with: self.renderService.session.size)
        }
    }
}

extension RecognizerViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filterLibrary.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: filterCellID, for: indexPath) as! FilterCollectionViewCell
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

extension RecognizerViewController: RecognizeServiceDelegate {
    func recognizeService(_ service: RecognizeService, didFindComponents components: [CGRect]) {
        DispatchQueue.main.async {
            self.componentsView.draw(components: components)
        }
    }
    
    func recognizeService(_ service: RecognizeService, didRecognize result: RecognizedResult, in component: CGRect) {
        DispatchQueue.main.async {
            self.componentsView.draw(digit: result.digit, in: component)
        }
        
        self.recognizedResults.append(result)
    }
}
