import FirefoxSyncKit
import Foundation
import Observation

// Zen and phone spaces in one list; phone pins can also go into Zen spaces.
@Observable
final class SpacesModel {
    private(set) var local: LocalLibrary
    private let account: AccountModel
    private let file: URL?

    static let defaultFile = URL.applicationSupportDirectory.appending(path: "spaces.json")

    static let starter = LocalLibrary(spaces: [
        LocalSpace(name: "Personal", icon: "🏠", colors: [[244, 93, 74], [120, 96, 220]], opacity: 0.6),
    ])

    init(account: AccountModel, library: LocalLibrary? = nil, file: URL? = SpacesModel.defaultFile) {
        self.account = account
        self.file = library == nil ? file : nil
        local = library ?? file.flatMap(Self.load) ?? Self.starter
    }

    // Phone-only spaces never reach Zen; their tabs show on desktop only under Synced Tabs.
    var spaces: [Space] {
        let synced = account.snapshot.spaces.spaces.map { space in
            var merged = space
            merged.items += pins(in: space.id)
            return merged
        }
        let mine = local.spaces.map { space in
            Space(id: space.id, name: space.name, icon: SpaceIcon(raw: space.icon), theme: space.theme, items: pins(in: space.id))
        }
        return synced + mine
    }

    // Essentials of a Zen space plus the ones added on the phone.
    func essentials(for space: Space?) -> [SpaceTab] {
        let synced = account.snapshot.spaces
        let base = space.map { synced.essentials(for: $0) } ?? synced.allEssentials
        return base + local.essentials.map { $0.tab(essential: true) }
    }

    var allEssentials: [SpaceTab] {
        account.snapshot.spaces.allEssentials + local.essentials.map { $0.tab(essential: true) }
    }

    func isLocal(_ id: String) -> Bool {
        id.hasPrefix(LocalSpace.prefix)
    }

    func localSpace(_ id: String) -> LocalSpace? {
        local.spaces.first { $0.id == id }
    }

    func save(_ space: LocalSpace) {
        if let index = local.spaces.firstIndex(where: { $0.id == space.id }) {
            local.spaces[index] = space
        } else {
            local.spaces.append(space)
        }
        persist()
    }

    func delete(space id: String) {
        local.spaces.removeAll { $0.id == id }
        local.pins[id] = nil
        persist()
    }

    // Pins a site into a space unless already there; returns false for a repeat.
    @discardableResult
    func pin(_ url: URL, title: String, in spaceID: String) -> Bool {
        let present = spaces.first { $0.id == spaceID }.map { Self.urls(in: $0.items) } ?? []
        guard !present.contains(url) else { return false }
        local.pins[spaceID, default: []].append(LocalPin(url: url, title: title))
        persist()
        return true
    }

    @discardableResult
    func addEssential(_ url: URL, title: String) -> Bool {
        guard !allEssentials.contains(where: { $0.url == url }) else { return false }
        local.essentials.append(LocalPin(url: url, title: title))
        persist()
        return true
    }

    func remove(pin id: String) {
        for key in local.pins.keys {
            local.pins[key]?.removeAll { $0.id == id }
        }
        local.essentials.removeAll { $0.id == id }
        persist()
    }

    // Moves a phone Essential one slot over.
    func moveEssential(_ id: String, by offset: Int) {
        guard let index = local.essentials.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard local.essentials.indices.contains(target) else { return }
        local.essentials.swapAt(index, target)
        persist()
    }

    private func pins(in spaceID: String) -> [SpaceItem] {
        (local.pins[spaceID] ?? []).map { .tab($0.tab(essential: false)) }
    }

    private func persist() {
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(local).write(to: file, options: .atomic)
    }

    private static func load(_ file: URL) -> LocalLibrary? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(LocalLibrary.self, from: data)
    }

    private static func urls(in items: [SpaceItem]) -> Set<URL> {
        items.reduce(into: Set<URL>()) { result, item in
            switch item {
            case .tab(let tab): result.insert(tab.url)
            case .folder(let folder): result.formUnion(urls(in: folder.items))
            }
        }
    }
}
