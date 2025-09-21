import SwiftUI

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImmersed = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Depth Aid MVP")
                .font(.largeTitle).bold()

            Text("Open the immersive space to place depth markers or use the ruler.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Enter Immersive Space") {
                    Task {
                        let result = await openImmersiveSpace(id: "DepthSpace")
                        if case .opened = result { isImmersed = true }
                    }
                }
                .disabled(isImmersed)

                Button("Exit") {
                    Task {
                        await dismissImmersiveSpace()
                        isImmersed = false
                    }
                }
                .disabled(!isImmersed)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview { ContentView() }
