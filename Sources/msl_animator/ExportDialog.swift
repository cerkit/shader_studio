import SwiftUI

struct ExportDialog: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var durationString: String = "10.0"

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Movie")
                .font(.headline)

            VStack(alignment: .leading) {
                Text("Duration (seconds):")
                TextField("Duration", text: $durationString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Export") {
                    if let duration = Double(durationString) {
                        appState.duration = duration
                        dismiss()

                        // Small delay to allow sheet to dismiss before opening save panel
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            appState.exportMovie()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300)
        .onAppear {
            durationString = String(format: "%.1f", appState.duration)
        }
    }
}
