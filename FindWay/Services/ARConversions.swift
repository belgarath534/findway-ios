import ARKit
import FindWayCore

extension simd_float4x4 {
    /// Where the phone is, in world coordinates (meters).
    var position: Point3 {
        Point3(columns.3.x, columns.3.y, columns.3.z)
    }

    /// The direction the back camera is pointing. ARKit cameras look down their -Z axis.
    var cameraForward: Point3 {
        Point3(-columns.2.x, -columns.2.y, -columns.2.z)
    }
}

extension ARCamera.TrackingState {
    var condition: TrackingCondition {
        switch self {
        case .normal:
            return .good
        case .notAvailable:
            return .unavailable
        case .limited(let reason):
            switch reason {
            case .initializing: return .starting
            case .relocalizing: return .recognizing
            case .excessiveMotion: return .movingTooFast
            case .insufficientFeatures: return .notEnoughDetail
            @unknown default: return .unavailable
            }
        }
    }
}

extension ARFrame.WorldMappingStatus {
    var condition: MappingCondition {
        switch self {
        case .notAvailable: return .none
        case .limited: return .limited
        case .extending: return .growing
        case .mapped: return .mapped
        @unknown default: return .none
        }
    }
}

enum DepthSampler {
    /// High-confidence LiDAR distances from the middle of the camera view, in meters.
    static func centerDepths(from depth: ARDepthData) -> [Float] {
        let map = depth.depthMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }

        let confidence = depth.confidenceMap
        if let confidence {
            CVPixelBufferLockBaseAddress(confidence, .readOnly)
        }
        defer {
            if let confidence { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        }

        guard let base = CVPixelBufferGetBaseAddress(map) else { return [] }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let rowBytes = CVPixelBufferGetBytesPerRow(map)

        let confidenceBase = confidence.flatMap { CVPixelBufferGetBaseAddress($0) }
        let confidenceRowBytes = confidence.map { CVPixelBufferGetBytesPerRow($0) } ?? 0
        let high = UInt8(ARConfidenceLevel.high.rawValue)

        var depths: [Float] = []
        depths.reserveCapacity(200)
        for y in stride(from: height * 35 / 100, to: height * 65 / 100, by: 3) {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
            let confidenceRow = confidenceBase?.advanced(by: y * confidenceRowBytes).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: width * 35 / 100, to: width * 65 / 100, by: 3) {
                if let confidenceRow, confidenceRow[x] < high { continue }
                depths.append(row[x])
            }
        }
        return depths
    }
}
