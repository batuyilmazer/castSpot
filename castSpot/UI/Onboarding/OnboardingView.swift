import SwiftUI

extension ShapeStyle where Self == Color {
    static var spotifyGreen: Color { Color(red: 0.118, green: 0.843, blue: 0.376) }
}

struct OnboardingView: View {
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(.spotifyGreen)

            Text("Connect Spotify")
                .font(.system(size: 20, weight: .semibold))

            Text("Sign in with your Spotify account to search and play music instantly from anywhere.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onConnect) {
                Label("Connect with Spotify", systemImage: "arrow.right.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.spotifyGreen)
        }
        .padding(30)
        .frame(width: 620)
    }
}
