import Foundation

/// How well the camera is following the person's movement.
/// The app translates ARKit's tracking state into this.
public enum TrackingCondition: Equatable {
    case good
    case starting
    case unavailable
    case recognizing
    case movingTooFast
    case notEnoughDetail
}

/// How complete ARKit's saved map of the current area is.
/// The app translates ARKit's world mapping status into this.
public enum MappingCondition: Equatable {
    case none
    case limited
    case growing
    case mapped
}

/// Everything the coach needs to know about one moment of scanning.
public struct ScanSnapshot: Equatable {
    public var tracking: TrackingCondition
    public var mapping: MappingCondition
    /// ARKit's light estimate in lumens. Around 1000 is a normally lit room. `nil` if unknown.
    public var ambientLight: Float?

    public init(tracking: TrackingCondition, mapping: MappingCondition, ambientLight: Float?) {
        self.tracking = tracking
        self.mapping = mapping
        self.ambientLight = ambientLight
    }
}

/// A spoken tip during scanning.
public struct ScanTip: Equatable {
    public enum Kind: String {
        case starting, dark, slowDown, notEnoughDetail, lost, keepGoing, areaMapped
    }
    public var kind: Kind
    public var message: String
    /// Problems the person needs to fix right away. Good news isn't urgent.
    public var isProblem: Bool
}

/// Turns what ARKit reports into plain spoken advice, like
/// "It's dark here, turn on a light if you can."
public enum ScanCoach {
    /// Below this light estimate (lumens) the room counts as dark.
    public static let darkThreshold: Float = 250

    public static func tip(for snapshot: ScanSnapshot) -> ScanTip {
        switch snapshot.tracking {
        case .starting:
            return ScanTip(kind: .starting,
                           message: "Getting started. Hold the phone up at chest height with the back camera facing forward, then slowly turn.",
                           isProblem: false)
        case .unavailable, .recognizing:
            return ScanTip(kind: .lost,
                           message: "I lost track of where you are. Stand still and slowly look around the room.",
                           isProblem: true)
        case .movingTooFast:
            return ScanTip(kind: .slowDown,
                           message: "Slow down. Move the phone more slowly and walk at a gentle pace.",
                           isProblem: true)
        case .notEnoughDetail:
            if isDark(snapshot) {
                return darkTip
            }
            return ScanTip(kind: .notEnoughDetail,
                           message: "I can't see enough detail. Point the camera at the room and furniture, not at a blank wall or the floor.",
                           isProblem: true)
        case .good:
            break
        }

        if isDark(snapshot) {
            return darkTip
        }
        switch snapshot.mapping {
        case .mapped:
            return ScanTip(kind: .areaMapped,
                           message: "This area is mapped well.",
                           isProblem: false)
        case .none, .limited, .growing:
            return ScanTip(kind: .keepGoing,
                           message: "Scanning. Keep walking slowly and turn to look around.",
                           isProblem: false)
        }
    }

    static func isDark(_ snapshot: ScanSnapshot) -> Bool {
        guard let light = snapshot.ambientLight else { return false }
        return light < darkThreshold
    }

    static let darkTip = ScanTip(
        kind: .dark,
        message: "It looks dark here. Turn on a light if you can, or ask someone to help.",
        isProblem: true)

    /// Whether there is enough of a map to save.
    public static func canSave(_ mapping: MappingCondition) -> Bool {
        mapping == .growing || mapping == .mapped
    }
}
