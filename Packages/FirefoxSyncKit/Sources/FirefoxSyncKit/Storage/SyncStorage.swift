import Foundation

// Reads encrypted collections from the Firefox Sync storage server.
public actor SyncStorage {
    let account: FirefoxAccount
    let credentials: Credentials
    let transport: any HTTPTransport
    var accessToken: AccessToken?
    var publishedClient: String?
    var node: Node?
    var keys: CollectionKeys?

    public init(account: FirefoxAccount, credentials: Credentials) {
        self.account = account
        self.credentials = credentials
        self.transport = account.transport
    }

    // Returns decrypted records of a collection, skipping deleted ones and ones with a bad signature.
    public func records(in collection: String) async throws -> [Data] {
        let bundle = try await collectionKeys().bundle(for: collection)
        let envelopes: [Envelope] = try await get("storage/\(collection)?full=1")
        return envelopes.compactMap { envelope in
            guard let payload = try? JSONDecoder().decode(EncryptedPayload.self, from: Data(envelope.payload.utf8)) else { return nil }
            return try? bundle.decrypt(payload)
        }
    }

    public func decoded<T: Decodable>(_ type: T.Type, in collection: String) async throws -> [T] {
        try await records(in: collection).compactMap { try? JSONDecoder().decode(type, from: $0) }
    }

    // Last-modified time of each collection; decides whether to re-read.
    public func collections() async throws -> [String: Double] {
        try await get("info/collections")
    }

    public func meta() async throws -> MetaGlobal {
        let envelope: Envelope = try await get("storage/meta/global")
        let meta = try JSONDecoder().decode(MetaGlobal.self, from: Data(envelope.payload.utf8))
        guard meta.storageVersion == 5 else { throw SyncError.unsupportedStorage }
        return meta
    }

    func collectionKeys() async throws -> CollectionKeys {
        if let keys { return keys }
        let envelope: Envelope = try await get("storage/crypto/keys")
        let payload = try JSONDecoder().decode(EncryptedPayload.self, from: Data(envelope.payload.utf8))
        do {
            let clear = try credentials.key.bundle().decrypt(payload)
            let loaded = try JSONDecoder().decode(CollectionKeys.self, from: clear)
            keys = loaded
            return loaded
        } catch SyncCryptoError.hmacMismatch {
            throw SyncError.keysChanged
        }
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try JSONDecoder().decode(T.self, from: await send("GET", path))
    }

    // Signs a storage request with Hawk; on 401 fetches a fresh node token once.
    func send(_ method: String, _ path: String, body: Data? = nil, retry: Bool = true) async throws -> Data {
        let node = try await currentNode()
        guard let url = URL(string: node.api_endpoint + "/" + path) else { throw SyncError.badResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(Hawk(id: node.id, key: node.key).header(method: method, url: url), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        do {
            let (data, response) = try await transport.success(request)
            if let wait = response.value(forHTTPHeaderField: "X-Weave-Backoff").flatMap(Int.init) {
                backoffUntil = Date().addingTimeInterval(TimeInterval(wait))
            }
            return data
        } catch SyncError.http(status: 401, _) where retry {
            self.node = nil
            keys = nil
            return try await send(method, path, body: body, retry: false)
        }
    }

    // Encrypts own records with the collection key and sends them in one POST.
    public func upload(_ records: [(id: String, cleartext: Data)], to collection: String, ttl: Int? = 15_552_000) async throws {
        let bundle = try await collectionKeys().bundle(for: collection)
        let items = try records.map { record -> [String: Any] in
            let payload = try JSONEncoder().encode(bundle.encrypt(record.cleartext))
            var item: [String: Any] = ["id": record.id, "payload": String(decoding: payload, as: UTF8.self)]
            item["ttl"] = ttl
            return item
        }
        let reply = try await send("POST", "storage/\(collection)", body: JSONSerialization.data(withJSONObject: items))
        let parsed = try JSONSerialization.jsonObject(with: reply) as? [String: Any]
        if let failed = parsed?["failed"] as? [String: Any], !failed.isEmpty {
            throw SyncError.http(status: 400, body: "\(collection): \(failed.keys.sorted())")
        }
    }

    var backoffUntil = Date.distantPast

    // The storage token lasts about an hour and is issued for the account token plus the key id.
    func currentNode() async throws -> Node {
        if backoffUntil > Date() { throw SyncError.backoff(seconds: Int(backoffUntil.timeIntervalSinceNow)) }
        if let node, node.expires > Date() { return node }
        if accessToken?.isFresh != true {
            accessToken = try await account.accessToken(for: credentials)
        }
        var request = URLRequest(url: account.config.tokenServer)
        request.setValue("Bearer \(accessToken?.value ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.key.kid, forHTTPHeaderField: "X-KeyID")
        do {
            var fresh: Node = try await transport.json(request)
            fresh.expires = Date().addingTimeInterval(fresh.duration * 0.9)
            node = fresh
            return fresh
        } catch SyncError.http(status: 401, let body) where body.contains("invalid-client-state") {
            throw SyncError.keysChanged
        }
    }

    struct Node: Decodable {
        var id: String
        var key: String
        var api_endpoint: String
        var duration: Double
        var expires = Date.distantPast

        private enum CodingKeys: String, CodingKey {
            case id, key, api_endpoint, duration
        }
    }

    struct Envelope: Decodable {
        var id: String
        var payload: String
    }
}

public struct MetaGlobal: Sendable, Equatable, Decodable {
    public var storageVersion: Int
    public var engines: [String: Engine]?
    public var declined: [String]?

    public struct Engine: Sendable, Equatable, Decodable {
        public var version: Int
        public var syncID: String?
    }
}

// Contents of crypto/keys: the default key and optional per-collection keys.
struct CollectionKeys: Decodable {
    var `default`: [String]
    var collections: [String: [String]]?

    func bundle(for collection: String) throws -> KeyBundle {
        let pair = collections?[collection] ?? `default`
        guard pair.count == 2, let enc = Data(base64Encoded: pair[0]), let mac = Data(base64Encoded: pair[1]) else {
            throw SyncCryptoError.badKey
        }
        return try KeyBundle(encryptionKey: enc, hmacKey: mac)
    }
}
