import SwiftUI

@main
struct castSpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(SpotifyAuth.shared)
        }
    }
}
