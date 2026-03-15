import Combine
import Foundation

struct Track: Identifiable, Equatable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let uri: String
    let artworkURL: URL?
}

@MainActor
class SpotifySearch: ObservableObject {
    @Published var results: [Track] = []
    @Published var isLoading = false

    private var searchTask: Task<Void, Never>?
    private let cache = NSCache<NSString, NSArray>()

    func search(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }

        searchTask = Task {
            if let cached = cache.object(forKey: trimmed as NSString) as? [Track] {
                results = cached
                return
            }

            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            isLoading = true
            defer { isLoading = false }

            do {
                let token = try await SpotifyAuth.shared.validAccessToken()
                let tracks = try await fetchTracks(query: trimmed, token: token)
                cache.setObject(tracks as NSArray, forKey: trimmed as NSString)
                results = tracks
            } catch {
                // Token expired and refresh failed — results stay empty
            }
        }
    }

    func clear() {
        searchTask?.cancel()
        results = []
        isLoading = false
    }

    // MARK: - Network

    private func fetchTracks(query: String, token: String) async throws -> [Track] {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "type", value: "track"),
            .init(name: "limit", value: "5"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)

        return response.tracks.items.map { item in
            Track(
                id: item.id,
                name: item.name,
                artist: item.artists.first?.name ?? "",
                album: item.album.name,
                uri: item.uri,
                artworkURL: item.album.images.first.flatMap { URL(string: $0.url) }
            )
        }
    }
}

// MARK: - API Response Models

private struct SearchResponse: Decodable {
    let tracks: TracksContainer
    struct TracksContainer: Decodable {
        let items: [TrackItem]
    }
    struct TrackItem: Decodable {
        let id: String
        let name: String
        let uri: String
        let artists: [Artist]
        let album: Album
        struct Artist: Decodable { let name: String }
        struct Album: Decodable {
            let name: String
            let images: [Image]
            struct Image: Decodable { let url: String }
        }
    }
}
