import Foundation

enum SpotifyPlayer {
    /// Plays a track via the Spotify Web API (requires Premium).
    static func play(track: Track) {
        Task {
            guard let token = try? await SpotifyAuth.shared.validAccessToken() else { return }

            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/play")!)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["uris": [track.uri]])

            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
