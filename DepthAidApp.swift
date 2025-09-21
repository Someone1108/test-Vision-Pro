//
//  DepthAidApp.swift
//  depth_scale
//
//  Created by Daniel Ng on 21/9/2025.
//

import SwiftUI

@main
struct DepthAidApp: App {
    var body: some Scene {
        // 2D control window
        WindowGroup {
            ContentView()
        }
        .windowStyle(.plain)

        // Immersive 3D space
        ImmersiveSpace(id: "DepthSpace") {
            DepthImmersiveView()
        }
    }
}
