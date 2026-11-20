import FirefoxSyncKit
import Foundation
import Observation

// Phone tabs grouped by space; Essentials belong to no space.
@Observable
final class BrowserModel {
    var tabs: [BrowserTab]
    var selectedID: UUID
    var selectedSpaceID: String? {
        didSet { defaults?.set(selectedSpaceID, forKey: Self.spaceKey) }
    }

    // Sync ids this phone owns in Zen's spaces collection; only these may ever get a tombstone.
    private(set) var mirrored: [String: String]
    private(set) var revision = 0

    private let defaults: UserDefaults?
    private static let key = "browser.tabs"
    private static let spaceKey = "browser.space"
    private static let mirrorKey = "browser.mirrored"

    init(tabs: [BrowserTab]? = nil, defaults: UserDefaults? = .standard) {
        self.defaults = tabs == nil ? defaults : nil
        let restored = tabs ?? Self.restore(from: defaults)
        let list = restored.isEmpty ? [BrowserTab()] : restored
        self.tabs = list
        selectedID = list[0].id
        selectedSpaceID = tabs == nil ? defaults?.string(forKey: Self.spaceKey) : nil
        mirrored = (tabs == nil ? defaults?.dictionary(forKey: Self.mirrorKey) as? [String: String] : nil) ?? [:]
    }

    func isMirrored(_ syncID: String) -> Bool {
        mirrored[syncID] != nil
    }

    // What to send to Zen spaces: new and changed tabs, plus tombstones for own closed ones.
    func mirrorPlan(isZenSpace: (String) -> Bool) -> (changed: [MirroredTab], removed: [String], next: [String: String]) {
        var next: [String: String] = [:]
        var changed: [MirroredTab] = []
        for tab in tabs where tab.pinnedURL == nil {
            guard let url = tab.url, ["http", "https"].contains(url.scheme ?? ""), let space = tab.spaceID, isZenSpace(space) else { continue }
            let signature = Self.signature(url, tab.title, space)
            next[tab.syncID] = signature
            if mirrored[tab.syncID] != signature {
                changed.append(MirroredTab(id: tab.syncID, url: url, title: tab.title, spaceID: space))
            }
        }
        let removed = mirrored.keys.filter { next[$0] == nil }.sorted()
        return (changed, removed, next)
    }

    // Phone and Zen tabs of a space as one list in Zen's order; tabs Zen has not echoed back yet go last.
    func entries(in space: Space?) -> [TabEntry] {
        let mine = openTabs(in: space?.id)
        let bySync = Dictionary(mine.map { ($0.syncID, $0) }, uniquingKeysWith: { first, _ in first })
        var placed: Set<String> = []
        var result: [TabEntry] = []
        for zen in space?.openTabs ?? [] {
            if let tab = bySync[zen.id] {
                result.append(.phone(tab))
                placed.insert(zen.id)
            } else if mirrored[zen.id] == nil {
                result.append(.zen(zen))
            }
        }
        return result + mine.filter { !placed.contains($0.syncID) }.map(TabEntry.phone)
    }

    // Opens a Zen tab here as the same tab, so closing it on either side closes it on both.
    func open(zen tab: SpaceTab, in spaceID: String) {
        if let existing = tabs.first(where: { $0.syncID == tab.id }) {
            select(existing)
            return
        }
        if selected.isBlank, tabs.count > 1 {
            tabs.removeAll { $0.id == selectedID }
        }
        let opened = BrowserTab(url: tab.url, title: tab.title, spaceID: spaceID, syncID: tab.id)
        tabs.append(opened)
        selectedID = opened.id
        selectedSpaceID = spaceID
        mirrored[tab.id] = Self.signature(tab.url, tab.title, spaceID)
        defaults?.set(mirrored, forKey: Self.mirrorKey)
        save()
    }

    func open(_ entry: TabEntry, in space: Space?) {
        switch entry {
        case .phone(let tab): select(tab)
        case .zen(let tab): open(zen: tab, in: space?.id ?? selectedSpaceID ?? "")
        }
    }

    func close(_ entry: TabEntry) {
        switch entry {
        case .phone(let tab): close(tab)
        case .zen(let tab): closeRemote(tab.id)
        }
    }

    // Closes a Zen tab without opening it; the next sync sends its tombstone.
    func closeRemote(_ id: String) {
        mirrored[id] = ""
        defaults?.set(mirrored, forKey: Self.mirrorKey)
        revision += 1
    }

    static func signature(_ url: URL, _ title: String, _ space: String) -> String {
        "\(url.absoluteString)\t\(title)\t\(space)"
    }

    func confirmMirror(_ next: [String: String]) {
        mirrored = next
        defaults?.set(next, forKey: Self.mirrorKey)
    }

    // Closes phone tabs that were closed in Zen and stops treating them as own.
    func closeRemoved(_ tombstones: Set<String>) {
        let gone = tabs.filter { mirrored[$0.syncID] != nil && tombstones.contains($0.syncID) }
        guard !gone.isEmpty else { return }
        for tab in gone {
            mirrored[tab.syncID] = nil
            close(tab)
        }
        defaults?.set(mirrored, forKey: Self.mirrorKey)
    }

    var selected: BrowserTab {
        tabs.first { $0.id == selectedID } ?? tabs[0]
    }

    // Tabs of a space together with Essentials, which are shared by all.
    func tabs(in spaceID: String?) -> [BrowserTab] {
        tabs.filter { $0.spaceID == nil || $0.spaceID == spaceID }
    }

    // Open tabs of a space without pinned ones: those show as pins and Essentials.
    func openTabs(in spaceID: String?) -> [BrowserTab] {
        tabs(in: spaceID).filter { $0.pinnedURL == nil && !$0.isBlank }
    }

    func liveTab(for url: URL) -> BrowserTab? {
        tabs.first { $0.pinnedURL == url }
    }

    // A pin reuses its tab if one exists; Essentials live outside spaces.
    func open(_ url: URL, pinned: Bool = false, essential: Bool = false) {
        if pinned || essential, let existing = liveTab(for: url) {
            select(existing)
            return
        }
        let space = essential ? nil : selectedSpaceID
        if selected.isBlank, selected.spaceID == space || selected.spaceID == nil {
            selected.pinnedURL = pinned || essential ? url : nil
            selected.spaceID = space
            selected.lastUsed = .now
            selected.load(url)
        } else {
            let tab = BrowserTab(url: url, pinnedURL: pinned || essential ? url : nil, spaceID: space)
            tabs.append(tab)
            selectedID = tab.id
        }
        save()
    }

    func newTab() {
        if let blank = tabs.first(where: { $0.isBlank && $0.spaceID == selectedSpaceID }) {
            select(blank)
            return
        }
        let tab = BrowserTab(spaceID: selectedSpaceID)
        tabs.append(tab)
        selectedID = tab.id
    }

    func close(_ tab: BrowserTab) {
        let siblings = tabs(in: tab.spaceID ?? selectedSpaceID)
        let position = siblings.firstIndex { $0.id == tab.id } ?? 0
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty { tabs = [BrowserTab(spaceID: selectedSpaceID)] }
        if selectedID == tab.id {
            let rest = tabs(in: selectedSpaceID)
            selectedID = (rest.isEmpty ? tabs : rest)[min(position, max(0, (rest.isEmpty ? tabs : rest).count - 1))].id
        }
        save()
    }

    func select(_ tab: BrowserTab) {
        selectedID = tab.id
        tab.lastUsed = .now
        if let space = tab.spaceID { selectedSpaceID = space }
    }

    // Steps to a neighbor tab of the current space with a swipe on the bottom bar.
    func step(_ offset: Int) {
        let list = tabs(in: selectedSpaceID)
        guard let index = list.firstIndex(where: { $0.id == selectedID }) else { return }
        let next = index + offset
        guard list.indices.contains(next) else { return }
        select(list[next])
    }

    // Assigns the first space to tabs from older versions that have none.
    func adopt(into spaceID: String?) {
        guard let spaceID else { return }
        for tab in tabs where tab.spaceID == nil && tab.pinnedURL == nil {
            tab.spaceID = spaceID
        }
        if selectedSpaceID == nil { selectedSpaceID = spaceID }
        save()
    }

    // Changes on any address or title edit; used to debounce the sync upload.
    var syncSignature: [String] {
        tabs.map { "\($0.url?.absoluteString ?? "")\t\($0.title)" }
    }

    var localTabs: [LocalTab] {
        tabs.compactMap { tab in tab.url.map { LocalTab(url: $0, title: tab.title, lastUsed: tab.lastUsed) } }
    }

    func save() {
        let stored = tabs.compactMap { tab in
            tab.url.map { Stored(id: tab.id, url: $0, title: tab.title, pinnedURL: tab.pinnedURL, spaceID: tab.spaceID, lastUsed: tab.lastUsed, syncID: tab.syncID) }
        }
        defaults?.set(try? JSONEncoder().encode(stored), forKey: Self.key)
    }

    static func restore(from defaults: UserDefaults?) -> [BrowserTab] {
        guard let data = defaults?.data(forKey: key), let stored = try? JSONDecoder().decode([Stored].self, from: data) else { return [] }
        return stored.map { BrowserTab(id: $0.id, url: $0.url, title: $0.title, pinnedURL: $0.pinnedURL, spaceID: $0.spaceID, lastUsed: $0.lastUsed ?? .now, syncID: $0.syncID) }
    }

    struct Stored: Codable {
        var id: UUID
        var url: URL
        var title: String
        var pinnedURL: URL?
        var spaceID: String?
        var lastUsed: Date?
        var syncID: String?
    }
}
