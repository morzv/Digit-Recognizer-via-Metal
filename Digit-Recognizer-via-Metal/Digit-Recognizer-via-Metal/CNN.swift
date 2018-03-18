//
//  CNN.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 14.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import Foundation
import Metal
import MetalPerformanceShaders
import Accelerate


class CNN {
    let metalDevice: MTLDevice
    var graph: MPSNNGraph!
    
    init(metalDevice: MTLDevice) {
        self.metalDevice = metalDevice
    }
    
    func makeGraph() -> MPSNNGraph {
        let relu = MPSCNNNeuronReLU(device: metalDevice, a: 0)
        let inputImage = MPSNNImageNode(handle: nil)
        
        let conv1 = MPSCNNConvolutionNode(source: inputImage, weights: DataSource(fileName: "conv1",
                                                                                  kernelSize: KernelSize(width: 5, height: 5),
                                                                                  featureChannels: FeatureChannels(input: 1, output: 32),
                                                                                  neuronFilter: relu))
        
        let pool1 = MPSCNNPoolingMaxNode(source: conv1.resultImage, kernelWidth: 2, kernelHeight: 2, strideInPixelsX: 2, strideInPixelsY: 2)
        
        let conv2 = MPSCNNConvolutionNode(source: pool1.resultImage, weights: DataSource(fileName: "conv2",
                                                                                        kernelSize: KernelSize(width: 5, height: 5),
                                                                                        featureChannels: FeatureChannels(input: 32, output: 64),
                                                                                        neuronFilter: relu))
        
        let pool2 = MPSCNNPoolingMaxNode(source: conv2.resultImage, kernelWidth: 2, kernelHeight: 2, strideInPixelsX: 2, strideInPixelsY: 2)
        
        let fullCon1 = MPSCNNFullyConnectedNode(source: pool2.resultImage, weights: DataSource(fileName: "fc1",
                                                                                               kernelSize: KernelSize(width: 7, height: 7),
                                                                                               featureChannels: FeatureChannels(input: 64, output: 1024),
                                                                                               neuronFilter: nil))
        
        let fullCon2 = MPSCNNFullyConnectedNode(source: fullCon1.resultImage, weights: DataSource(fileName: "fc2",
                                                                                                  kernelSize: KernelSize(width: 1, height: 1),
                                                                                                  featureChannels: FeatureChannels(input: 1024, output: 10),
                                                                                                  neuronFilter: nil))
        
        let softmax = MPSCNNSoftMaxNode(source: fullCon2.resultImage)
        
        guard let graph = MPSNNGraph(device: metalDevice,
                                     resultImage: softmax.resultImage) else {
            fatalError("Error: could not initialize graph")
        }
        
        return graph
    }
    
    func recognizeDigit(in inputImage: MPSImage, completionHandler: @escaping (Int) -> () ) {
        if graph == nil {
            graph = makeGraph()
        }
        
        graph.executeAsync(withSourceImages: [inputImage]) { (resultImage, error) in
            guard let image = resultImage else {
                print("Result image is nil")
                return
            }
            
            guard let digit = self.getDigit(finalLayer: image) else {
                print("Cannot recognize digit")
                return
            }
            
            completionHandler(digit)
        }
    }
    
    private func getDigit(finalLayer: MPSImage) -> Int? {
        var result_half_array = [UInt16](repeating: 0, count: 12)
        var result_float_array = [Float](repeating: 0, count: 10)
        for i in 0...2 {
            finalLayer.texture.getBytes(&(result_half_array[4*i]),
                                        bytesPerRow: MemoryLayout<UInt16>.size*1*4,
                                        bytesPerImage: MemoryLayout<UInt16>.size*1*1*4,
                                        from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                                        size: MTLSize(width: 1, height: 1, depth: 1)),
                                        mipmapLevel: 0,
                                        slice: i)
        }
        
        // Metal GPUs use float16 and swift float is 32-bit
        var fullResultVImagebuf = vImage_Buffer(data: &result_float_array, height: 1, width: 10, rowBytes: 10*4)
        var halfResultVImagebuf = vImage_Buffer(data: &result_half_array , height: 1, width: 10, rowBytes: 10*2)

        if vImageConvert_Planar16FtoPlanarF(&halfResultVImagebuf, &fullResultVImagebuf, 0) != kvImageNoError {
            print("Error in vImage")
        }
        
        var max:Float = 0
        var mostProbableDigit = 10
        for i in 0...9 {
            if(max < result_float_array[i]){
                max = result_float_array[i]
                mostProbableDigit = i
            }
        }
        // return label only if prob more than 32%
        return max > 0.32 ? mostProbableDigit : nil
    }
}

fileprivate class DataSource: NSObject, MPSCNNConvolutionDataSource {
    private let fileName: String
    private let fileExtension = "dat"
    private let kernelSize: KernelSize
    private let featureChannels: FeatureChannels
    private let stride: Stride
    private var weightsData: Data?
    private var biasData: Data?
    private let neuron: MPSCNNNeuron?
    
    var weightsPath: String {
        return "weights_\(fileName)"
    }
    
    var biasPath: String {
        return "bias_\(fileName)"
    }
    
    init(fileName: String, kernelSize: KernelSize, featureChannels: FeatureChannels, neuronFilter: MPSCNNNeuron?) {
        self.fileName = fileName
        self.kernelSize = kernelSize
        self.featureChannels = featureChannels
        stride = Stride(x: 1, y: 1)
        neuron = neuronFilter
    }
    
    func dataType() -> MPSDataType {
        return .float32
    }
    
    func descriptor() -> MPSCNNConvolutionDescriptor {
        let descriptor = MPSCNNConvolutionDescriptor(kernelWidth: kernelSize.width,
                                                     kernelHeight: kernelSize.height,
                                                     inputFeatureChannels: featureChannels.input,
                                                     outputFeatureChannels: featureChannels.output,
                                                     neuronFilter: neuron)
        descriptor.strideInPixelsX = stride.x
        descriptor.strideInPixelsY = stride.y
        
        return descriptor
    }
    
    func load() -> Bool {
        guard let weightsUrl = Bundle.main.url(forResource: weightsPath, withExtension: fileExtension),
            let biasUrl = Bundle.main.url(forResource: biasPath, withExtension: fileExtension) else {
                print("Cannot load data")
                return false
        }
        
        do {
            weightsData = try Data(contentsOf: weightsUrl)
            biasData = try Data(contentsOf: biasUrl)
        } catch {
            print("Cannot read data")
            return false
        }
        
        return true
    }
    
    func weights() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(mutating: (weightsData! as NSData).bytes)
    }
    
    func biasTerms() -> UnsafeMutablePointer<Float>? {
        let rawBias = UnsafeMutableRawPointer(mutating: (biasData! as NSData).bytes)
        return rawBias.bindMemory(to: Float.self, capacity: biasData!.count)
    }
    
    func purge() {
        weightsData = nil
        biasData = nil
    }
    
    func label() -> String? {
        return nil
    }
}

fileprivate struct KernelSize {
    let width: Int
    let height: Int
}

fileprivate struct FeatureChannels {
    let input: Int
    let output: Int
}

fileprivate struct Stride {
    let x: Int
    let y: Int
}
