import AVFoundation
import CoreImage
import Metal
import MetalKit

class VideoExporter: ObservableObject, @unchecked Sendable {
    let renderer: ShaderRenderer
    private var currentSession: ExportSession?

    init(renderer: ShaderRenderer) {
        self.renderer = renderer
    }

    func export(
        outputURL: URL, duration: Double, width: Int, height: Int,
        audioProvider: ((TimeInterval) -> Float)? = nil,
        progress: @escaping @Sendable (Double) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) {
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            completion(
                NSError(
                    domain: "VideoExporter", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create AVAssetWriter"]))
            return
        }

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ])

        if assetWriter.canAdd(writerInput) {
            assetWriter.add(writerInput)
        } else {
            completion(
                NSError(
                    domain: "VideoExporter", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not add input to asset writer"]))
            return
        }

        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        // Create a texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, renderer.device, nil, &textureCache)
        guard let cache = textureCache else {
            completion(
                NSError(
                    domain: "VideoExporter", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create texture cache"]))
            return
        }

        let fps = 60
        let totalFrames = Int(duration * Double(fps))
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        let session = ExportSession(
            totalFrames: totalFrames, writerInput: writerInput, assetWriter: assetWriter,
            adaptor: pixelBufferAdaptor, renderer: renderer, cache: cache,
            frameDuration: frameDuration, width: width, height: height,
            audioProvider: audioProvider, progress: progress, completion: completion)

        session.onFinish = { [weak self] in
            self?.currentSession = nil
        }

        self.currentSession = session
        session.start()
    }

    class ExportSession: @unchecked Sendable {
        var frameCount = 0
        let totalFrames: Int
        let writerInput: AVAssetWriterInput
        let assetWriter: AVAssetWriter
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
        let renderer: ShaderRenderer
        let cache: CVMetalTextureCache
        let frameDuration: CMTime
        let width: Int
        let height: Int
        let audioProvider: ((TimeInterval) -> Float)?
        let progress: @Sendable (Double) -> Void
        let completion: @Sendable (Error?) -> Void
        var onFinish: (() -> Void)?

        init(
            totalFrames: Int, writerInput: AVAssetWriterInput, assetWriter: AVAssetWriter,
            adaptor: AVAssetWriterInputPixelBufferAdaptor, renderer: ShaderRenderer,
            cache: CVMetalTextureCache, frameDuration: CMTime, width: Int, height: Int,
            audioProvider: ((TimeInterval) -> Float)?,
            progress: @escaping @Sendable (Double) -> Void,
            completion: @escaping @Sendable (Error?) -> Void
        ) {
            self.totalFrames = totalFrames
            self.writerInput = writerInput
            self.assetWriter = assetWriter
            self.adaptor = adaptor
            self.renderer = renderer
            self.cache = cache
            self.frameDuration = frameDuration
            self.width = width
            self.height = height
            self.audioProvider = audioProvider
            self.progress = progress
            self.completion = completion
        }

        func start() {
            print("ExportSession: Starting export. Total frames: \(totalFrames)")

            guard adaptor.pixelBufferPool != nil else {
                print("ExportSession: Error - Pixel buffer pool is nil")
                let completion = self.completion
                DispatchQueue.main.async {
                    completion(
                        NSError(
                            domain: "VideoExporter", code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "Pixel buffer pool is nil"]))
                }
                return
            }

            writerInput.requestMediaDataWhenReady(
                on: DispatchQueue(label: "com.mslanimator.export.session")
            ) { [weak self] in
                guard let self = self else {
                    print("ExportSession: Self is nil in requestMediaDataWhenReady")
                    return
                }

                print(
                    "ExportSession: requestMediaDataWhenReady called. isReady: \(self.writerInput.isReadyForMoreMediaData)"
                )

                while self.writerInput.isReadyForMoreMediaData {
                    if self.assetWriter.status == .failed {
                        print(
                            "ExportSession: Asset writer failed: \(self.assetWriter.error?.localizedDescription ?? "unknown")"
                        )
                        let completion = self.completion
                        let error = self.assetWriter.error
                        let onFinish = self.onFinish
                        DispatchQueue.main.async {
                            completion(error)
                            onFinish?()
                        }
                        return
                    }

                    if self.frameCount >= self.totalFrames {
                        print("ExportSession: Finished all frames. Marking as finished.")
                        self.writerInput.markAsFinished()
                        self.assetWriter.finishWriting {
                            print("ExportSession: Asset writer finished writing.")
                            let completion = self.completion
                            let onFinish = self.onFinish
                            DispatchQueue.main.async {
                                completion(nil)
                                onFinish?()
                            }
                        }
                        return
                    }

                    let presentationTime = CMTimeMultiply(
                        self.frameDuration, multiplier: Int32(self.frameCount))
                    let time = Float(presentationTime.seconds)

                    // Create pixel buffer
                    var pixelBuffer: CVPixelBuffer?
                    let poolCreateResult = CVPixelBufferPoolCreatePixelBuffer(
                        kCFAllocatorDefault, self.adaptor.pixelBufferPool!, &pixelBuffer)

                    guard poolCreateResult == kCVReturnSuccess, let pb = pixelBuffer else {
                        print(
                            "ExportSession: Failed to create pixel buffer. Error: \(poolCreateResult)"
                        )
                        // Break the loop to yield execution. If we are just waiting for pool, we might be called again.
                        // But if we are stuck, we might need to fail.
                        // Let's try to yield.
                        break
                    }

                    // Create Metal texture
                    var cvTexture: CVMetalTexture?
                    let textureCreateResult = CVMetalTextureCacheCreateTextureFromImage(
                        kCFAllocatorDefault,
                        self.cache,
                        pb,
                        nil,
                        .bgra8Unorm,
                        self.width,
                        self.height,
                        0,
                        &cvTexture)

                    guard textureCreateResult == kCVReturnSuccess,
                        let cvTex = cvTexture,
                        let texture = CVMetalTextureGetTexture(cvTex)
                    else {
                        print(
                            "ExportSession: Failed to create texture. Error: \(textureCreateResult)"
                        )
                        // If we fail to create texture, we probably can't recover easily for this frame.
                        // Fail the export.
                        let completion = self.completion
                        let onFinish = self.onFinish
                        DispatchQueue.main.async {
                            completion(
                                NSError(
                                    domain: "VideoExporter", code: 5,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to create texture"
                                    ]))
                            onFinish?()
                        }
                        return
                    }

                    // Render
                    if let commandBuffer = self.renderer.commandQueue.makeCommandBuffer() {
                        let audioLevel = self.audioProvider?(Double(time)) ?? 0.0

                        self.renderer.encode(
                            commandBuffer: commandBuffer,
                            texture: texture,
                            time: time,
                            audioLevel: audioLevel,
                            resolution: CGSize(width: self.width, height: self.height))
                        commandBuffer.commit()
                        commandBuffer.waitUntilCompleted()
                    } else {
                        print("ExportSession: Failed to create command buffer")
                    }

                    if !self.adaptor.append(pb, withPresentationTime: presentationTime) {
                        print(
                            "ExportSession: Failed to append buffer. Error: \(self.assetWriter.error?.localizedDescription ?? "unknown")"
                        )
                        self.writerInput.markAsFinished()
                        let completion = self.completion
                        let error = self.assetWriter.error
                        let onFinish = self.onFinish
                        DispatchQueue.main.async {
                            completion(error)
                            onFinish?()
                        }
                        return
                    }

                    self.frameCount += 1
                    if self.frameCount % 60 == 0 {
                        print("ExportSession: Encoded frame \(self.frameCount)/\(self.totalFrames)")
                        CVMetalTextureCacheFlush(self.cache, 0)
                    }

                    let p = Double(self.frameCount) / Double(self.totalFrames)
                    let progress = self.progress
                    DispatchQueue.main.async {
                        progress(p)
                    }
                }
                print(
                    "ExportSession: Exited while loop. isReady: \(self.writerInput.isReadyForMoreMediaData)"
                )
            }
        }
    }
}
