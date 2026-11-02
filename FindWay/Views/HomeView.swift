import SwiftUI
import FindWayCore

/// The first screen: scan your home, or pick a place to go.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !model.isSupported {
                    Text("This iPhone can't run FindWay. It needs an iPhone that supports ARKit world tracking.")
                        .font(.title3)
                } else if let home = model.home {
                    savedHome(home)
                } else {
                    firstTime
                }
            }
            .padding()
        }
        .navigationTitle("FindWay")
        .onAppear { model.reload() }
    }

    private var firstTime: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to FindWay")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text("First, scan your home. Hold your phone up at chest height with the back camera facing forward, and walk slowly through each room. At the spots you care about, like the kitchen or the bathroom door, tap Mark this spot and give it a name.")
            Text("Then FindWay can guide you to any spot you named. Headphones help you hear the guiding ping.")
            NavigationLink {
                ScanView(model: model, continuing: false)
            } label: {
                BigButtonLabel(title: "Scan my home", systemImage: "camera.viewfinder")
            }
            .accessibilityHint("Starts the camera and coaches you as you walk.")
            safetyNote
        }
    }

    private func savedHome(_ home: HomeData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            let count = home.places.count
            Text("Your home has \(count) saved \(count == 1 ? "place" : "places").")
                .font(.title3)

            NavigationLink {
                PlacePickerView()
            } label: {
                BigButtonLabel(title: "Take me somewhere", systemImage: "figure.walk")
            }
            .accessibilityHint("Pick a saved place and FindWay guides you there.")

            NavigationLink {
                ScanView(model: model, continuing: true)
            } label: {
                BigButtonLabel(title: "Scan more of my home", systemImage: "plus.viewfinder")
            }
            .accessibilityHint("Adds new rooms, paths and places to your saved home.")

            NavigationLink {
                ManagePlacesView()
            } label: {
                BigButtonLabel(title: "My places", systemImage: "list.bullet")
            }
            .accessibilityHint("Rename or delete places, or erase your home.")

            NavigationLink {
                SettingsView()
            } label: {
                BigButtonLabel(title: "Settings", systemImage: "gearshape")
            }

            safetyNote
        }
    }

    private var safetyNote: some View {
        Text("FindWay is an extra helper, not a replacement for your cane or guide dog. Always stay careful, especially near stairs.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

/// A large, easy-to-hit button look used across the app.
struct BigButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
    }
}
