import FirefoxSyncKit
import Foundation
import Observation

// Firefox account state and the latest sync data for the UI.
@Observable
final class AccountModel {
    var snapshot = SyncSnapshot()
    var phase: Phase = .signedOut
    var isRefreshing = false
    // False until the first sync returns, so hints don't judge an empty snapshot.
    private(set) var hasSynced = false

    enum Phase: Equatable {
        case signedOut
        case signedIn
        case needsLogin
        case failed(String)
    }

    private let account = FirefoxAccount()
    private let store = CredentialsStore()
    private var storage: SyncStorage?
    private var credentials: Credentials?

    // Desktop shows the phone under this name in Synced Tabs and in the account's device list.
    static let deviceName = "iPhone (Zen)"
    private static let deviceKey = "fxa.deviceID"

    static var signedOutPreview: AccountModel { AccountModel(preview: SyncSnapshot(), signedIn: false) }

    init(preview: SyncSnapshot? = nil, signedIn: Bool = true) {
        if let preview {
            snapshot = preview
            hasSynced = true
            phase = signedIn ? .signedIn : .signedOut
            return
        }
        guard let credentials = store.load() else { return }
        self.credentials = credentials
        storage = SyncStorage(account: account, credentials: credentials)
        phase = .signedIn
    }

    var isSignedIn: Bool {
        phase != .signedOut && phase != .needsLogin
    }

    func beginLogin() -> LoginAttempt {
        account.beginLogin()
    }

    // Finishes sign-in with the code from the Mozilla page and fetches data right away.
    func finishLogin(_ attempt: LoginAttempt, code: String, state: String) async {
        do {
            let credentials = try await account.finishLogin(attempt, code: code, state: state)
            store.save(credentials)
            self.credentials = credentials
            storage = SyncStorage(account: account, credentials: credentials)
            phase = .signedIn
            await refresh()
        } catch {
            phase = .failed("Sign-in failed: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        guard let storage, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await storage.snapshot(excluding: UserDefaults.standard.string(forKey: Self.deviceKey))
            hasSynced = true
            phase = .signedIn
        } catch SyncError.signedOut, SyncError.keysChanged {
            phase = .needsLogin
        } catch SyncError.backoff {
            return
        } catch {
            phase = .failed("Sync failed: \(error.localizedDescription)")
        }
    }

    // Publishes phone tabs to sync, registering the phone as an account device on first run.
    func publish(_ tabs: [LocalTab]) async {
        guard let storage, let credentials, phase == .signedIn else { return }
        do {
            let id = try await deviceID(credentials)
            try await storage.publish(device: OwnDevice(id: id, name: Self.deviceName), tabs: tabs)
        } catch SyncError.signedOut, SyncError.keysChanged {
            phase = .needsLogin
        } catch {
            return
        }
    }

    // Puts phone tabs into Zen spaces; true if the server accepted.
    func mirror(_ tabs: [MirroredTab], removed: [String]) async -> Bool {
        guard let storage, phase == .signedIn, snapshot.spacesState == .available else { return false }
        do {
            try await storage.mirror(tabs, removed: removed)
            return true
        } catch SyncError.signedOut, SyncError.keysChanged {
            phase = .needsLogin
            return false
        } catch {
            return false
        }
    }

    private func deviceID(_ credentials: Credentials) async throws -> String {
        if let id = UserDefaults.standard.string(forKey: Self.deviceKey) { return id }
        let id = try await account.registerDevice(named: Self.deviceName, for: credentials)
        UserDefaults.standard.set(id, forKey: Self.deviceKey)
        return id
    }

    func signOut() async {
        if let credentials = store.load() {
            await account.signOut(credentials)
        }
        store.clear()
        UserDefaults.standard.removeObject(forKey: Self.deviceKey)
        credentials = nil
        storage = nil
        snapshot = SyncSnapshot()
        phase = .signedOut
    }
}
