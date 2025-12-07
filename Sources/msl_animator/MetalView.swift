import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    @ObservedObject var renderer: ShaderRenderer

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = renderer.device
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false  // Allow reading if needed, but mainly for display
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update logic if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalView

        init(_ parent: MetalView) {
            self.parent = parent
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                let commandBuffer = parent.renderer.commandQueue.makeCommandBuffer()
            else { return }

            let time = Float(Date().timeIntervalSince(parent.renderer.startTime))
            let resolution = view.drawableSize

            parent.renderer.encode(
                commandBuffer: commandBuffer, texture: drawable.texture, time: time,
                resolution: resolution)

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
