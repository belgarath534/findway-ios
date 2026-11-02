import SwiftUI
import FindWayCore

/// Guiding screen. Most of it is spoken; the buttons are for repeating and stopping.
struct NavigateView: View {
    @StateObject private var session: NavigationSession
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, place: Place) {
        let defaults = UserDefaults.standard
        let options = NavigationSession.Options(
            clockDirections: defaults.bool(forKey: SettingsKey.clockDirections),
            obstacleWarnings: defaults.object(forKey: SettingsKey.obstacleWarnings) as? Bool ?? true,
            beacon: defaults.object(forKey: SettingsKey.beacon) as? Bool ?? true)
        _session = StateObject(wrappedValue: model.makeNavigationSession(to: place, options: options))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(session.statusText)
                    .font(.largeTitle.bold())
                    .accessibilityLabel(session.statusText)

                if !session.detailText.isEmpty {
                    Text(session.detailText)
                        .font(.title3)
                }

                if session.phase == .arrived || session.phase == .failed {
                    Button {
                        dismiss()
                    } label: {
                        BigButtonLabel(title: "Done", systemImage: "checkmark")
                    }
                } else {
                    Button {
                        session.repeatDirections()
                    } label: {
                        BigButtonLabel(title: "Repeat direction", systemImage: "speaker.wave.2")
                    }

                    Button {
                        dismiss()
                    } label: {
                        BigButtonLabel(title: "Stop", systemImage: "stop.circle")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("To \(session.destination.name)")
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            session.start()
        }
        .onDisappear {
            session.stop()
            Speaker.shared.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
