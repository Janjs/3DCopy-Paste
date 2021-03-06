//
//  EntryViewController.swift
//  3D Copy&Paste
//
//  Created by Jan Jiménez Serra on 6/8/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import UIKit
import SwiftUI

class EntryViewController: UIViewController {

    @IBOutlet weak var PhotogrammetryButton: UIButton!
    @IBOutlet weak var LidarButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        createStackView()
    }
    
    func createStackView(){
        let stackView = UIStackView(arrangedSubviews: [PhotogrammetryButton, LidarButton])
        stackView.frame = view.bounds
        
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        
        view.addSubview(stackView)
    }
    
    /*
    @objc func didTapButton() {
        // SwiftUI interop
        let vc = UIHostingController(rootView: PhotogrammetryScreen())
        addChild(vc)
        vc.view.frame = view.bounds
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
    }*/
}
