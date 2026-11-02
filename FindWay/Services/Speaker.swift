import AVFoundation
import UIKit

/// Says things out loud. With VoiceOver on it speaks through VoiceOver, so it uses
/// the person's own VoiceOver voice and speed. Without VoiceOver it uses the system voice.
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// - Parameter interrupt: stop whatever is being said first (true for directions,
    ///   which are only useful while they are fresh).
    func speak(_ text: String, interrupt: Bool = true) {
        if UIAccessibility.isVoiceOverRunning {
            let announcement = NSAttributedString(
                string: text,
                attributes: [.accessibilitySpeechQueueAnnouncement: NSNumber(value: !interrupt)])
            // A short pause so VoiceOver finishes reacting to a button press first;
            // otherwise it can cut the announcement off and nothing is heard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
            return
        }
        if interrupt, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Lets speech and the beacon play together, quietly lowering music from other apps.
    static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
    }
}
