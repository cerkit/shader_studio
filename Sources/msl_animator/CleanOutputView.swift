import SwiftUI

struct CleanOutputView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            MetalView(
                renderer: appState.renderer,
                audioController: appState.audioController
            )
            .edgesIgnoringSafeArea(.all)
        }
    }
}
