import Foundation

// A phone tab that Zen will create as a normal tab in its own space.
public struct MirroredTab: Sendable, Equatable {
    public var id: String
    public var url: URL
    public var title: String
    public var spaceID: String

    public init(id: String, url: URL, title: String, spaceID: String) {
        self.id = id
        self.url = url
        self.title = title
        self.spaceID = spaceID
    }

    // The record in the shape ZenSpacesSyncModel builds for a normal tab.
    var cleartext: [String: Any] {
        let data: [String: Any] = [
            "tabId": id, "url": url.absoluteString, "title": title, "icon": "",
            "containerGuid": NSNull(), "essential": false, "pinned": false,
            "workspaceUuid": spaceID, "folderId": NSNull(), "staticLabel": NSNull(),
            "hasStaticIcon": false, "defaultContainer": false,
        ]
        return ["id": id, "kind": "tab", "data": data]
    }
}

extension SyncStorage {
    // Puts phone tabs into Zen spaces and tombstones only its own closed tabs.
    // Zen applies normal tabs only when zen.spaces-sync.normal-tabs is true in about:config on desktop.
    public func mirror(_ tabs: [MirroredTab], removed: [String]) async throws {
        guard !tabs.isEmpty || !removed.isEmpty else { return }
        guard try await collections()[SpacesRecord.collection] != nil else { throw SyncError.unsupportedStorage }
        let meta = try await meta()
        if let version = meta.engines?[SpacesRecord.collection]?.version, version != SpacesRecord.engineVersion {
            throw SyncError.unsupportedStorage
        }
        guard !(meta.declined ?? []).contains(SpacesRecord.collection) else { throw SyncError.unsupportedStorage }
        var records = try tabs.map { ($0.id, try JSONSerialization.data(withJSONObject: $0.cleartext)) }
        records += try removed.map { ($0, try JSONSerialization.data(withJSONObject: ["id": $0, "deleted": true])) }
        for start in stride(from: 0, to: records.count, by: 100) {
            try await upload(Array(records[start..<min(start + 100, records.count)]), to: SpacesRecord.collection, ttl: nil)
        }
    }
}
