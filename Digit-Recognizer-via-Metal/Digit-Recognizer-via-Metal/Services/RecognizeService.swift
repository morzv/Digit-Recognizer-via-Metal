//
//  RecognizeService.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 31.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import CoreGraphics
import MetalKit
import MetalPerformanceShaders


/// Protocol for result of recognize service.
protocol RecognizeServiceDelegate: class {
    /// Signal, when service found some area, which can contain digit.
    ///
    /// - Parameters:
    ///   - service: Service, which found component.
    ///   - components: Sequence of rects, which can contain digit.
    func recognizeService(_ service: RecognizeService, didFindComponents components: [CGRect])
    
    /// Signal, when service detect digit in some area.
    ///
    /// - Parameters:
    ///   - service: Service, which recognize digit.
    ///   - result: Recognized result.
    ///   - component: Rect, which contains recognized digit.
    func recognizeService(_ service: RecognizeService, didRecognize result: RecognizedResult, in component: CGRect)
}

/// Responsible for digit detection and recognizing.
class RecognizeService {
    weak var delegate: RecognizeServiceDelegate?
    
    private let cnn: CNN
    private let metalService: MetalService
    
    init(metalService: MetalService) {
        self.metalService = metalService
        cnn = CNN(metalDevice: metalService.device)
    }
    
    /// Detect digit position and recognize its class.
    ///
    /// - Parameters:
    ///   - texture: Binarized texture. Source of digit detection and recognition.
    ///   - size: Size of texture.
    func recognizeDigit(in texture: MTLTexture, with size: (width: Int, height: Int)) {
        let alphaChannelData = createAlphaChannelData(from: texture, with: size)
        
        let builder = ComponentProvider(imageData: alphaChannelData, size: size)
        let components = builder.findComponents()
        delegate?.recognizeService(self, didFindComponents: components)
        
        let imageProvider = ImageProvider(rawData: alphaChannelData, imageSize: size, cropSize: CGSize(width: 24, height: 24))
        let alphaChannelImage = imageProvider.createImage()
        
        for component in components {
            guard let croppedImage = alphaChannelImage?.cropping(to: component),
                let cnnImage = imageProvider.imageForCNN(from: croppedImage)  else { continue }
            
            let texture = metalService.createTexture(for: .r8Unorm, size: (width: 28, height: 28))
            
            let inputImage = MPSImage(texture: texture!, featureChannels: 1)
            inputImage.texture.replace(region: MTLRegionMake2D(0, 0, 28, 28),
                                       mipmapLevel: 0,
                                       withBytes: CFDataGetBytePtr(cnnImage.dataProvider!.data!),
                                       bytesPerRow: 28)
            
            cnn.recognizeDigit(in: inputImage, completionHandler: { digit in
                let result = RecognizedResult(digit: digit, image: UIImage(cgImage: cnnImage))
                self.delegate?.recognizeService(self, didRecognize: result, in: component)
            })
        }
    }
    
    private func createAlphaChannelData(from texture: MTLTexture, with size: (width: Int, height: Int)) -> [UInt8] {
        let bytePerPixel = 4
        let bytesPerRow = size.width * bytePerPixel
        let imageBytesSize = size.width * size.height * bytePerPixel
        var pixelData = [UInt8](repeating: 0, count: imageBytesSize)
        let region = MTLRegionMake2D(0, 0, size.width, size.height)
        pixelData.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        
        var pixelIndex = 0
        let alphaChannelData = pixelData.filter { _ in
            defer { pixelIndex += 1 }
            return pixelIndex % 4 == 0
        }
        
        return alphaChannelData
    }
}
