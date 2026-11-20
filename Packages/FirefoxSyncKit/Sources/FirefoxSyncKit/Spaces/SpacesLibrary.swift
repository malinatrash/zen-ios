import Foundation

// Space tree assembled from the flat records of the spaces collection.
public struct SpacesLibrary: Sendable, Equatable {
    public var spaces: [Space]
    public var containers: [String: SpacesRecord.ContainerData]
    var essentialsByContainer: [String: [SpaceTab]]

    public static let empty = SpacesLibrary(records: [])
    static let defaultContainerKey = "default"

    public init(records: [SpacesRecord]) {
        var index = RecordIndex(records: records)
        spaces = index.orderedSpaces().map { data in
            Space(
                id: data.uuid,
                name: data.name ?? "",
                icon: SpaceIcon(raw: data.icon),
                theme: data.theme,
                containerGuid: data.containerGuid,
                items: (data.children ?? []).flatMap { index.resolve($0) }
            )
        }
        containers = index.containers
        essentialsByContainer = index.essentials()
    }

    // Essentials of a space: by its container in separate mode, otherwise all of them.
    public func essentials(for space: Space?, separateByContainer: Bool = true) -> [SpaceTab] {
        guard separateByContainer, let space else { return allEssentials }
        return essentialsByContainer[space.containerGuid ?? Self.defaultContainerKey] ?? []
    }

    public var allEssentials: [SpaceTab] {
        essentialsByContainer.keys.sorted().flatMap { essentialsByContainer[$0] ?? [] }
    }

    public var isEmpty: Bool {
        spaces.isEmpty && essentialsByContainer.isEmpty
    }
}

public struct Space: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var icon: SpaceIcon
    public var theme: SpaceTheme?
    public var containerGuid: String?
    public var items: [SpaceItem]

    public init(id: String, name: String, icon: SpaceIcon = .none, theme: SpaceTheme? = nil, containerGuid: String? = nil, items: [SpaceItem] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.theme = theme
        self.containerGuid = containerGuid
        self.items = items
    }

    public var pinned: [SpaceItem] {
        items.filter(\.isPinned)
    }

    public var openTabs: [SpaceTab] {
        items.compactMap { item in
            if case .tab(let tab) = item, !tab.isPinned { return tab }
            return nil
        }
    }
}

public enum SpaceIcon: Sendable, Equatable, Hashable {
    case emoji(String)
    case named(String)
    case none

    // Zen stores either an emoji or chrome://…/selectable/<name>.svg.
    public init(raw: String?) {
        guard let raw, !raw.isEmpty else {
            self = .none
            return
        }
        guard raw.hasPrefix("chrome://") else {
            self = .emoji(raw)
            return
        }
        let file = raw.split(separator: "/").last.map(String.init) ?? ""
        self = .named(file.replacingOccurrences(of: ".svg", with: ""))
    }
}

public struct SpaceTab: Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var url: URL
    public var title: String
    public var iconDataURL: String?
    public var isEssential: Bool
    public var isPinned: Bool
    public var containerGuid: String?

    public init(id: String, url: URL, title: String, iconDataURL: String? = nil, isEssential: Bool = false, isPinned: Bool = false, containerGuid: String? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.iconDataURL = iconDataURL
        self.isEssential = isEssential
        self.isPinned = isPinned
        self.containerGuid = containerGuid
    }

    init?(_ data: SpacesRecord.TabData) {
        guard let url = URL(string: data.url), url.scheme != nil else { return nil }
        let label = [data.staticLabel, data.title].compactMap { $0 }.first { !$0.isEmpty }
        self.init(
            id: data.tabId,
            url: url,
            title: label ?? url.host() ?? data.url,
            iconDataURL: data.icon.flatMap { $0.hasPrefix("data:") ? $0 : nil },
            isEssential: data.essential ?? false,
            isPinned: data.pinned ?? false,
            containerGuid: data.containerGuid
        )
    }
}

public struct SpaceFolder: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var icon: SpaceIcon
    public var items: [SpaceItem]

    public init(id: String, name: String, icon: SpaceIcon = .none, items: [SpaceItem] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.items = items
    }
}

public indirect enum SpaceItem: Sendable, Equatable, Identifiable {
    case tab(SpaceTab)
    case folder(SpaceFolder)

    public var id: String {
        switch self {
        case .tab(let tab): tab.id
        case .folder(let folder): folder.id
        }
    }

    public var isPinned: Bool {
        switch self {
        case .tab(let tab): tab.isPinned
        case .folder: true
        }
    }
}

struct RecordIndex {
    var spaces: [String: SpacesRecord.SpaceData] = [:]
    var tabs: [String: SpacesRecord.TabData] = [:]
    var folders: [String: SpacesRecord.FolderData] = [:]
    var splits: [String: SpacesRecord.SplitData] = [:]
    var containers: [String: SpacesRecord.ContainerData] = [:]
    var layout = SpacesRecord.LayoutData()
    var visiting: Set<String> = []

    init(records: [SpacesRecord]) {
        for record in records {
            switch record {
            case .space(let data): spaces[data.uuid] = data
            case .tab(let data): tabs[data.tabId] = data
            case .folder(let data): folders[data.folderId] = data
            case .split(let data): splits[data.splitId] = data
            case .container(let data): containers[data.guid] = data
            case .layout(let data): layout = data
            case .tombstone, .unknown: break
            }
        }
    }

    // Order comes from layout; spaces missing there go last.
    func orderedSpaces() -> [SpacesRecord.SpaceData] {
        let listed = (layout.spaces ?? []).compactMap { spaces[$0] }
        let known = Set(listed.map(\.uuid))
        let rest = spaces.values.filter { !known.contains($0.uuid) }.sorted { $0.uuid < $1.uuid }
        return listed + rest
    }

    // Resolves an id into an item: a split becomes its tabs, a folder is walked recursively.
    mutating func resolve(_ id: String) -> [SpaceItem] {
        if let data = tabs[id] {
            return SpaceTab(data).map { [.tab($0)] } ?? []
        }
        if let split = splits[id] {
            return (split.tabs ?? []).compactMap { tabs[$0] }.compactMap(SpaceTab.init).map(SpaceItem.tab)
        }
        guard let folder = folders[id], visiting.insert(id).inserted else { return [] }
        defer { visiting.remove(id) }
        let items = (folder.children ?? []).flatMap { resolve($0) }
        return [.folder(SpaceFolder(id: id, name: folder.name ?? "", icon: SpaceIcon(raw: folder.icon), items: items))]
    }

    func essentials() -> [String: [SpaceTab]] {
        var result: [String: [SpaceTab]] = [:]
        var placed: Set<String> = []
        for (key, ids) in layout.essentials ?? [:] {
            let found = ids.compactMap { tabs[$0] }.filter { $0.essential == true }.compactMap(SpaceTab.init)
            placed.formUnion(found.map(\.id))
            result[key] = found
        }
        let stray = tabs.values.filter { $0.essential == true && !placed.contains($0.tabId) }.sorted { $0.tabId < $1.tabId }
        for data in stray {
            guard let tab = SpaceTab(data) else { continue }
            result[data.containerGuid ?? SpacesLibrary.defaultContainerKey, default: []].append(tab)
        }
        return result.filter { !$0.value.isEmpty }
    }
}
