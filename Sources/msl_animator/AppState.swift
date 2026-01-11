import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class AppState: ObservableObject {
    @Published var shaderCode: String = """
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
    @Published var duration: Double = 10.0
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0

    // Image to Shader Logic
    @Published var selectedImageData: Data?
    @Published var selectedImageName: String?

    // UI Logic for Dialogs
    @Published var showExportDialog = false

    // Scene Presets
    @Published var presets: [String] = []

    // Dependencies
    let renderer = ShaderRenderer()
    let audioController = AudioController()
    private var currentExporter: VideoExporter?

    init() {
        loadPresets()
    }

    func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an image to use as reference"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    // Convert to JPEG for consistent format and reasonable size
                    if let tiffData = image.tiffRepresentation,
                        let bitmap = NSBitmapImageRep(data: tiffData),
                        let jpegData = bitmap.representation(
                            using: .jpeg, properties: [.compressionFactor: 0.8])
                    {
                        self.selectedImageData = jpegData
                        self.selectedImageName = url.lastPathComponent
                        print("Image loaded: \(self.selectedImageName ?? "unknown")")
                    }
                }
            }
        }
    }

    func clearImage() {
        self.selectedImageData = nil
        self.selectedImageName = nil
    }

    func loadAudio(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a WAV audio file"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.audioController.load(url: url)

                // Construct prompt based on analysis
                var promptAddon = ""
                if self.audioController.isEnergetic {
                    promptAddon =
                        "The music is energetic. Use vibrant colors like orange, red, and yellow. Make it react strongly to u_audio."
                } else {
                    promptAddon =
                        "The music is ambient and slow. Use gradient shades of blue and purple. Make it react gently to u_audio."
                }

                promptAddon += " Mirror the resulting image on the horizontal and vertical axis."

                completion(promptAddon)
            }
        }
    }

    func compileShader() {
        renderer.compile(source: shaderCode)
    }

    // MARK: - File Actions

    func loadShader() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.sourceCode]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a Metal shader file"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.shaderCode = content
                        self.compileShader()
                    }
                } catch {
                    print("Failed to load shader: \(error.localizedDescription)")
                }
            }
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
                do {
                    try self.shaderCode.write(to: url, atomically: true, encoding: .utf8)
                    print("Shader saved to \(url.path)")
                } catch {
                    print("Failed to save shader: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Export Actions

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

                guard let texture = self.renderer.device.makeTexture(descriptor: descriptor) else {
                    print("Failed to create texture for saving")
                    return
                }

                // 2. Render to it
                if let commandBuffer = self.renderer.commandQueue.makeCommandBuffer() {
                    let time = Float(Date().timeIntervalSince(self.renderer.startTime))
                    self.renderer.encode(
                        commandBuffer: commandBuffer, texture: texture, time: time, audioLevel: 0.0,
                        resolution: CGSize(width: width, height: height))
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()

                    // 3. Convert to PNG
                    let ciImage = CIImage(
                        mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()])
                    let context = CIContext()

                    if let ciImage = ciImage {
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

    func exportMovie(width: Int = 1920, height: Int = 1080) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.quickTimeMovie]
        panel.nameFieldStringValue = "shader_animation.mov"
        panel.canCreateDirectories = true
        panel.title = "Export Movie"

        panel.begin { response in
            if response == .OK, let outputURL = panel.url {
                self.isExporting = true
                self.exportProgress = 0.0

                let exporter = VideoExporter(renderer: self.renderer)
                self.currentExporter = exporter

                let width = 1920
                let height = 1080

                // Capture audio controller to safe processing
                // Assuming audioController is MainActor, we need to be careful.
                // But export happens on background?
                // AudioController.level(at:) only reads existing immutable array (mostly).
                // However AudioController is MainActor.
                // We should grab the data or make level(at:) nonisolated if possible and safe.
                // `audioSamples` is private var.
                // Better: Capture the closure if it can run safely?
                // Actually, AudioController is @MainActor. Calling level(at:) from background thread will require excessive awaiting.
                // Let's make `level(at:)` nonisolated? Accessing `audioSamples` (Array) from multiple threads is unsafe if it is verified being mutated.
                // Mutations happen only on `analyze` (MainActor). Reads happen here.
                // If we ensure no mutation during export (reasonable), we can maybe make a copy for export, or just access it.
                // Safest: Copy the samples out to a helper struct/class for the exporter?
                // Or just `await` inside the provider? The provider expects (TimeInterval) -> Float immediately (synchronous).
                // So we can't await.

                // Solution: Extract the provider logic into a standalone safe struct or closure that captures the necessary data (samples, sampleRate) *before* export starts.

                let samples = self.audioController.getSamples()  // We need to expose this
                let sampleRate = self.audioController.getSampleRate()

                let audioProvider: (TimeInterval) -> Float = { time in
                    guard !samples.isEmpty else { return 0.0 }
                    let index = Int(time * sampleRate)
                    guard index >= 0 && index < samples.count else { return 0.0 }
                    let windowSize = Int(0.05 * sampleRate)
                    let start = max(0, index - windowSize / 2)
                    let end = min(samples.count, index + windowSize / 2)

                    var sumSquares: Float = 0
                    var count = 0

                    // Unsafe calculation optimization? or simple loop
                    for i in start..<end {
                        let s = samples[i]
                        sumSquares += s * s
                        count += 1
                    }

                    if count == 0 { return 0.0 }
                    let rms = sqrt(sumSquares / Float(count))
                    let minDb: Float = -60.0
                    let db = rms > 0 ? 20 * log10(rms) : -160.0
                    let clampedDb = max(minDb, db)
                    return (clampedDb - minDb) / abs(minDb)
                }

                exporter.export(
                    outputURL: outputURL, duration: self.duration, width: width, height: height,
                    audioProvider: audioProvider
                ) { progress in
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
        }
    }

    // MARK: - Scene Presets Logic

    func loadPresets() {
        var loadedPresets: [String] = []
        for i in 0..<4 {
            if let saved = UserDefaults.standard.string(forKey: "Preset_\(i)") {
                loadedPresets.append(saved)
            } else {
                // Default empty or basic shader for new slots
                loadedPresets.append(ShaderDefaults.defaultShader)
            }
        }
        self.presets = loadedPresets
    }

    func savePresets() {
        for (i, code) in presets.enumerated() {
            if i < 4 {
                UserDefaults.standard.set(code, forKey: "Preset_\(i)")
            }
        }
    }
}

struct ShaderDefaults {
    static let defaultShader = """
        #include <metal_stdlib>
        using namespace metal;

        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                      constant float2& u_resolution [[buffer(0)]],
                                      constant float& u_time [[buffer(1)]]) {
            return float4(0.0, 0.0, 0.0, 1.0);
        }
        """
}
