//
//  Filter.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 28.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import MetalPerformanceShaders


/// Represent image filter.
struct Filter {
    let name: String
    let kernel: MPSUnaryImageKernel
}
