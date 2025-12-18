import AVFoundation
import Combine

@MainActor
class AudioController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer?

    @Published var isPlaying = false
    @Published var currentLevel: Float = 0.0
    @Published var currentURL: URL?
    @Published var duration: TimeInterval = 0

    private var timer: Timer?

    // Random access storage
    private var audioSamples: [Float] = []
    private var sampleRate: Double = 44100

    // Analysis results
    var averagePower: Float = 0.0
    var peakPower: Float = 0.0
    var isEnergetic: Bool = false

    override init() {
        super.init()
    }

    func load(url: URL) {
        do {
            self.stop()
            self.currentURL = url
            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.isMeteringEnabled = true
            self.duration = self.audioPlayer?.duration ?? 0

            self.analyze(url: url)

            print("Audio loaded: \(url.lastPathComponent)")
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func play() {
        guard let player = audioPlayer, !player.isPlaying else { return }
        player.play()
        isPlaying = true
        startMetering()
    }

    func pause() {
        guard let player = audioPlayer, player.isPlaying else { return }
        player.pause()
        isPlaying = false
        stopMetering()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        stopMetering()
        currentLevel = 0.0
    }

    private func startMetering() {
        stopMetering()  // Ensure no duplicate timers
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard let player = self.audioPlayer else { return }
                player.updateMeters()

                // Get average power for the first channel (normalized 0..1 roughly)
                // Power is in decibels, usually -160 to 0.
                let power = player.averagePower(forChannel: 0)

                // Convert dB to a normalized linear scale (0..1)
                // Assuming noise floor of -60dB for visual purposes
                let minDb: Float = -60.0
                let clampedPower = max(minDb, power)
                let normalized = (clampedPower - minDb) / abs(minDb)  // 0..1

                self.currentLevel = normalized
            }
        }
    }

    private func stopMetering() {
        timer?.invalidate()
        timer = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            stopMetering()
            currentLevel = 0.0
        }
    }

    func getSamples() -> [Float] {
        return audioSamples
    }

    func getSampleRate() -> Double {
        return sampleRate
    }

    func level(at time: TimeInterval) -> Float {
        guard !audioSamples.isEmpty else { return 0.0 }

        // Calculate index
        let index = Int(time * sampleRate)
        guard index >= 0 && index < audioSamples.count else { return 0.0 }

        // Return instantaneous value or windowed RMS?
        // Instantaneous is too noisy. Let's do a small window RMS (e.g., 50ms)
        let windowSize = Int(0.05 * sampleRate)
        let start = max(0, index - windowSize / 2)
        let end = min(audioSamples.count, index + windowSize / 2)

        var sumSquares: Float = 0
        var count = 0

        // Simple loop ok for short window
        for i in start..<end {
            let s = audioSamples[i]
            sumSquares += s * s
            count += 1
        }

        if count == 0 { return 0.0 }

        let rms = sqrt(sumSquares / Float(count))

        // Normalize (same logic as metering)
        let minDb: Float = -60.0
        // Convert RMS to dB: 20 * log10(rms)
        // Avoid log(0)
        let db = rms > 0 ? 20 * log10(rms) : -160.0

        let clampedDb = max(minDb, db)
        let normalized = (clampedDb - minDb) / abs(minDb)

        return normalized
    }

    // Simple analysis to determine "Mood"
    private func analyze(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            guard
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
            else { return }
            try file.read(into: buffer)

            self.sampleRate = file.processingFormat.sampleRate

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            // Store samples for random access
            // This copies the data.
            self.audioSamples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

            var sumSquares: Float = 0
            var peak: Float = 0

            // Basic RMS calculation using stored samples
            // Stride to save time?
            let step = 100
            var count = 0
            var i = 0
            while i < frameLength {
                let sample = channelData[i]
                let absSample = abs(sample)
                sumSquares += sample * sample
                if absSample > peak {
                    peak = absSample
                }
                count += 1
                i += step
            }

            let rms = sqrt(sumSquares / Float(count))
            self.averagePower = rms
            self.peakPower = peak

            // Threshold for "Energetic" vs "Ambient"
            self.isEnergetic = rms > 0.15 || peak > 0.8

            print("Audio Analysis - RMS: \(rms), Peak: \(peak), Energetic: \(isEnergetic)")

        } catch {
            print("Error analyzing audio file: \(error)")
        }
    }
}
