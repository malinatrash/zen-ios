import Foundation

// A phone tab as it goes into the tabs collection.
public struct LocalTab: Sendable, Equatable {
    public var url: URL
    public var title: String
    public var lastUsed: Date

    public init(url: URL, title: String, lastUsed: Date) {
        self.url = url
        self.title = title
        self.lastUsed = lastUsed
    }
}

public struct OwnDevice: Sendable, Equatable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

struct ClientUpload: Encodable {
    var id: String
    var name: String
    var type = "mobile"
    var fxaDeviceId: String
    var protocols = ["1.5"]
    var os = "iOS"
    var application = "Zen iOS"
    var commands: [String] = []
}

struct TabsUpload: Encodable {
    var id: String
    var clientName: String
    var tabs: [Tab]

    struct Tab: Encodable {
        var title: String
        var urlHistory: [String]
        var lastUsed: Int
    }

    static let limit = 100

    // Only http(s); long addresses and titles are trimmed; freshest tabs first.
    static func prepare(_ tabs: [LocalTab]) -> [Tab] {
        tabs
            .filter { ["http", "https"].contains($0.url.scheme?.lowercased() ?? "") && $0.url.absoluteString.count < 65_536 }
            .sorted { $0.lastUsed > $1.lastUsed }
            .prefix(limit)
            .map { Tab(title: String($0.title.prefix(512)), urlHistory: [$0.url.absoluteString], lastUsed: Int($0.lastUsed.timeIntervalSince1970)) }
    }
}

extension SyncStorage {
    // Publishes phone tabs: the clients record once per session, then the own tabs record.
    public func publish(device: OwnDevice, tabs: [LocalTab]) async throws {
        guard !(try await meta().declined ?? []).contains("tabs") else { return }
        let encoder = JSONEncoder()
        if publishedClient != device.id {
            let client = ClientUpload(id: device.id, name: device.name, fxaDeviceId: device.id)
            try await upload([(device.id, encoder.encode(client))], to: "clients")
            publishedClient = device.id
        }
        let record = TabsUpload(id: device.id, clientName: device.name, tabs: TabsUpload.prepare(tabs))
        try await upload([(device.id, encoder.encode(record))], to: "tabs")
    }
}
