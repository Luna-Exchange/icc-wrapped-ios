//
//  File.swift
//  
//
//  Created by Computer on 5/6/24.
//

import Foundation
import UIKit

class LoaderViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.5) // Semi-transparent black background
        
        // Create UIImageView and set the loading image
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)) // Adjust size as needed
        imageView.contentMode = .scaleAspectFit
        imageView.center = view.center
        
        // Replace "loadingImageName" with the name of your loading image asset
        if let loadingImage = UIImage(named: "loadingpage") {
            imageView.image = loadingImage
        }
        
        // Create white loader view
        let loaderViewSize: CGFloat = 50
        let loaderView = UIView(frame: CGRect(x: (imageView.frame.width - loaderViewSize) / 2, y: (imageView.frame.height - loaderViewSize) / 2, width: loaderViewSize, height: loaderViewSize))
        loaderView.backgroundColor = .white
        loaderView.layer.cornerRadius = loaderViewSize / 2
        
        // Add loader view on top of the image view
        imageView.addSubview(loaderView)
        
        view.addSubview(imageView)
    }
}
