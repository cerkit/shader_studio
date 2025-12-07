import Metal
import MetalKit

class ShaderRenderer: NSObject, ObservableObject {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?

    @Published var compilationError: String?

    let startTime: Date

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue()
        else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        self.commandQueue = queue
        self.startTime = Date()
        super.init()
    }

    func compile(source: String) {
        // We'll wrap the user's code with necessary headers and the vertex shader.
        // We assume the user writes a function `fragment float4 fragment_main(...)` or similar,
        // BUT to make it easier, we can provide the signature and let them write the body,
        // OR just let them write the whole fragment function.
        // Let's go with: User writes the fragment function body or the whole function.
        // Actually, to ensure compatibility with our pipeline (arguments), we should probably
        // wrap it or define a strict interface.

        // Let's define a standard header they get for free.
        let fullSource = """
            #include <metal_stdlib>
            using namespace metal;

            struct VertexOut {
                float4 position [[position]];
                float2 uv;
            };

            vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
                float2 positions[4] = {
                    float2(-1, -1),
                    float2( 1, -1),
                    float2(-1,  1),
                    float2( 1,  1)
                };
                
                VertexOut out;
                out.position = float4(positions[vertexID], 0, 1);
                out.uv = positions[vertexID] * 0.5 + 0.5; // 0..1
                return out;
            }

            // User code starts here
            \(source)
            """

        do {
            let library = try device.makeLibrary(source: fullSource, options: nil)
            guard let vertexFunction = library.makeFunction(name: "vertex_main"),
                let fragmentFunction = library.makeFunction(name: "fragment_main")
            else {
                self.compilationError =
                    "Could not find 'fragment_main' function. Make sure your shader has a function named 'fragment_main'."
                return
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            self.compilationError = nil
            print("Shader compiled successfully")
        } catch {
            self.compilationError = error.localizedDescription
            print("Compilation error: \(error)")
        }
    }

    func encode(
        commandBuffer: MTLCommandBuffer, texture: MTLTexture, time: Float, resolution: CGSize
    ) {
        guard let pipelineState = pipelineState else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0, green: 0, blue: 0, alpha: 1)

        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor)
        else { return }

        renderEncoder.setRenderPipelineState(pipelineState)

        var res = SIMD2<Float>(Float(resolution.width), Float(resolution.height))
        renderEncoder.setFragmentBytes(&res, length: MemoryLayout<SIMD2<Float>>.size, index: 0)

        var t = time
        renderEncoder.setFragmentBytes(&t, length: MemoryLayout<Float>.size, index: 1)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}
