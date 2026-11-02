import Foundation

/// A named spot in the home, like "Kitchen" or "Bathroom door".
public struct Place: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var position: Point3
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, position: Point3, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.position = position
        self.createdAt = createdAt
    }
}

/// Everything FindWay remembers about a home, apart from ARKit's own camera map
/// (that one is saved next to this file by the app).
public struct HomeData: Codable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var places: [Place]
    public var trail: TrailMap
    public var updatedAt: Date

    public init(places: [Place] = [], trail: TrailMap = TrailMap(), updatedAt: Date = Date()) {
        self.version = Self.currentVersion
        self.places = places
        self.trail = trail
        self.updatedAt = updatedAt
    }

    /// Cleans up a spoken or typed place name.
    /// - Returns: `nil` when nothing usable is left.
    public static func cleanName(_ raw: String) -> String? {
        let trimmed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(60))
    }

    /// True if a place already uses this name (ignoring capital letters).
    public func hasPlace(named name: String) -> Bool {
        places.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Places sorted by name, the order they are listed in the app.
    public var sortedPlaces: [Place] {
        places.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> HomeData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HomeData.self, from: data)
    }
}
