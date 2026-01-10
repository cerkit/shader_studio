import SwiftUI

struct ScenesConfigView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack {
            Text("Configure Scene Presets")
                .font(.headline)
                .padding(.top)

            TabView {
                ForEach(0..<4) { index in
                    VStack(alignment: .leading) {
                        Text("Preset \(index + 1) Code")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // We use a Binding to the specific index of the presets array
                        // MonacoEditor expects a binding.
                        if appState.presets.indices.contains(index) {
                            MonacoEditor(
                                text: Binding(
                                    get: { appState.presets[index] },
                                    set: { appState.presets[index] = $0 }
                                ))
                        } else {
                            Text("Error loading preset")
                        }
                    }
                    .padding()
                    .tabItem {
                        Text("Scene \(index + 1)")
                    }
                }
            }
            .padding()

            HStack {
                Spacer()
                Button("Save All Presets") {
                    appState.savePresets()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
