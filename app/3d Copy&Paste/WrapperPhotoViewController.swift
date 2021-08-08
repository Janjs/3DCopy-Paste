//
//  WrapperPhotoViewController.swift
//  3D Copy&Paste
//
//  Created by Jan Jiménez Serra on 8/8/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import UIKit
import SwiftUI

class WrapperPhotoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // SwiftUI interop
        let vc = UIHostingController(rootView: PhotogrammetryScreen())
        addChild(vc)
        vc.view.frame = view.bounds
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
    }
    


}
