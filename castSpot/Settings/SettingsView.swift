import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: SpotifyAuth

    var body: some View {
        Form {
            Section("Spotify Account") {
                if auth.isAuthenticated {
                    HStack {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect") { auth.signOut() }
                            .foregroundStyle(.red)
                    }
                } else {
                    HStack {
                        Label("Not connected", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Connect Spotify") { auth.startAuthFlow() }
                    }
                }
            }

            Section("Keyboard Shortcut") {
                LabeledContent("Show castSpot") {
                    Text("Control+Space")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
    }
}
