import AppKit
import Combine
import CryptoKit
import Security

@MainActor
class SpotifyAuth: ObservableObject {
    static let shared = SpotifyAuth()

    // MARK: - Replace with your Spotify app's Client ID from developer.spotify.com
    private let clientID = "81dfea34ee154383a3c01260cb5fe340"
    private let redirectURI = "castspot://callback"
    private let scopes = "user-read-playback-state user-modify-playback-state"

    @Published var isAuthenticated = false

    private var pendingVerifier: String?

    private init() {
        isAuthenticated = loadStoredTokens() != nil
    }

    // MARK: - OAuth PKCE

    func startAuthFlow() {
        let verifier = makeCodeVerifier()
        pendingVerifier = verifier
        let challenge = makeCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "scope", value: scopes),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    func handleCallback(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
            let verifier = pendingVerifier
        else { return }
        pendingVerifier = nil
        Task { try? await exchangeCode(code, verifier: verifier) }
    }

    func validAccessToken() async throws -> String {
        guard let stored = loadStoredTokens() else { throw AuthError.notAuthenticated }
        if let expiry = stored.expiryDate, expiry > Date() {
            return stored.accessToken
        }
        return try await refresh(using: stored.refreshToken)
    }

    func signOut() {
        deleteFromKeychain(key: "castspot_tokens")
        isAuthenticated = false
    }

    // MARK: - Token Exchange

    private static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!

    private func performTokenRequest(body: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: Self.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formEncode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func exchangeCode(_ code: String, verifier: String) async throws {
        let response = try await performTokenRequest(body: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ])
        saveTokens(response, existingRefresh: nil)
    }

    private func refresh(using refreshToken: String) async throws -> String {
        let response = try await performTokenRequest(body: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])
        saveTokens(response, existingRefresh: refreshToken)
        return response.accessToken
    }

    // MARK: - Keychain

    private func saveTokens(_ response: TokenResponse, existingRefresh: String?) {
        let stored = StoredTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? existingRefresh ?? "",
            expiryDate: Date().addingTimeInterval(TimeInterval(response.expiresIn - 60))
        )
        if let data = try? JSONEncoder().encode(stored) {
            saveToKeychain(key: "castspot_tokens", data: data)
            isAuthenticated = true
        }
    }

    func loadStoredTokens() -> StoredTokens? {
        guard let data = loadFromKeychain(key: "castspot_tokens") else { return nil }
        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }

    private func saveToKeychain(key: String, data: Data) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> Data? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecReturnData: true]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    private func deleteFromKeychain(key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - PKCE Helpers

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private func makeCodeChallenge(from verifier: String) -> String {
        base64URLEncode(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private func formEncode(_ dict: [String: String]) -> Data {
        dict.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)!
    }
}

// MARK: - Models

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct StoredTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiryDate: Date?
}

enum AuthError: Error {
    case notAuthenticated
}
