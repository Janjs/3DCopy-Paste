//
//  GalleryViewController.swift
//  3D Copy&Paste
//
//  Created by Jan Jiménez Serra on 8/8/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import UIKit

class GalleryViewController: UIViewController {
    
    var capturedImage: UIImage?
    
    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = capt
        // Do any additional setup after loading the view.
    }
    
}
