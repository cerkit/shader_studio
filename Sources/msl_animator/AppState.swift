import Combine
import SwiftUI

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

    // UI Logic for Dialogs
    @Published var showExportDialog = false

    // Dependencies
    let renderer = ShaderRenderer()
    private var currentExporter: VideoExporter?

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
                    let content = try String(contentsOf: url)
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
                        commandBuffer: commandBuffer, texture: texture, time: time,
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

                exporter.export(
                    outputURL: outputURL, duration: self.duration, width: width, height: height
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
}
