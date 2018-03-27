//
//  RecognizingResultViewController.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 26.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import UIKit

class RecognizingResultViewController: UIViewController {

    @IBOutlet weak var resultCollectionView: UICollectionView!
    
    var results: [RecognizingResult]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        resultCollectionView.dataSource = self
    }

    @IBAction func closeButtonDidTap(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension RecognizingResultViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return results?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecognizedDigitCollectionViewCell", for: indexPath) as! RecognizedDigitCollectionViewCell
        
        if let result = results?[indexPath.row] {
            cell.imageView.image = result.image
            cell.digitLabel.text = result.digit.description
        }
        
        return cell
    }
}

extension RecognizingResultViewController: UIBarPositioningDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
