//
//  FilterCollectionViewCell.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 10.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import UIKit

class FilterCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    

    func refreshTitleLabel() {
        titleLabel.backgroundColor = isSelected ? .red : .clear
    }
}
