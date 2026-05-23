import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Quick Capture") {
                LabeledContent("Global Shortcut", value: "Option-N")
                Text("Shortcut remapping can be added after the first version.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
