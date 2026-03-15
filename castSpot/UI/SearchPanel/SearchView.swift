import SwiftUI

struct SearchView: View {
    @StateObject private var search = SpotifySearch()
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if !search.results.isEmpty {
                Divider()
                resultsList
            }
        }
        .onChange(of: query) { _, newValue in
            selectedIndex = 0
            search.search(query: newValue)
        }
        .onChange(of: search.results) { _, results in
            NotificationCenter.default.post(name: .resultsCountChanged, object: results.count)
        }
        .onAppear { focused = true }
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, search.results.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.escape) { dismiss(); return .handled }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            TextField("Search for music…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($focused)
                .onSubmit { playSelected() }

            if search.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 22)
            } else if !query.isEmpty {
                Button { query = ""; search.clear(); focused = true } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 22)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(search.results.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track, isSelected: index == selectedIndex)
                    .contentShape(Rectangle())
                    .onTapGesture { play(track) }
                    .onHover { hovering in if hovering { selectedIndex = index } }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func playSelected() {
        guard !search.results.isEmpty else { return }
        play(search.results[selectedIndex])
    }

    private func play(_ track: Track) {
        SpotifyPlayer.play(track: track)
        dismiss()
    }

    private func dismiss() {
        query = ""
        search.clear()
        NotificationCenter.default.post(name: .closeSearchPanel, object: nil)
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let track: Track
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15))
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("\(track.artist) · \(track.album)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let resultsCountChanged = Notification.Name("castSpot.resultsCountChanged")
    static let closeSearchPanel = Notification.Name("castSpot.closeSearchPanel")
}
