import SwiftUI
import FindWayCore

/// Rename or delete places, or erase the whole home.
struct ManagePlacesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var renaming: Place?
    @State private var newName = ""
    @State private var deleting: Place?
    @State private var confirmErase = false
    @State private var errorMessage: String?

    var body: some View {
        let places = model.home?.sortedPlaces ?? []
        List {
            Section("Places") {
                if places.isEmpty {
                    Text("No places yet.")
                }
                ForEach(places) { place in
                    Text(place.name)
                        .font(.title3)
                        .frame(minHeight: 44)
                        .accessibilityHint("Swipe up or down for rename and delete.")
                        .accessibilityAction(named: "Rename") { startRename(place) }
                        .accessibilityAction(named: "Delete") { deleting = place }
                        .swipeActions {
                            Button("Delete", role: .destructive) { deleting = place }
                            Button("Rename") { startRename(place) }
                        }
                }
            }
            Section {
                Button("Erase my home and start over", role: .destructive) {
                    confirmErase = true
                }
            } footer: {
                Text("Deleting a place keeps the paths you walked. Erasing removes everything.")
            }
        }
        .navigationTitle("My places")
        .alert("Rename place", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("New name", text: $newName)
            Button("Save") {
                if let place = renaming {
                    errorMessage = model.rename(place, to: newName)
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("Delete \(deleting?.name ?? "this place")?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let place = deleting { model.delete(place) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        }
        .confirmationDialog("Erase your whole home?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) {
                model.eraseEverything()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All places and scans will be deleted. This can't be undone.")
        }
        .alert("Couldn't rename", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startRename(_ place: Place) {
        newName = place.name
        renaming = place
    }
}
