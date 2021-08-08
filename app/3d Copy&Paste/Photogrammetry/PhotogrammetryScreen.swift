//
//  Photogrammetry.swift
//  3D Copy&Paste
//
//  Created by Jan Jiménez Serra on 8/8/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import SwiftUI

struct PhotogrammetryScreen: View {
    @StateObject var model = CameraViewModel()
    
    var body: some View {
        ContentView(model: model)
    }
}
