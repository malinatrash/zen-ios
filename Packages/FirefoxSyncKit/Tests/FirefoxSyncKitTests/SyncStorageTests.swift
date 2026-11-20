import Foundation
import Testing
@testable import FirefoxSyncKit

// Fake server: account, token server and storage with real record encryption.
final class FakeServer: HTTPTransport, @unchecked Sendable {
    let syncKey = Data((0..<64).map { UInt8($0) })
    let collectionBundle: KeyBundle
    var collections: [String: [String]] = [:]
    var spacesVersion = 3
    var requests: [URLRequest] = []
    let lock = NSLock()

    init() throws {
        collectionBundle = try KeyBundle(encryptionKey: Data(repeating: 7, count: 32), hmacKey: Data(repeating: 9, count: 32))
    }

    var credentials: Credentials {
        Credentials(refreshToken: "refresh", key: ScopedKey(k: syncKey.base64URL, kid: "1700000000000-abc"))
    }

    func put(_ collection: String, _ cleartext: String) throws {
        collections[collection, default: []].append(cleartext)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { requests.append(request) }
        let url = try #require(request.url)
        let body = try reply(url: url, request: request)
        let response = try #require(HTTPURLResponse(url: url, statusCode: body == nil ? 404 : 200, httpVersion: nil, headerFields: nil))
        return (body ?? Data(), response)
    }

    func reply(url: URL, request: URLRequest) throws -> Data? {
        let path = url.path
        if path.hasSuffix("/account/device") {
            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer refresh" else { return nil }
            return Data(#"{"id":"phone-1","name":"iPhone"}"#.utf8)
        }
        if path.hasSuffix("/oauth/token") {
            return Data(#"{"access_token":"access","expires_in":3600}"#.utf8)
        }
        if url.host() == "token.services.mozilla.com" {
            guard request.value(forHTTPHeaderField: "X-KeyID") == "1700000000000-abc" else { return nil }
            return Data(#"{"id":"hawk-id","key":"hawk-key","uid":1,"api_endpoint":"https://node.test/1.5/1","duration":3600}"#.utf8)
        }
        guard request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Hawk id=\"hawk-id\"") == true else { return nil }
        if path.hasSuffix("/info/collections") {
            let names = collections.keys.map { "\"\($0)\":1700000000.12" }.joined(separator: ",")
            return Data("{\(names)}".utf8)
        }
        if path.hasSuffix("/storage/meta/global") {
            let payload = #"{"syncID":"x","storageVersion":5,"engines":{"spaces":{"version":\#(spacesVersion),"syncID":"y"}},"declined":[]}"#
            return try envelope(id: "global", payload: payload)
        }
        if path.hasSuffix("/storage/crypto/keys") {
            let keys = [collectionBundle.encryptionKey.base64EncodedString(), collectionBundle.hmacKey.base64EncodedString()]
            let clear = try JSONSerialization.data(withJSONObject: ["id": "keys", "collection": "crypto", "default": keys])
            return try envelope(id: "keys", payload: encrypted(clear, with: KeyBundle(syncKey: syncKey)))
        }
        if request.httpMethod == "POST", let name = path.split(separator: "/").last.map(String.init) {
            return try accept(request.httpBody ?? Data(), into: name)
        }
        guard let name = path.split(separator: "/").last.map(String.init), let records = collections[name] else { return nil }
        let items = try records.enumerated().map { index, clear in
            try JSONSerialization.jsonObject(with: envelope(id: "r\(index)", payload: encrypted(Data(clear.utf8), with: collectionBundle)))
        }
        return try JSONSerialization.data(withJSONObject: items)
    }

    // Decrypts the uploaded records and replaces ones with the same id.
    func accept(_ body: Data, into collection: String) throws -> Data {
        let items = try #require(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        var ids: [String] = []
        for item in items {
            let id = try #require(item["id"] as? String)
            let payload = try JSONDecoder().decode(EncryptedPayload.self, from: Data(try #require(item["payload"] as? String).utf8))
            let clear = String(decoding: try collectionBundle.decrypt(payload), as: UTF8.self)
            let inner = try #require(JSONSerialization.jsonObject(with: Data(clear.utf8)) as? [String: Any])
            #expect(inner["id"] as? String == id)
            collections[collection, default: []].removeAll { $0.contains("\"id\":\"\(id)\"") }
            collections[collection, default: []].append(clear)
            ids.append(id)
        }
        return try JSONSerialization.data(withJSONObject: ["success": ids, "failed": [String: Any]()])
    }

    func encrypted(_ clear: Data, with bundle: KeyBundle) throws -> String {
        String(decoding: try JSONEncoder().encode(bundle.encrypt(clear)), as: UTF8.self)
    }

    func envelope(id: String, payload: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["id": id, "modified": 1_700_000_000.12, "payload": payload])
    }
}

struct SyncStorageTests {
    func storage(_ server: FakeServer) -> SyncStorage {
        SyncStorage(account: FirefoxAccount(transport: server), credentials: server.credentials)
    }

    @Test func snapshotJoinsTabsWithClientsAndSpaces() async throws {
        let server = try FakeServer()
        try server.put("clients", #"{"id":"dev1","name":"Zen on Mac","type":"desktop","application":"Zen"}"#)
        try server.put("tabs", #"{"id":"dev1","clientName":"old","tabs":[{"title":"Old","urlHistory":["https://a.example/"],"lastUsed":100},{"title":"","urlHistory":["https://b.example/x"],"lastUsed":"200","pinned":true},{"title":"skip","urlHistory":["about:config"],"lastUsed":300}]}"#)
        try server.put("spaces", #"{"id":"{s}","kind":"space","data":{"uuid":"{s}","name":"Home","children":["t1"]}}"#)
        try server.put("spaces", #"{"id":"t1","kind":"tab","data":{"tabId":"t1","url":"https://pin.example/","title":"Pin","pinned":true,"workspaceUuid":"{s}"}}"#)
        try server.put("spaces", #"{"id":"gone","deleted":true}"#)

        try server.put("prefs", #"{"id":"prefs1","type":"preferences","value":{"zen.spaces-sync.normal-tabs":true,"browser.startup.page":3}}"#)
        let snapshot = try await storage(server).snapshot()
        #expect(snapshot.desktopNormalTabs == true)
        #expect(snapshot.spacesState == .available)
        #expect(snapshot.spaces.spaces.map(\.name) == ["Home"])
        #expect(snapshot.spaces.spaces[0].pinned.count == 1)
        #expect(snapshot.devices.count == 1)
        #expect(snapshot.devices[0].name == "Zen on Mac")
        #expect(snapshot.devices[0].tabs.map(\.title) == ["b.example", "Old"])
        #expect(snapshot.devices[0].tabs[0].isPinned)
    }

    @Test func foreignSpacesVersionIsNotParsed() async throws {
        let server = try FakeServer()
        server.spacesVersion = 4
        try server.put("spaces", #"{"id":"{s}","kind":"space","data":{"uuid":"{s}","name":"Home"}}"#)
        let snapshot = try await storage(server).snapshot()
        #expect(snapshot.spacesState == .unsupportedVersion(4))
        #expect(snapshot.spaces.isEmpty)
    }

    @Test func missingSpacesMeansNotEnabled() async throws {
        let server = try FakeServer()
        try server.put("tabs", #"{"id":"dev1","clientName":"Mac","tabs":[{"title":"A","urlHistory":["https://a.example/"],"lastUsed":1}]}"#)
        let snapshot = try await storage(server).snapshot()
        #expect(snapshot.spacesState == .notEnabled)
        #expect(snapshot.desktopNormalTabs == nil)
        #expect(snapshot.devices[0].name == "Mac")
    }

    @Test func wrongSyncKeyReportsChangedKeys() async throws {
        let server = try FakeServer()
        try server.put("tabs", "{}")
        var credentials = server.credentials
        credentials.key.k = Data(repeating: 1, count: 64).base64URL
        let storage = SyncStorage(account: FirefoxAccount(transport: server), credentials: credentials)
        await #expect(throws: SyncError.keysChanged) {
            try await storage.snapshot()
        }
    }

    @Test func publishedTabsReachDesktopFormat() async throws {
        let server = try FakeServer()
        try server.put("clients", #"{"id":"dev1","name":"Zen on Mac","type":"desktop"}"#)
        try server.put("tabs", #"{"id":"dev1","clientName":"Mac","tabs":[{"title":"A","urlHistory":["https://a.example/"],"lastUsed":1}]}"#)
        let account = FirefoxAccount(transport: server)
        let deviceID = try await account.registerDevice(named: "iPhone", for: server.credentials)
        #expect(deviceID == "phone-1")

        let storage = SyncStorage(account: account, credentials: server.credentials)
        let tabs = [
            LocalTab(url: URL(string: "https://old.example/")!, title: "Old", lastUsed: Date(timeIntervalSince1970: 100)),
            LocalTab(url: URL(string: "https://new.example/")!, title: "New", lastUsed: Date(timeIntervalSince1970: 200)),
            LocalTab(url: URL(string: "about:blank")!, title: "skip", lastUsed: .now),
        ]
        try await storage.publish(device: OwnDevice(id: deviceID, name: "iPhone"), tabs: tabs)
        try await storage.publish(device: OwnDevice(id: deviceID, name: "iPhone"), tabs: Array(tabs.prefix(1)))

        let clientPosts = server.requests.filter { $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/storage/clients") == true }
        #expect(clientPosts.count == 1)
        #expect(server.collections["tabs"]?.count == 2)

        let everyone = try await storage.snapshot()
        let phone = try #require(everyone.devices.first { $0.id == "phone-1" })
        #expect(phone.kind == .mobile)
        #expect(phone.tabs.map(\.title) == ["Old"])

        let others = try await storage.snapshot(excluding: "phone-1")
        #expect(others.devices.map(\.id) == ["dev1"])
    }

    @Test func mirroredTabsLandInZenSpaceAndTombstoneOnClose() async throws {
        let server = try FakeServer()
        try server.put("spaces", #"{"id":"{s}","kind":"space","data":{"uuid":"{s}","name":"Work","children":[]}}"#)
        let storage = SyncStorage(account: FirefoxAccount(transport: server), credentials: server.credentials)
        let tab = MirroredTab(id: "1700000000000-abc", url: URL(string: "https://phone.example/")!, title: "From phone", spaceID: "{s}")

        try await storage.mirror([tab], removed: [])
        let stored = try #require(server.collections["spaces"]?.last)
        let json = try #require(JSONSerialization.jsonObject(with: Data(stored.utf8)) as? [String: Any])
        let data = try #require(json["data"] as? [String: Any])
        #expect(json["kind"] as? String == "tab")
        #expect(data["pinned"] as? Bool == false)
        #expect(data["essential"] as? Bool == false)
        #expect(data["workspaceUuid"] as? String == "{s}")
        #expect(data["folderId"] is NSNull)
        let posts = server.requests.filter { $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/storage/spaces") == true }
        let items = try #require(JSONSerialization.jsonObject(with: posts.last?.httpBody ?? Data()) as? [[String: Any]])
        #expect(items[0]["ttl"] == nil)

        try await storage.mirror([], removed: [tab.id])
        let snapshot = try await storage.snapshot()
        #expect(snapshot.spaceTombstones == [tab.id])
        #expect(snapshot.spaces.spaces.map(\.name) == ["Work"])
    }

    @Test func mirrorRefusesForeignSpacesVersion() async throws {
        let server = try FakeServer()
        server.spacesVersion = 4
        try server.put("spaces", #"{"id":"{s}","kind":"space","data":{"uuid":"{s}","name":"Work"}}"#)
        let storage = SyncStorage(account: FirefoxAccount(transport: server), credentials: server.credentials)
        let tab = MirroredTab(id: "1-a", url: URL(string: "https://a.example/")!, title: "A", spaceID: "{s}")
        await #expect(throws: SyncError.unsupportedStorage) {
            try await storage.mirror([tab], removed: [])
        }
        #expect(!server.requests.contains { $0.httpMethod == "POST" && $0.url?.path.contains("/storage/") == true })
    }

    @Test func tabsPrepareKeepsFreshestAndTrims() {
        let many = (0..<150).map { LocalTab(url: URL(string: "https://e.example/\($0)")!, title: String(repeating: "x", count: 600), lastUsed: Date(timeIntervalSince1970: Double($0))) }
        let prepared = TabsUpload.prepare(many)
        #expect(prepared.count == TabsUpload.limit)
        #expect(prepared[0].lastUsed == 149)
        #expect(prepared[0].title.count == 512)
    }

    @Test func loginURLCarriesPKCEAndKeys() throws {
        let attempt = FirefoxAccount().beginLogin()
        let items = try #require(URLComponents(url: attempt.url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        #expect(attempt.url.absoluteString.hasPrefix("https://accounts.firefox.com/authorization?"))
        #expect(query["context"] == "oauth_webchannel_v1")
        #expect(query["scope"] == "profile https://identity.mozilla.com/apps/oldsync")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["redirect_uri"] == nil)
        #expect(Data(base64URL: query["keys_jwk"] ?? "") != nil)
    }
}
