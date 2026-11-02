import SwiftUI
import FindWayCore

/// Scanning screen: walk around, mark spots, save.
struct ScanView: View {
    @StateObject private var session: ScanSession
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var isNaming = false
    @State private var newName = ""
    @State private var confirmLeave = false

    init(model: AppModel, continuing: Bool) {
        _session = StateObject(wrappedValue: model.makeScanSession(continuing: continuing))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(session.statusText)
                    .font(.title2)
                    .accessibilityLabel("Tip: \(session.statusText)")

                Text("Places marked: \(session.placeCount). Paths walked: about \(session.metersWalked) meters.")
                    .font(.body)

                Button {
                    newName = ""
                    isNaming = true
                } label: {
                    BigButtonLabel(title: "Mark this spot", systemImage: "mappin.and.ellipse")
                }
                .accessibilityHint("Names the spot where you're standing, like Kitchen.")

                Button {
                    session.repeatStatus()
                } label: {
                    BigButtonLabel(title: "Repeat tip", systemImage: "speaker.wave.2")
                }

                Button {
                    session.save { saved in
                        if saved {
                            model.reload()
                            dismiss()
                        }
                    }
                } label: {
                    BigButtonLabel(title: session.isSaving ? "Saving" : "Finish and save", systemImage: "checkmark.circle")
                }
                .disabled(session.isSaving)

                Button("Leave without saving", role: .destructive) {
                    confirmLeave = true
                }
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .padding()
        }
        .navigationTitle(session.isContinuing ? "Scan more" : "Scan my home")
        .navigationBarBackButtonHidden(true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            session.start()
        }
        .onDisappear {
            session.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .alert("Name this spot", isPresented: $isNaming) {
            TextField("For example, Kitchen", text: $newName)
            Button("Save") { _ = session.markPlace(named: newName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Type a name or use dictation on the keyboard.")
        }
        .confirmationDialog("Leave without saving?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave without saving", role: .destructive) { dismiss() }
            Button("Keep scanning", role: .cancel) {}
        } message: {
            Text("Everything you scanned since you opened this screen will be lost.")
        }
    }
}
