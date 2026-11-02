import SwiftUI

@main
struct FindWayApp: App {
    @StateObject private var model = AppModel()

    init() {
        Speaker.configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environmentObject(model)
        }
    }
}
