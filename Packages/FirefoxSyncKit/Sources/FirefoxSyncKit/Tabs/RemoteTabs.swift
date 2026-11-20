import Foundation

// A tabs collection record: all open tabs of one device.
struct TabsRecord: Decodable {
    var id: String
    var clientName: String?
    var tabs: [Tab]?

    struct Tab: Decodable {
        var title: String?
        var urlHistory: [String]?
        var icon: String?
        var lastUsed: Double?
        var pinned: Bool?
        var inactive: Bool?

        private enum CodingKeys: String, CodingKey {
            case title, urlHistory, icon, lastUsed, pinned, inactive
        }

        init(from decoder: Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            title = try? box.decode(String.self, forKey: .title)
            urlHistory = try? box.decode([String].self, forKey: .urlHistory)
            icon = try? box.decode(String.self, forKey: .icon)
            pinned = try? box.decode(Bool.self, forKey: .pinned)
            inactive = try? box.decode(Bool.self, forKey: .inactive)
            if let number = try? box.decode(Double.self, forKey: .lastUsed) {
                lastUsed = number
            } else if let text = try? box.decode(String.self, forKey: .lastUsed) {
                lastUsed = Double(text)
            }
        }
    }
}

// A clients collection record: the device the tabs belong to.
struct ClientRecord: Decodable {
    var id: String
    var name: String?
    var type: String?
    var fxaDeviceId: String?
    var application: String?
}

public struct RemoteTab: Sendable, Equatable, Hashable, Identifiable {
    public var url: URL
    public var title: String
    public var iconURL: URL?
    public var lastUsed: Date
    public var isPinned: Bool

    public var id: String { url.absoluteString }

    public init(url: URL, title: String, iconURL: URL? = nil, lastUsed: Date = .now, isPinned: Bool = false) {
        self.url = url
        self.title = title
        self.iconURL = iconURL
        self.lastUsed = lastUsed
        self.isPinned = isPinned
    }
}

public struct RemoteDevice: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var kind: Kind
    public var application: String?
    public var tabs: [RemoteTab]

    public enum Kind: String, Sendable {
        case desktop, mobile, tablet
    }

    public init(id: String, name: String, kind: Kind = .desktop, application: String? = nil, tabs: [RemoteTab] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.application = application
        self.tabs = tabs
    }

    // Joins tabs with device descriptions, freshest tabs first.
    static func join(tabs: [TabsRecord], clients: [ClientRecord]) -> [RemoteDevice] {
        let byID = Dictionary(clients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let devices = tabs.map { record -> RemoteDevice in
            let client = byID[record.id]
            let list = (record.tabs ?? []).compactMap(RemoteTab.init).sorted { $0.lastUsed > $1.lastUsed }
            return RemoteDevice(
                id: record.id,
                name: client?.name ?? record.clientName ?? "Device",
                kind: Kind(rawValue: client?.type ?? "") ?? .desktop,
                application: client?.application,
                tabs: list
            )
        }
        return devices.filter { !$0.tabs.isEmpty }.sorted { $0.name < $1.name }
    }
}

extension RemoteTab {
    init?(_ tab: TabsRecord.Tab) {
        guard let first = tab.urlHistory?.first, let url = URL(string: first), url.scheme?.hasPrefix("http") == true else { return nil }
        self.init(
            url: url,
            title: tab.title.flatMap { $0.isEmpty ? nil : $0 } ?? url.host() ?? first,
            iconURL: tab.icon.flatMap(URL.init),
            lastUsed: Date(timeIntervalSince1970: tab.lastUsed ?? 0),
            isPinned: tab.pinned ?? false
        )
    }
}
