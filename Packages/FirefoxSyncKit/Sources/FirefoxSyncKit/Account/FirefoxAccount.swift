import CryptoKit
import Foundation

public struct AccountConfig: Sendable {
    // Borrowed Firefox for iOS client id: Mozilla issues none to third parties and can revoke this one at any time.
    public var clientID = "1b1a3e44c54fbb58"
    public var contentRoot = URL(string: "https://accounts.firefox.com")!
    public var authAPI = URL(string: "https://api.accounts.firefox.com/v1")!
    public var tokenServer = URL(string: "https://token.services.mozilla.com/1.0/sync/1.5")!
    public var entrypoint = "ios_settings_manage"

    public init() {}

    var scope: String { "profile " + ScopedKey.syncScope }
}

// What stays in the Keychain after sign-in.
public struct Credentials: Sendable, Equatable, Codable {
    public var refreshToken: String
    public var key: ScopedKey

    public init(refreshToken: String, key: ScopedKey) {
        self.refreshToken = refreshToken
        self.key = key
    }
}

// One sign-in attempt: the Mozilla page address and the secrets that verify its answer.
public struct LoginAttempt: Sendable {
    public let url: URL
    let state: String
    let verifier: String
    let keys: ScopedKeysFlow
}

public struct AccessToken: Sendable, Equatable {
    public var value: String
    public var expires: Date

    var isFresh: Bool { expires.timeIntervalSinceNow > 60 }
}

public struct AccountDevice: Sendable, Equatable, Identifiable, Decodable {
    public var id: String
    public var name: String
    public var type: String?
    public var isCurrentDevice: Bool?
    public var lastAccessTime: Double?
}

// Firefox account sign-in via OAuth with PKCE, delivering the sync key.
public struct FirefoxAccount: Sendable {
    let config: AccountConfig
    let transport: any HTTPTransport

    public init(config: AccountConfig = AccountConfig(), transport: any HTTPTransport = URLSession.shared) {
        self.config = config
        self.transport = transport
    }

    // Prepares the sign-in page the app opens in its own web view.
    public func beginLogin() -> LoginAttempt {
        let state = Data.random(16).base64URL
        let verifier = Data.random(43).base64URL
        let keys = ScopedKeysFlow()
        var components = URLComponents(url: config.contentRoot.appending(path: "authorization"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "email"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "entrypoint", value: config.entrypoint),
            URLQueryItem(name: "service", value: "sync"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: Data(SHA256.hash(data: Data(verifier.utf8))).base64URL),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "keys_jwk", value: keys.publicJWK),
            URLQueryItem(name: "scope", value: config.scope),
            URLQueryItem(name: "context", value: "oauth_webchannel_v1"),
        ]
        return LoginAttempt(url: components.url!, state: state, verifier: verifier, keys: keys)
    }

    // Exchanges the sign-in page's code for a long-lived token and the sync key.
    public func finishLogin(_ attempt: LoginAttempt, code: String, state: String) async throws -> Credentials {
        guard state == attempt.state else { throw SyncError.stateMismatch }
        let body = ["grant_type": "authorization_code", "client_id": config.clientID, "code": code, "code_verifier": attempt.verifier]
        let reply: TokenReply = try await transport.json(.postJSON(config.authAPI.appending(path: "oauth/token"), body: body))
        guard let refresh = reply.refresh_token, let jwe = reply.keys_jwe else { throw SyncError.badResponse }
        return Credentials(refreshToken: refresh, key: try attempt.keys.syncKey(fromJWE: jwe))
    }

    public func accessToken(for credentials: Credentials) async throws -> AccessToken {
        let body = ["grant_type": "refresh_token", "client_id": config.clientID, "refresh_token": credentials.refreshToken, "scope": ScopedKey.syncScope]
        do {
            let reply: TokenReply = try await transport.json(.postJSON(config.authAPI.appending(path: "oauth/token"), body: body))
            return AccessToken(value: reply.access_token, expires: Date().addingTimeInterval(reply.expires_in ?? 3600))
        } catch SyncError.http(let status, _) where status == 400 || status == 401 {
            throw SyncError.signedOut
        }
    }

    public func devices(for credentials: Credentials) async throws -> [AccountDevice] {
        var request = URLRequest(url: config.authAPI.appending(path: "account/devices"))
        request.setValue("Bearer \(credentials.refreshToken)", forHTTPHeaderField: "Authorization")
        return try await transport.json(request)
    }

    // Registers the phone as an account device; without it desktop will not show its tabs.
    public func registerDevice(named name: String, id: String? = nil, for credentials: Credentials) async throws -> String {
        var body: [String: Any] = ["name": name, "type": "mobile", "availableCommands": [String: String]()]
        if let id { body["id"] = id }
        let reply: DeviceReply = try await transport.json(.postJSON(config.authAPI.appending(path: "account/device"), body: body, bearer: credentials.refreshToken))
        return reply.id
    }

    struct DeviceReply: Decodable {
        var id: String
    }

    public func signOut(_ credentials: Credentials) async {
        let url = URL(string: "https://oauth.accounts.firefox.com/v1/destroy")!
        _ = try? await transport.send(.postJSON(url, body: ["refresh_token": credentials.refreshToken]))
    }

    struct TokenReply: Decodable {
        var access_token: String
        var refresh_token: String?
        var keys_jwe: String?
        var expires_in: Double?
    }
}
