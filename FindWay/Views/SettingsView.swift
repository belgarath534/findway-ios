import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.clockDirections) private var clockDirections = false
    @AppStorage(SettingsKey.obstacleWarnings) private var obstacleWarnings = true
    @AppStorage(SettingsKey.beacon) private var beacon = true

    var body: some View {
        Form {
            Section {
                Toggle("Clock directions", isOn: $clockDirections)
            } footer: {
                Text("Say directions like \"3 o'clock\" instead of \"Turn right\".")
            }
            Section {
                Toggle("Guiding ping sound", isOn: $beacon)
            } footer: {
                Text("A ping that sounds like it comes from where you're heading. Works best with headphones.")
            }
            Section {
                Toggle("Warn about things in front of me", isOn: $obstacleWarnings)
            } footer: {
                Text("Uses the LiDAR sensor to warn you when something is close ahead while you're being guided.")
            }
        }
        .navigationTitle("Settings")
    }
}
