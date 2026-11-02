import Foundation

/// Why a route could not be planned, with a message that can be spoken as-is.
public enum RouteProblem: Error, Equatable {
    case noTrail
    case tooFarFromTrail(meters: Float)
    case notConnected

    public var spokenMessage: String {
        switch self {
        case .noTrail:
            return "There are no scanned paths yet. Scan your home first."
        case .tooFarFromTrail:
            return "You're not near a path you scanned. Walk to a part of the home you scanned and try again."
        case .notConnected:
            return "I don't have a walked path from here to there. Scan the way between these two spots, walking from one to the other."
        }
    }
}

public enum RoutePlanner {
    /// How far from the nearest breadcrumb the person may stand when asking for a route.
    public static let maxStartDistance: Float = 2.5

    /// Plans a route along walked paths from `position` to `destination`.
    /// - Returns: waypoints to walk through, in order. The last one is the destination itself.
    public static func plan(on trail: TrailMap, from position: Point3, to destination: Point3) -> Result<[Point3], RouteProblem> {
        guard !trail.isEmpty else { return .failure(.noTrail) }
        guard let start = trail.nearestPoint(to: position, within: maxStartDistance) else {
            let closest = trail.nearestPoint(to: position).map { Geometry.floorDistance(trail.points[$0], position) } ?? .infinity
            return .failure(.tooFarFromTrail(meters: closest))
        }
        guard let goal = trail.nearestPoint(to: destination, within: 1.5),
              let indexes = trail.route(from: start, to: goal) else {
            return .failure(.notConnected)
        }
        var points = indexes.map { trail.points[$0] }
        points.append(destination)
        return .success(simplify(points))
    }

    /// Removes breadcrumbs that sit on a straight stretch, keeping only the turns.
    /// Fewer waypoints means fewer, clearer directions.
    /// - Parameters:
    ///   - minTurn: smaller changes of direction than this (degrees) are ignored.
    ///   - maxLeg: never skip so many breadcrumbs that a leg gets longer than this,
    ///     so the route can't drift far from where the person actually walked.
    public static func simplify(_ points: [Point3], minTurn: Float = 25, maxLeg: Float = 4) -> [Point3] {
        guard points.count > 2 else { return points }
        var kept: [Point3] = [points[0]]
        for i in 1..<(points.count - 1) {
            let anchor = kept[kept.count - 1]
            let here = points[i]
            let next = points[i + 1]
            let legSoFar = Geometry.floorDistance(anchor, next)
            let headingIn = heading(from: anchor, to: here)
            let headingOut = heading(from: here, to: next)
            var turn: Float = 0
            if let a = headingIn, let b = headingOut {
                turn = abs(Geometry.normalizeDegrees(b - a))
            }
            if turn >= minTurn || legSoFar > maxLeg {
                kept.append(here)
            }
        }
        kept.append(points[points.count - 1])
        return kept
    }

    /// Compass-style heading across the floor, in degrees, or `nil` for a zero-length step.
    static func heading(from a: Point3, to b: Point3) -> Float? {
        let dx = b.x - a.x, dz = b.z - a.z
        guard dx * dx + dz * dz > 0.000001 else { return nil }
        return atan2(dx, -dz) * 180 / .pi
    }
}
