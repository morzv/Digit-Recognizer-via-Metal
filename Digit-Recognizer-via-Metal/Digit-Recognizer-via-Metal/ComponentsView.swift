//
//  ComponentsView.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 11.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import UIKit

class ComponentsView: UIView {
    
    private var rectangles = [CGRect]()
    
    override func draw(_ rect: CGRect) {
        UIColor.red.setStroke()
        
        for rect in rectangles {
            let path = UIBezierPath(rect: rect)
            path.lineWidth = 2.0
            path.stroke()
        }
    }
    
    func draw(components rectangles: [CGRect]) {
        self.rectangles = rectangles
        setNeedsDisplay()
    }
    
    func clear() {
        rectangles.removeAll()
        setNeedsDisplay()
    }
}
