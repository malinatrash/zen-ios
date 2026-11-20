import Foundation

// A decrypted spaces record: {id, kind, data} or {id, deleted}.
public enum SpacesRecord: Sendable, Equatable {
    case container(ContainerData)
    case space(SpaceData)
    case tab(TabData)
    case folder(FolderData)
    case split(SplitData)
    case layout(LayoutData)
    case tombstone(id: String)
    case unknown(id: String)

    // Zen's engine version; when Zen bumps it, read ZenSpacesSyncModel again before raising this.
    public static let engineVersion = 3
    public static let collection = "spaces"

    public struct ContainerData: Sendable, Equatable, Decodable {
        public var guid: String
        public var name: String
        public var icon: String?
        public var color: String?
    }

    public struct SpaceData: Sendable, Equatable, Decodable {
        public var uuid: String
        public var name: String?
        public var icon: String?
        public var theme: SpaceTheme?
        public var containerGuid: String?
        public var children: [String]?
    }

    public struct TabData: Sendable, Equatable, Decodable {
        public var tabId: String
        public var url: String
        public var title: String?
        public var icon: String?
        public var containerGuid: String?
        public var essential: Bool?
        public var pinned: Bool?
        public var workspaceUuid: String?
        public var folderId: String?
        public var staticLabel: String?
        public var hasStaticIcon: Bool?
        public var defaultContainer: Bool?
    }

    public struct FolderData: Sendable, Equatable, Decodable {
        public var folderId: String
        public var name: String?
        public var icon: String?
        public var workspaceUuid: String?
        public var parentFolderId: String?
        public var children: [String]?
    }

    public struct SplitData: Sendable, Equatable, Decodable {
        public var splitId: String
        public var gridType: String?
        public var pinned: Bool?
        public var tabs: [String]?
        public var workspaceUuid: String?
        public var folderId: String?
    }

    public struct LayoutData: Sendable, Equatable, Decodable {
        public var spaces: [String]?
        public var essentials: [String: [String]]?
    }
}

extension SpacesRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, kind, data, deleted
    }

    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        let id = try box.decode(String.self, forKey: .id)
        if try box.decodeIfPresent(Bool.self, forKey: .deleted) == true {
            self = .tombstone(id: id)
            return
        }
        switch try box.decodeIfPresent(String.self, forKey: .kind) {
        case "container": self = .container(try box.decode(ContainerData.self, forKey: .data))
        case "space": self = .space(try box.decode(SpaceData.self, forKey: .data))
        case "tab": self = .tab(try box.decode(TabData.self, forKey: .data))
        case "folder": self = .folder(try box.decode(FolderData.self, forKey: .data))
        case "split": self = .split(try box.decode(SplitData.self, forKey: .data))
        case "layout": self = .layout(try box.decode(LayoutData.self, forKey: .data))
        default: self = .unknown(id: id)
        }
    }
}
