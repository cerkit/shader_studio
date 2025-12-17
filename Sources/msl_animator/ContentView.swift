import CoreImage
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
                        MetalView(renderer: renderer)
                            .aspectRatio(16 / 9, contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()

                    // Controls
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

                        Button("Save PNG") {
                            saveImage()
                        }
                        .disabled(shaderCode.isEmpty)

                        Button("Export Movie") {
                            exportMovie()
                        }
                        .disabled(isExporting)
                    }
                    .padding([.horizontal, .bottom])

                    if isExporting {
                        ProgressView(value: exportProgress)
                            .padding()
                    }
                }
                .frame(minWidth: 400, maxWidth: .infinity)
            }
            .frame(minHeight: 300)  // Minimum height for top section

            // Bottom Section: Editor
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Fragment Shader (MSL)")
                        .font(.headline)
                        .padding([.leading, .top], 10)

                    if let error = renderer.compilationError {
                        Spacer()
                        Text("Compilation Error")
                            .foregroundColor(.red)
                            .padding([.trailing, .top], 10)
                            .help(error)
                    }
                }

                MonacoEditor(text: $shaderCode)
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: shaderCode) {
                        renderer.compile(source: shaderCode)
                    }

                if let error = renderer.compilationError {
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
                let generatedCode = try await geminiClient.generateShader(
                    prompt: prompt, apiKey: effectiveApiKey)
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

        exporter.export(outputURL: outputURL, duration: duration, width: width, height: height) {
            progress in
            Task { @MainActor in
                self.exportProgress = progress
            }
        } completion: { error in
            Task { @MainActor in
                self.isExporting = false
                self.currentExporter = nil
            }
            if let error = error {
                print("Export failed: \(error)")
            } else {
                print("Export finished to \(outputURL.path)")
                NSWorkspace.shared.open(outputURL)
            }
        }
    }

    func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "shader_preview.png"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save Preview"
        panel.message = "Choose a location to save the shader preview"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                // 1. Create a texture
                let width = 1920
                let height = 1080
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
                descriptor.usage = [.renderTarget, .shaderRead]

                guard let texture = renderer.device.makeTexture(descriptor: descriptor) else {
                    print("Failed to create texture for saving")
                    return
                }

                // 2. Render to it
                if let commandBuffer = renderer.commandQueue.makeCommandBuffer() {
                    let time = Float(Date().timeIntervalSince(renderer.startTime))
                    renderer.encode(
                        commandBuffer: commandBuffer, texture: texture, time: time,
                        resolution: CGSize(width: width, height: height))
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()

                    // 3. Convert to PNG
                    let ciImage = CIImage(
                        mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()])
                    let context = CIContext()

                    if let ciImage = ciImage {
                        // Flip vertically because Metal texture is top-down? Or CIImage expects bottom-up?
                        // Usually Metal textures are top-left origin, CIImage is bottom-left.
                        // Let's check. Standard Metal is top-left. CIImage is bottom-left.
                        // So we might need to flip.
                        let flippedImage = ciImage.transformed(
                            by: CGAffineTransform(scaleX: 1, y: -1).translatedBy(
                                x: 0, y: -CGFloat(height)))

                        do {
                            try context.writePNGRepresentation(
                                of: flippedImage, to: url, format: .RGBA8,
                                colorSpace: CGColorSpaceCreateDeviceRGB())
                            print("Image saved to \(url.path)")
                        } catch {
                            print("Failed to save image: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
