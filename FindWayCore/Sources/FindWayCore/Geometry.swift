import Foundation

/// A point in the home, in meters, using ARKit's world coordinates:
/// x points right, y points up, z points back toward where the scan started.
public typealias Point3 = SIMD3<Float>

public enum Geometry {
    /// Straight-line distance between two points.
    public static func distance(_ a: Point3, _ b: Point3) -> Float {
        let d = a - b
        return (d * d).sum().squareRoot()
    }

    /// Distance across the floor, ignoring height. Holding the phone higher or
    /// lower should not change how far away a place feels.
    public static func floorDistance(_ a: Point3, _ b: Point3) -> Float {
        let dx = a.x - b.x
        let dz = a.z - b.z
        return (dx * dx + dz * dz).squareRoot()
    }

    /// The signed angle, in degrees, the person has to turn to face `target`.
    /// Positive means turn right, negative means turn left, 0 means straight ahead.
    ///
    /// - Parameters:
    ///   - position: where the person is standing.
    ///   - forward: the direction the phone's camera is pointing.
    ///   - target: the point to face.
    /// - Returns: `nil` when the angle can't be worked out, for example when the
    ///   phone points straight at the floor or the target is right underfoot.
    public static func turnAngle(from position: Point3, forward: Point3, to target: Point3) -> Float? {
        let fx = forward.x, fz = forward.z
        let flen = (fx * fx + fz * fz).squareRoot()
        guard flen > 0.0001 else { return nil }
        let tx = target.x - position.x, tz = target.z - position.z
        guard (tx * tx + tz * tz) > 0.000001 else { return nil }
        let nfx = fx / flen, nfz = fz / flen
        // The right-hand side of "forward" on the floor, with y pointing up.
        let ahead = nfx * tx + nfz * tz
        let right = -nfz * tx + nfx * tz
        return atan2(right, ahead) * 180 / .pi
    }

    /// Keeps an angle between -180 and 180 degrees.
    public static func normalizeDegrees(_ angle: Float) -> Float {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a > 180 { a -= 360 }
        if a <= -180 { a += 360 }
        return a
    }
}
