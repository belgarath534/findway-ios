import AVFoundation
import FindWayCore

/// A repeating "ping" that sounds like it comes from the next waypoint.
/// With headphones you can follow it with your ears: turn until it's straight
/// in front of you, then walk toward it.
final class SpatialBeacon {
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffer: AVAudioPCMBuffer?
    private(set) var isRunning = false

    var isMuted = false {
        didSet { player.volume = isMuted ? 0 : 1 }
    }

    init() {
        // 3D sound only works with a mono source.
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(environment)
        engine.attach(player)
        engine.connect(player, to: environment, format: format)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)

        player.renderingAlgorithm = .HRTFHQ
        let distance = environment.distanceAttenuationParameters
        distance.distanceAttenuationModel = .inverse
        distance.referenceDistance = 1
        distance.maximumDistance = 15
        distance.rolloffFactor = 0.5

        buffer = Self.makePing(format: format)
    }

    func start() {
        guard !isRunning, let buffer else { return }
        do {
            try engine.start()
        } catch {
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        player.stop()
        engine.stop()
        isRunning = false
    }

    /// Moves the listener (the person) and the ping (the waypoint).
    func update(listener: Point3, forward: Point3, target: Point3) {
        environment.listenerPosition = AVAudio3DPoint(x: listener.x, y: listener.y, z: listener.z)
        // Only the direction across the floor matters; tilting the phone shouldn't move the sound.
        let length = (forward.x * forward.x + forward.z * forward.z).squareRoot()
        if length > 0.001 {
            environment.listenerVectorOrientation = AVAudio3DVectorOrientation(
                forward: AVAudio3DVector(x: forward.x / length, y: 0, z: forward.z / length),
                up: AVAudio3DVector(x: 0, y: 1, z: 0))
        }
        // Keep the ping at ear height so it never sounds like it's above or below you.
        player.position = AVAudio3DPoint(x: target.x, y: listener.y, z: target.z)
    }

    /// A short bell-like ping followed by silence, about once a second.
    private static func makePing(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let total = AVAudioFrameCount(sampleRate * 0.9)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = total
        let pingLength = Int(sampleRate * 0.15)
        for i in 0..<Int(total) {
            guard i < pingLength else {
                samples[i] = 0
                continue
            }
            let t = Double(i) / sampleRate
            let fadeIn = min(1, t / 0.004)
            let decay = exp(-t * 28)
            let tone = sin(2 * .pi * 880 * t) + 0.4 * sin(2 * .pi * 1760 * t)
            samples[i] = Float(tone * decay * fadeIn * 0.6)
        }
        return buffer
    }
}
