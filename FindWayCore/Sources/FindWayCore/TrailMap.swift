import Foundation

/// The paths the person actually walked while scanning, stored as breadcrumbs.
///
/// FindWay only ever guides along breadcrumbs someone has walked. It never draws
/// a straight line between two rooms, because that line could go through a wall,
/// a table or down the stairs.
public struct TrailMap: Codable, Equatable {
    /// How far apart breadcrumbs are dropped while walking, in meters.
    public static let breadcrumbSpacing: Float = 0.5

    /// Two breadcrumbs this close together count as the same spot, so walking
    /// back over an old path joins the two paths. It is kept small on purpose:
    /// people walking on both sides of a wall are usually more than this far apart.
    public static let joinRadius: Float = 0.45

    /// Breadcrumbs more than this far apart in height are treated as different
    /// floors and never joined.
    public static let floorHeightTolerance: Float = 0.6

    public private(set) var points: [Point3] = []
    /// `links[i]` lists the breadcrumbs you can walk to directly from breadcrumb `i`.
    public private(set) var links: [[Int]] = []
    /// The breadcrumb dropped most recently, or `nil` right after the trail was broken.
    public private(set) var lastIndex: Int?

    public init() {}

    public var isEmpty: Bool { points.isEmpty }
    public var count: Int { points.count }

    /// Total length of every walked path, in meters (each link counted once).
    public var totalLength: Float {
        var sum: Float = 0
        for (i, neighbors) in links.enumerated() {
            for j in neighbors where j > i {
                sum += Geometry.distance(points[i], points[j])
            }
        }
        return sum
    }

    /// Call this on every camera update while scanning. A breadcrumb is only
    /// dropped once the person has moved far enough from the last one.
    /// - Returns: `true` if a new breadcrumb was dropped.
    @discardableResult
    public mutating func walk(to position: Point3) -> Bool {
        if let last = lastIndex,
           Geometry.distance(points[last], position) < Self.breadcrumbSpacing {
            return false
        }
        addPoint(position)
        return true
    }

    /// Drops a breadcrumb right here even if the last one is close.
    /// Used when the person marks a place, so the place sits exactly on the trail.
    /// - Returns: the index of the breadcrumb at this spot.
    @discardableResult
    public mutating func pin(at position: Point3) -> Int {
        if let last = lastIndex,
           Geometry.distance(points[last], position) < 0.05 {
            return last
        }
        return addPoint(position)
    }

    /// Stop connecting new breadcrumbs to the previous one. Call this when the
    /// camera loses track, so a jump in position never becomes a fake path.
    public mutating func breakTrail() {
        lastIndex = nil
    }

    @discardableResult
    private mutating func addPoint(_ position: Point3) -> Int {
        let index = points.count
        points.append(position)
        links.append([])
        if let last = lastIndex {
            connect(last, index)
        }
        // Join with old breadcrumbs at the same spot (walking back over a path).
        for i in 0..<index where i != lastIndex {
            if isSameSpot(points[i], position) {
                connect(i, index)
            }
        }
        lastIndex = index
        return index
    }

    private func isSameSpot(_ a: Point3, _ b: Point3) -> Bool {
        abs(a.y - b.y) <= Self.floorHeightTolerance
            && Geometry.floorDistance(a, b) <= Self.joinRadius
    }

    private mutating func connect(_ a: Int, _ b: Int) {
        guard a != b else { return }
        if !links[a].contains(b) { links[a].append(b) }
        if !links[b].contains(a) { links[b].append(a) }
    }

    /// The breadcrumb closest to `position` on the same floor, if one is within `maxDistance`.
    public func nearestPoint(to position: Point3, within maxDistance: Float = .greatestFiniteMagnitude) -> Int? {
        var best: Int?
        var bestDistance = maxDistance
        for (i, p) in points.enumerated() where abs(p.y - position.y) <= Self.floorHeightTolerance * 2 {
            let d = Geometry.floorDistance(p, position)
            if d <= bestDistance {
                bestDistance = d
                best = i
            }
        }
        return best
    }

    /// The shortest walked route between two breadcrumbs (A* search).
    /// - Returns: the breadcrumb indexes from `start` to `goal`, or `nil` if they
    ///   are not connected by any walked path.
    public func route(from start: Int, to goal: Int) -> [Int]? {
        guard points.indices.contains(start), points.indices.contains(goal) else { return nil }
        if start == goal { return [start] }

        var cost = [Float](repeating: .infinity, count: points.count)
        var cameFrom = [Int](repeating: -1, count: points.count)
        var done = [Bool](repeating: false, count: points.count)
        var open: Set<Int> = [start]
        cost[start] = 0

        func guess(_ i: Int) -> Float { cost[i] + Geometry.distance(points[i], points[goal]) }

        while let current = open.min(by: { guess($0) < guess($1) }) {
            if current == goal { break }
            open.remove(current)
            done[current] = true
            for next in links[current] where !done[next] {
                let newCost = cost[current] + Geometry.distance(points[current], points[next])
                if newCost < cost[next] {
                    cost[next] = newCost
                    cameFrom[next] = current
                    open.insert(next)
                }
            }
        }

        guard cost[goal].isFinite else { return nil }
        var path = [goal]
        var step = goal
        while step != start {
            step = cameFrom[step]
            path.append(step)
        }
        return path.reversed()
    }
}
