//
//  FilterCollectionViewCell.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 10.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import UIKit

/// Represent one filter from FilterLibrary.
class FilterCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!

    override func awakeFromNib() {
        titleLabel.layer.borderColor = UIColor.black.cgColor
        titleLabel.layer.borderWidth = 1.0
        titleLabel.layer.cornerRadius = 3.0
        titleLabel.clipsToBounds = true
    }
    
    override var isSelected: Bool {
        didSet {
            titleLabel.backgroundColor = isSelected ? .red : .clear
            titleLabel.textColor = isSelected ? .white : .black
        }
    }
}
