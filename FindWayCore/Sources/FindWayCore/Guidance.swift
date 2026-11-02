import Foundation

/// Which way to go, in words a person can act on.
public enum Direction: Equatable {
    case straight
    case slightLeft, slightRight
    case left, right
    case turnAround

    /// Picks a direction from a turn angle (positive = right).
    public init(turnAngle angle: Float) {
        let a = abs(angle)
        if a < 20 { self = .straight }
        else if a < 50 { self = angle > 0 ? .slightRight : .slightLeft }
        else if a < 135 { self = angle > 0 ? .right : .left }
        else { self = .turnAround }
    }

    public var phrase: String {
        switch self {
        case .straight: return "Straight ahead"
        case .slightLeft: return "Slightly left"
        case .slightRight: return "Slightly right"
        case .left: return "Turn left"
        case .right: return "Turn right"
        case .turnAround: return "Turn around"
        }
    }
}

/// One moment of guidance: what to say and how close the person is.
public struct GuidanceUpdate: Equatable {
    public var direction: Direction
    /// The turn angle to the next waypoint in degrees (positive = right).
    public var turnAngle: Float
    /// Clock-face direction to the next waypoint: 12 is straight ahead, 3 is to the right.
    public var clockHour: Int
    public var metersToWaypoint: Float
    public var metersToDestination: Float
    public var waypointIndex: Int
    public var waypointCount: Int
    /// True on the update where the person reached a waypoint and the next one became active.
    public var reachedWaypoint: Bool
    public var arrived: Bool
}

/// Walks the person through a list of waypoints, one at a time.
public struct GuidanceEngine {
    public static let waypointRadius: Float = 0.6
    public static let destinationRadius: Float = 0.7
    /// Average step length used to turn meters into steps.
    public static let stepLength: Float = 0.7

    public let waypoints: [Point3]
    public private(set) var currentIndex = 0
    public private(set) var hasArrived = false

    public init(waypoints: [Point3]) {
        precondition(!waypoints.isEmpty, "A route needs at least one waypoint")
        self.waypoints = waypoints
    }

    public var destination: Point3 { waypoints[waypoints.count - 1] }

    /// Call this on every camera update.
    /// - Returns: `nil` if the direction can't be worked out right now
    ///   (for example the phone is pointed at the floor).
    public mutating func update(position: Point3, forward: Point3) -> GuidanceUpdate? {
        var reached = false

        if !hasArrived {
            // Move on past every waypoint the person is standing at, or has
            // already walked past along the next leg of the route. Being close
            // to a later waypoint is not enough on its own: it could be on the
            // other side of a wall.
            while currentIndex < waypoints.count - 1 {
                let here = Geometry.floorDistance(position, waypoints[currentIndex])
                if here <= Self.waypointRadius
                    || Self.isAlongLeg(position, from: waypoints[currentIndex], to: waypoints[currentIndex + 1]) {
                    currentIndex += 1
                    reached = true
                } else {
                    break
                }
            }
            if currentIndex == waypoints.count - 1,
               Geometry.floorDistance(position, destination) <= Self.destinationRadius {
                hasArrived = true
            }
        }

        let target = waypoints[currentIndex]
        let toWaypoint = Geometry.floorDistance(position, target)
        let remaining = toWaypoint + legsAfter(currentIndex)

        let angle: Float
        if hasArrived {
            angle = 0
        } else if let a = Geometry.turnAngle(from: position, forward: forward, to: target) {
            angle = a
        } else {
            return nil
        }

        return GuidanceUpdate(
            direction: Direction(turnAngle: angle),
            turnAngle: angle,
            clockHour: Self.clockHour(for: angle),
            metersToWaypoint: toWaypoint,
            metersToDestination: remaining,
            waypointIndex: currentIndex,
            waypointCount: waypoints.count,
            reachedWaypoint: reached && !hasArrived,
            arrived: hasArrived
        )
    }

    /// How far to the side of a leg the person may be and still count as walking along it.
    public static let legCorridor: Float = 0.6

    /// True when the person is partway along the leg from `a` to `b`
    /// (past `a`, not yet at `b`, and within the corridor around the line).
    static func isAlongLeg(_ p: Point3, from a: Point3, to b: Point3) -> Bool {
        let lx = b.x - a.x, lz = b.z - a.z
        let length2 = lx * lx + lz * lz
        guard length2 > 0.0001 else { return false }
        let px = p.x - a.x, pz = p.z - a.z
        let t = (px * lx + pz * lz) / length2
        guard t > 0.15, t < 1 else { return false }
        let side = abs(px * lz - pz * lx) / length2.squareRoot()
        return side <= legCorridor
    }

    private func legsAfter(_ index: Int) -> Float {
        guard index < waypoints.count - 1 else { return 0 }
        var sum: Float = 0
        for i in index..<(waypoints.count - 1) {
            sum += Geometry.floorDistance(waypoints[i], waypoints[i + 1])
        }
        return sum
    }

    /// Converts a turn angle to a clock position (12 = ahead, 3 = right, 9 = left).
    public static func clockHour(for angle: Float) -> Int {
        let normalized = Geometry.normalizeDegrees(angle)
        var hour = Int((normalized / 30).rounded())
        if hour <= 0 { hour += 12 }
        return hour
    }

    /// Meters as a number of walking steps, never less than 1.
    public static func steps(for meters: Float) -> Int {
        max(1, Int((meters / stepLength).rounded()))
    }
}

/// Turns guidance updates into short sentences to speak.
public enum GuidancePhrases {
    public static func instruction(for update: GuidanceUpdate, destinationName: String, useClock: Bool) -> String {
        if update.arrived {
            return "You've arrived at \(destinationName)."
        }
        let steps = GuidanceEngine.steps(for: update.metersToWaypoint)
        let stepWord = steps == 1 ? "step" : "steps"
        if useClock {
            if update.direction == .straight {
                return "Straight ahead, \(steps) \(stepWord)."
            }
            return "\(update.clockHour) o'clock, \(steps) \(stepWord)."
        }
        switch update.direction {
        case .straight:
            return "Straight ahead, \(steps) \(stepWord)."
        case .slightLeft, .slightRight:
            return "\(update.direction.phrase), \(steps) \(stepWord)."
        case .left, .right, .turnAround:
            return "\(update.direction.phrase)."
        }
    }

    public static func summary(for update: GuidanceUpdate, destinationName: String) -> String {
        if update.arrived { return "You've arrived at \(destinationName)." }
        let steps = GuidanceEngine.steps(for: update.metersToDestination)
        return "\(destinationName) is about \(steps) \(steps == 1 ? "step" : "steps") away."
    }
}

/// Decides when to speak, so FindWay talks enough to be useful but never nonstop.
public struct AnnouncementThrottle {
    /// Never speak two messages closer together than this, in seconds.
    public var minimumGap: TimeInterval
    /// Repeat an unchanged message after this many seconds.
    public var repeatAfter: TimeInterval

    private var lastKey: String?
    private var lastTime: TimeInterval = -.greatestFiniteMagnitude

    public init(minimumGap: TimeInterval = 1.5, repeatAfter: TimeInterval = 6) {
        self.minimumGap = minimumGap
        self.repeatAfter = repeatAfter
    }

    /// - Parameters:
    ///   - key: identifies the message; a new key means something changed.
    ///   - urgent: skip the minimum gap (used for arriving and for obstacle warnings).
    ///   - now: the current time in seconds.
    /// - Returns: `true` if this message should be spoken now. Speaking is recorded.
    public mutating func shouldSpeak(key: String, urgent: Bool = false, now: TimeInterval) -> Bool {
        let elapsed = now - lastTime
        let changed = key != lastKey
        let speak: Bool
        if changed {
            speak = urgent || elapsed >= minimumGap
        } else {
            speak = elapsed >= repeatAfter
        }
        if speak {
            lastKey = key
            lastTime = now
        }
        return speak
    }

    public mutating func reset() {
        lastKey = nil
        lastTime = -.greatestFiniteMagnitude
    }
}
