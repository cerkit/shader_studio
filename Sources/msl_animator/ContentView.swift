import SwiftUI

struct ContentView: View {
    @State private var shaderCode: String = """
    // Simple Gradient Shader
    #include <metal_stdlib>
    using namespace metal;

    fragment float4 fragment_main(VertexOut in [[stage_in]],
                                  constant float2& u_resolution [[buffer(0)]],
                                  constant float& u_time [[buffer(1)]]) {
        float2 uv = in.uv;
        float3 color = float3(uv.x, uv.y, 0.5 + 0.5 * sin(u_time));
        return float4(color, 1.0);
    }
    """
    @State private var duration: Double = 10.0
    @State private var durationString: String = "10.0"
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @StateObject private var renderer = ShaderRenderer()
    @State private var currentExporter: VideoExporter?
    
    // Gemini Integration
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
        HSplitView {
            VSplitView {
                // Gemini Section
                GroupBox(label: Label("Generative AI Shader", systemImage: "sparkles")) {
                    DisclosureGroup("Settings", isExpanded: $showGeminiSettings) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let _ = envApiKey {
                                Text("API Key loaded from environment variable GEMINI_API_KEY")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                SecureField("Gemini API Key (Environment Variable Active)", text: .constant("••••••••"))
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
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            
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
                .padding([.horizontal, .top])
                .frame(minHeight: 200) // Ensure it has a reasonable default height

                VStack(alignment: .leading) {
                    Text("Fragment Shader (MSL)")
                        .font(.headline)
                        .padding(.leading)
                    TextEditor(text: $shaderCode)
                        .font(.monospaced(.body)())
                        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: shaderCode) {
                            renderer.compile(source: shaderCode)
                        }
                    
                    if let error = renderer.compilationError {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }

            VStack {
                // Preview
                ZStack {
                    Color.black
                    MetalView(renderer: renderer)
                        .aspectRatio(16/9, contentMode: .fit)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow it to fill available space
                .padding()

                HStack {
                    Text("Duration:")
                    TextField("Seconds", text: $durationString)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: durationString) {
                            if let val = Double(durationString) {
                                duration = val
                            }
                        }
                    Text("sec")

                    Spacer()

                    Button("Save .metal") {
                        saveShader()
                    }
                    .disabled(shaderCode.isEmpty)

                    Button("Export Movie") {
                        exportMovie()
                    }
                    .disabled(isExporting)
                }
                .padding()
                .layoutPriority(1) // Ensure controls are always visible

                if isExporting {
                    ProgressView(value: exportProgress)
                        .padding()
                        .layoutPriority(1)
                }
            }
            .frame(minWidth: 400)
        }
        .padding()
        .onAppear {
            renderer.compile(source: shaderCode)
        }
    }

    func saveShader() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.sourceCode]
        panel.nameFieldStringValue = "shader.metal"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save Shader"
        panel.message = "Choose a location to save your Metal shader"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let fileContent = "// Prompt: \(self.prompt)\n\n\(self.shaderCode)"
                
                do {
                    try fileContent.write(to: url, atomically: true, encoding: .utf8)
                    print("Shader saved to \(url.path)")
                } catch {
                    print("Failed to save shader: \(error.localizedDescription)")
                }
            }
        }
    }

    func generateShader() {
        guard !effectiveApiKey.isEmpty, !prompt.isEmpty else { return }
        
        isGenerating = true
        generationError = nil
        
        Task {
            do {
                let generatedCode = try await geminiClient.generateShader(prompt: prompt, apiKey: effectiveApiKey)
                await MainActor.run {
                    self.shaderCode = generatedCode
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.generationError = "Generation failed: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }

    func exportMovie() {
        isExporting = true
        exportProgress = 0.0
        
        let exporter = VideoExporter(renderer: renderer)
        self.currentExporter = exporter
        
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .moviesDirectory, in: .userDomainMask)
        guard let moviesDir = urls.first else { return }
        
        let outputURL = moviesDir.appendingPathComponent("shader_animation.mov")
        
        // Use a fixed resolution for export, e.g., 1920x1080
        let width = 1920
        let height = 1080
        
        exporter.export(outputURL: outputURL, duration: duration, width: width, height: height) { progress in
            self.exportProgress = progress
        } completion: { error in
            self.isExporting = false
            self.currentExporter = nil
            if let error = error {
                print("Export failed: \(error)")
            } else {
                print("Export finished to \(outputURL.path)")
                NSWorkspace.shared.open(outputURL)
            }
        }
    }
}
