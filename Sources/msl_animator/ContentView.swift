import CoreImage
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    // Gemini Integration (Keeping UI specific state here for now or could move to AppState)
    @AppStorage("geminiApiKey") private var apiKey: String = ""
    @State private var prompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationError: String?
    @State private var showGeminiSettings: Bool = true

    private let geminiClient = GeminiClient()

    private var envApiKey: String? {
        ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }

    private var effectiveApiKey: String {
        if let envKey = envApiKey, !envKey.isEmpty {
            return envKey
        }
        return apiKey
    }

    var body: some View {
        VSplitView {
            // Top Section
            HSplitView {
                // Left Column: Gemini Section
                GroupBox(label: Label("Generative AI Shader", systemImage: "sparkles")) {
                    DisclosureGroup("Settings", isExpanded: $showGeminiSettings) {
                        VStack(alignment: .leading, spacing: 10) {
                            if envApiKey != nil {
                                Text("API Key loaded from environment variable GEMINI_API_KEY")
                                    .font(.caption)
                                    .foregroundColor(.green)

                                SecureField(
                                    "Gemini API Key (Environment Variable Active)",
                                    text: .constant("••••••••")
                                )
                                .disabled(true)
                                .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("Gemini API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Text("Describe the shader you want:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextEditor(text: $prompt)
                                .font(.body)
                                .frame(height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4).stroke(
                                        Color.gray.opacity(0.2), lineWidth: 1))

                            if let error = generationError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }

                            Button(action: generateShader) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isGenerating ? "Generating..." : "Generate Shader")
                                }
                            }
                            .disabled(isGenerating || effectiveApiKey.isEmpty || prompt.isEmpty)
                        }
                        .padding(10)
                    }
                }
                .padding()
                .frame(minWidth: 300, maxWidth: .infinity)

                // Right Column: Preview
                VStack {
                    ZStack {
                        Color.black
                        MetalView(renderer: appState.renderer)
                            .aspectRatio(16 / 9, contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()

                    // Controls
                    HStack {
                        Text("Duration:")
                        TextField(
                            "Seconds", value: $appState.duration, formatter: NumberFormatter()
                        )
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        Text("sec")

                        Spacer()
                    }
                    .padding([.horizontal, .bottom])

                    if appState.isExporting {
                        ProgressView(value: appState.exportProgress)
                            .padding()
                    }
                }
                .frame(minWidth: 400, maxWidth: .infinity)
            }
            .frame(minHeight: 300)

            // Bottom Section: Editor
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Fragment Shader (MSL)")
                        .font(.headline)
                        .padding([.leading, .top], 10)

                    if let error = appState.renderer.compilationError {
                        Spacer()
                        Text("Compilation Error")
                            .foregroundColor(.red)
                            .padding([.trailing, .top], 10)
                            .help(error)
                    }
                }

                MonacoEditor(text: $appState.shaderCode)
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: appState.shaderCode) {
                        appState.compileShader()
                    }

                if let error = appState.renderer.compilationError {
                    ScrollView {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption.monospaced())
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                    .background(Color.black.opacity(0.05))
                }
            }
        }
        .padding(0)
        .onAppear {
            appState.compileShader()
        }
        .sheet(isPresented: $appState.showExportDialog) {
            ExportDialog()
        }
    }

    func generateShader() {
        guard !effectiveApiKey.isEmpty, !prompt.isEmpty else { return }

        isGenerating = true
        generationError = nil

        Task {
            do {
                let generatedCode = try await geminiClient.generateShader(
                    prompt: prompt, apiKey: effectiveApiKey)
                await MainActor.run {
                    appState.shaderCode = generatedCode
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.generationError = "Generation failed: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
}
