import FirefoxSyncKit
import SwiftUI

// Tabs overview: spaces on top, then Essentials, pins and one list of phone and Zen tabs.
struct TabsOverview: View {
    let browser: BrowserModel
    let spaces: SpacesModel
    var isSignedIn = false
    let onDone: () -> Void

    private var current: Space? {
        let all = spaces.spaces
        return all.first { $0.id == browser.selectedSpaceID } ?? all.first
    }

    var body: some View {
        let all = spaces.spaces
        Group {
            if all.isEmpty {
                page(nil)
            } else {
                TabView(selection: Binding(get: { current?.id ?? "" }, set: { browser.selectedSpaceID = $0 })) {
                    ForEach(all) { space in
                        page(space).tag(space.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background { SpaceBackground(theme: current?.theme) }
        .animation(.smooth, value: current?.id)
        .safeAreaBar(edge: .top) {
            SpacesBar(spaces: spaces, browser: browser).padding(.top, 4)
        }
        .safeAreaBar(edge: .bottom) { bottomBar }
    }

    private func page(_ space: Space?) -> some View {
        let essentials = spaces.essentials(for: space)
        let live = Set(browser.tabs.compactMap(\.pinnedURL))
        let entries = browser.entries(in: space)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !essentials.isEmpty {
                    EssentialsGrid(
                        tabs: essentials,
                        liveURLs: live,
                        onRemove: { spaces.remove(pin: $0.id) },
                        onMove: { spaces.moveEssential($0.id, by: $1) }
                    ) { launch($0.url, in: space, essential: true) }
                }
                if let space, !space.pinned.isEmpty {
                    section("Pinned") {
                        PinnedList(items: space.pinned, markLocal: spaces.localSpace(space.id) == nil, liveURLs: live, onRemove: { spaces.remove(pin: $0.id) }) {
                            launch($0.url, in: space, pinned: true)
                        }
                    }
                }
                section(entries.isEmpty ? "No open tabs" : "Tabs · \(entries.count)") {
                    if !entries.isEmpty {
                        SpaceTabList(entries: entries, selectedID: browser.selectedID) { entry in
                            browser.open(entry, in: space)
                            onDone()
                        } onClose: { entry in
                            browser.close(entry)
                        }
                    }
                }
                if isSignedIn, let space, spaces.localSpace(space.id) != nil {
                    Hint("This space lives only on the phone, so its tabs reach Zen only under Synced Tabs. Create the space in Zen to share tabs both ways.")
                }
            }
            .padding(16)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private var bottomBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button("New Tab", systemImage: "plus") {
                    browser.newTab()
                    onDone()
                }
                .labelStyle(.iconOnly)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive(), in: .circle)
                HStack(spacing: 6) {
                    if let current {
                        SpaceIconView(icon: current.icon, size: 16)
                    }
                    Text(current?.name ?? "Tabs").lineLimit(1)
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .glassEffect(.regular, in: .capsule)
                Button("Done", action: done)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .tint(.primary)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 6)
            content()
        }
    }

    private func launch(_ url: URL, in space: Space?, pinned: Bool = false, essential: Bool = false) {
        browser.selectedSpaceID = space?.id ?? browser.selectedSpaceID
        browser.open(url, pinned: pinned, essential: essential)
        onDone()
    }

    // If the current tab belongs to another space, jumps to the last tab of the shown one.
    private func done() {
        let spaceID = current?.id
        if let tabSpace = browser.selected.spaceID, tabSpace != spaceID {
            if let recent = browser.tabs(in: spaceID).filter({ $0.spaceID == spaceID }).max(by: { $0.lastUsed < $1.lastUsed }) {
                browser.select(recent)
            } else {
                browser.newTab()
            }
        }
        onDone()
    }
}

#Preview("Spaces and pins") {
    let models = PreviewData.models()
    TabsOverview(browser: PreviewData.browser, spaces: models.spaces) {}
}

#Preview("Dark") {
    let models = PreviewData.models()
    TabsOverview(browser: PreviewData.browser, spaces: models.spaces) {}
        .preferredColorScheme(.dark)
}

#Preview("Signed out") {
    let account = AccountModel.signedOutPreview
    TabsOverview(browser: BrowserModel(tabs: [BrowserTab()]), spaces: SpacesModel(account: account, library: SpacesModel.starter)) {}
}
