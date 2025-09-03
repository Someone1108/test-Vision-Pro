import SwiftUI

@main
struct DepthAidApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.plain)

        ImmersiveSpace(id: "DepthSpace") {
            DepthImmersiveView()
        }
    }
}

