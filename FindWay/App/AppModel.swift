import ARKit
import FindWayCore

/// Keeps track of the saved home and builds scanning and navigation sessions.
final class AppModel: ObservableObject {
    @Published private(set) var home: HomeData?

    let store = HomeStore()

    init() {
        home = store.loadHome()
    }

    var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    func reload() {
        home = store.loadHome()
    }

    /// - Parameter continuing: add to the saved home instead of starting a new one.
    func makeScanSession(continuing: Bool) -> ScanSession {
        if continuing, let home, let map = try? store.loadWorldMap() {
            return ScanSession(store: store, existing: home, worldMap: map)
        }
        return ScanSession(store: store, existing: nil, worldMap: nil)
    }

    func makeNavigationSession(to place: Place, options: NavigationSession.Options) -> NavigationSession {
        NavigationSession(store: store, home: home ?? HomeData(), destination: place, options: options)
    }

    /// - Returns: a spoken-style error message, or `nil` if it worked.
    func rename(_ place: Place, to rawName: String) -> String? {
        guard var home else { return "There's no saved home." }
        guard let name = HomeData.cleanName(rawName) else { return "The name was empty." }
        if name.caseInsensitiveCompare(place.name) != .orderedSame, home.hasPlace(named: name) {
            return "You already have a place called \(name)."
        }
        guard let index = home.places.firstIndex(where: { $0.id == place.id }) else { return "That place is gone." }
        home.places[index].name = name
        return persist(home)
    }

    func delete(_ place: Place) {
        guard var home else { return }
        home.places.removeAll { $0.id == place.id }
        _ = persist(home)
    }

    func eraseEverything() {
        store.eraseEverything()
        home = nil
    }

    private func persist(_ updated: HomeData) -> String? {
        do {
            try store.saveHomeOnly(updated)
            home = updated
            return nil
        } catch {
            return "Saving didn't work: \(error.localizedDescription)"
        }
    }
}

/// Settings, saved between launches.
enum SettingsKey {
    static let clockDirections = "clockDirections"
    static let obstacleWarnings = "obstacleWarnings"
    static let beacon = "beacon"
}
