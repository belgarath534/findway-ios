import SwiftUI
import FindWayCore

/// Pick where to go.
struct PlacePickerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let places = model.home?.sortedPlaces ?? []
        List {
            if places.isEmpty {
                Text("No places yet. Go back and scan your home, then mark some spots.")
            } else {
                ForEach(places) { place in
                    NavigationLink {
                        NavigateView(model: model, place: place)
                    } label: {
                        Text(place.name)
                            .font(.title3)
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint("Starts guiding you to \(place.name).")
                }
            }
        }
        .navigationTitle("Where to?")
    }
}
