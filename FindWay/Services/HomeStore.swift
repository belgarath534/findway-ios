import ARKit
import FindWayCore

/// Saves the home on the phone: the list of places and paths (home.json) and
/// ARKit's camera map (home.worldmap). Nothing leaves the phone.
final class HomeStore {
    enum StoreError: LocalizedError {
        case mapUnreadable

        var errorDescription: String? {
            switch self {
            case .mapUnreadable: return "The saved scan of your home couldn't be opened."
            }
        }
    }

    private let folder: URL
    private var homeURL: URL { folder.appendingPathComponent("home.json") }
    private var mapURL: URL { folder.appendingPathComponent("home.worldmap") }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = support.appendingPathComponent("FindWay", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func loadHome() -> HomeData? {
        guard let data = try? Data(contentsOf: homeURL) else { return nil }
        return try? HomeData.decode(data)
    }

    func loadWorldMap() throws -> ARWorldMap {
        let data = try Data(contentsOf: mapURL)
        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw StoreError.mapUnreadable
        }
        return map
    }

    /// Saves both files. The map is written first, so a home.json never points at a missing map.
    func save(home: HomeData, worldMap: ARWorldMap) throws {
        let mapData = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try mapData.write(to: mapURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try saveHomeOnly(home)
    }

    /// For renaming or deleting places, which doesn't change the camera map.
    func saveHomeOnly(_ home: HomeData) throws {
        var updated = home
        updated.updatedAt = Date()
        try updated.encoded().write(to: homeURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func eraseEverything() {
        try? FileManager.default.removeItem(at: homeURL)
        try? FileManager.default.removeItem(at: mapURL)
    }
}
