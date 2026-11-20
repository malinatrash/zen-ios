import Foundation

// Everything the app shows from the account: Zen spaces and device tabs.
public struct SyncSnapshot: Sendable, Equatable {
    public var spaces: SpacesLibrary
    public var devices: [RemoteDevice]
    public var spacesState: SpacesState
    public var date: Date
    public var spaceTombstones: Set<String> = []
    public var desktopNormalTabs: Bool?

    public static let normalTabsPref = "zen.spaces-sync.normal-tabs"

    public enum SpacesState: Sendable, Equatable {
        case available
        case notEnabled
        case unsupportedVersion(Int)
    }

    public init(spaces: SpacesLibrary = .empty, devices: [RemoteDevice] = [], spacesState: SpacesState = .notEnabled, date: Date = .now) {
        self.spaces = spaces
        self.devices = devices
        self.spacesState = spacesState
        self.date = date
    }
}

extension SyncStorage {
    // Reads spaces, tabs and clients in one pass; skips spaces from foreign engine versions.
    public func snapshot(excluding ownDevice: String? = nil) async throws -> SyncSnapshot {
        let known = try await collections()
        var result = SyncSnapshot()
        if known["tabs"] != nil {
            let tabs = try await decoded(TabsRecord.self, in: "tabs")
            let clients = known["clients"] == nil ? [] : try await decoded(ClientRecord.self, in: "clients")
            result.devices = RemoteDevice.join(tabs: tabs, clients: clients).filter { $0.id != ownDevice }
        }
        if known["prefs"] != nil {
            result.desktopNormalTabs = try await syncedPref(SyncSnapshot.normalTabsPref)
        }
        guard known[SpacesRecord.collection] != nil else { return result }
        let version = try await meta().engines?[SpacesRecord.collection]?.version
        if let version, version != SpacesRecord.engineVersion {
            result.spacesState = .unsupportedVersion(version)
            return result
        }
        let records = try await decoded(SpacesRecord.self, in: SpacesRecord.collection)
        result.spaces = SpacesLibrary(records: records)
        result.spaceTombstones = Set(records.compactMap { record in
            if case .tombstone(let id) = record { return id }
            return nil
        })
        result.spacesState = .available
        return result
    }
}

extension SyncStorage {
    // Reads one boolean from the desktop's synced prefs; nil when it is at its default or not synced.
    func syncedPref(_ name: String) async throws -> Bool? {
        for raw in try await records(in: "prefs") {
            let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
            if let value = (object?["value"] as? [String: Any])?[name] as? Bool {
                return value
            }
        }
        return nil
    }
}
