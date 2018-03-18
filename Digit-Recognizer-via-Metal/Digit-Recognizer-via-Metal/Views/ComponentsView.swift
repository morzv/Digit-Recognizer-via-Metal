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
        
        rectangles.forEach { rect in
            let path = UIBezierPath(rect: rect)
            path.lineWidth = 1.0
            path.stroke()
        }
    }
    
    func draw(components rectangles: [CGRect]) {
        self.rectangles = rectangles.flatMap { return normalizedRect(from: $0) }
        
        setNeedsDisplay()
    }
    
    func draw(digit: Int, in component: CGRect) {
        let frame = normalizedRect(from: component)
        
        let label = UILabel(frame: frame)
        label.backgroundColor = .white
        label.text = "\(digit)"
        label.font = UIFont.systemFont(ofSize: 20)
        label.alpha = 0.5
        
        addSubview(label)
    }
    
    func clear() {
        rectangles.removeAll()
        subviews.forEach { $0.removeFromSuperview() }
        setNeedsDisplay()
    }
    
    private func normalizedRect(from rect: CGRect) -> CGRect {
        let width = Double(rect.maxX - rect.minX) / 1.2
        let height = Double(rect.maxY - rect.minY) / 1.2
        
        let x = Double(rect.minX) / 2.0 + 2
        let y = Double(rect.minY) / 2.0 + 5
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
}
