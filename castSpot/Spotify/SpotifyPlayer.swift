import Foundation

enum SpotifyPlayer {
    /// Plays a track in the Spotify macOS app via AppleScript.
    /// Launches Spotify if it isn't already running.
    static func play(track: Track) {
        let uri = track.uri
        // Run on a background thread so AppleScript delay doesn't block UI
        Task.detached(priority: .userInitiated) {
            let script = """
            tell application "Spotify"
                if not running then
                    activate
                    delay 2
                end if
                play track "\(uri)"
            end tell
            """
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }
}
