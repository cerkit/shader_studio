import SwiftUI

struct PresentationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MetalView(renderer: appState.renderer)
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("Shader Preview")
    }
}
