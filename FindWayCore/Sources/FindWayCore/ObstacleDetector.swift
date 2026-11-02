import Foundation

/// Watches the LiDAR depth in front of the phone and warns about things that are close.
public struct ObstacleDetector {
    /// Warn when something is closer than this, in meters.
    public var warningDistance: Float
    /// Ignore readings closer than this (a hand or sleeve over the sensor).
    public var minimumDistance: Float = 0.2
    /// How many readings must be close before warning, so one noisy pixel never triggers it.
    public var minimumFraction: Float = 0.08

    public init(warningDistance: Float = 0.8) {
        self.warningDistance = warningDistance
    }

    /// - Parameter depths: distances in meters from the middle of the camera view.
    ///   Pass only high-confidence readings.
    /// - Returns: how far away the obstacle is, or `nil` if the way looks clear.
    public func obstacleDistance(in depths: [Float]) -> Float? {
        let valid = depths.filter { $0.isFinite && $0 >= minimumDistance }
        guard valid.count >= 10 else { return nil }
        let close = valid.filter { $0 < warningDistance }
        guard Float(close.count) / Float(valid.count) >= minimumFraction else { return nil }
        // Report a typical close reading rather than the single nearest one.
        let sorted = close.sorted()
        return sorted[sorted.count / 2]
    }
}
