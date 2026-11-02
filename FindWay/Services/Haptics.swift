import UIKit

/// Short vibrations so the person can feel what is happening without listening.
final class Haptics {
    private let tap = UIImpactFeedbackGenerator(style: .light)
    private let bump = UIImpactFeedbackGenerator(style: .heavy)
    private let notice = UINotificationFeedbackGenerator()

    /// A light tap: "you're facing the right way."
    func onCourse() {
        tap.impactOccurred()
        tap.prepare()
    }

    /// A strong bump: "careful, something is close in front of you."
    func warning() {
        bump.impactOccurred()
        bump.prepare()
    }

    /// A happy double buzz: arrived, saved, or found where you are.
    func success() {
        notice.notificationOccurred(.success)
    }

    /// Something went wrong.
    func failure() {
        notice.notificationOccurred(.error)
    }
}
