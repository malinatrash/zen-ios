import FirefoxSyncKit
import SwiftUI

// Start page: spaces, Essentials, pins, one list of phone and Zen tabs, and other browsers' tabs.
struct StartPage: View {
    let account: AccountModel
    let spaces: SpacesModel
    let browser: BrowserModel
    var onSignIn: () -> Void = {}

    private var space: Space? {
        let all = spaces.spaces
        return all.first { $0.id == browser.selectedSpaceID } ?? all.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SpacesBar(spaces: spaces, browser: browser)
                .padding(.horizontal, -16)
                let essentials = spaces.essentials(for: space)
                if !essentials.isEmpty {
                    EssentialsGrid(
                        tabs: essentials,
                        liveURLs: Set(browser.tabs.filter(\.isLive).compactMap(\.pinnedURL)),
                        onRemove: { spaces.remove(pin: $0.id) },
                        onMove: { spaces.moveEssential($0.id, by: $1) }
                    ) { browser.open($0.url, essential: true) }
                }
                if let space, !space.pinned.isEmpty {
                    section("Pinned") {
                        PinnedList(items: space.pinned, markLocal: spaces.localSpace(space.id) == nil, liveURLs: Set(browser.tabs.compactMap(\.pinnedURL)), onRemove: { spaces.remove(pin: $0.id) }) {
                            browser.open($0.url, pinned: true)
                        }
                    }
                }
                let entries = browser.entries(in: space)
                if !entries.isEmpty {
                    section("Tabs") {
                        SpaceTabList(entries: entries, selectedID: browser.selectedID) { browser.open($0, in: space) } onClose: { browser.close($0) }
                    }
                }
                if essentials.isEmpty, space?.pinned.isEmpty ?? true {
                    Hint("To pin a site, open it and long-press the address bar, then choose Pin to Space or Add to Essentials.", systemImage: "pin")
                }
                ForEach(otherDevices) { device in
                    section(device.name) { rows(device.tabs.prefix(8).map { ($0.url, $0.title, nil) }) }
                }
                status
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .refreshable { await account.refresh() }
        .background { SpaceBackground(theme: space?.theme) }
        .animation(.smooth, value: space?.id)
    }

    // Zen desktops already show up through spaces; their tabs record would only repeat the list above.
    private var otherDevices: [RemoteDevice] {
        let viaSpaces = account.snapshot.spacesState == .available
        return account.snapshot.devices.filter { !(viaSpaces && $0.application == "Zen") }
    }

    // Normal tabs only travel when Zen has the flag on; open tabs in any space prove it is.
    private var normalTabsOff: Bool {
        let snapshot = account.snapshot
        guard snapshot.spacesState == .available, snapshot.desktopNormalTabs != true else { return false }
        return snapshot.desktopNormalTabs == false || snapshot.spaces.spaces.allSatisfy { $0.openTabs.isEmpty }
    }

    @ViewBuilder private var status: some View {
        if !account.isSignedIn {
            signInCard
        } else if !account.hasSynced {
            ProgressView().frame(maxWidth: .infinity)
        } else if account.snapshot.spacesState == .notEnabled {
            Hint("To see your spaces and Essentials from Zen, turn on Settings → Sync → Sync your Spaces across devices in Zen on desktop.", systemImage: "gearshape")
        } else if case .unsupportedVersion(let version) = account.snapshot.spacesState {
            Hint("Zen moved spaces to format version \(version), which this app does not understand yet.", systemImage: "exclamationmark.triangle")
        } else if normalTabsOff {
            Hint("To sync open tabs with Zen both ways, set zen.spaces-sync.normal-tabs to true in about:config on desktop. Until then only pinned tabs and Essentials travel.", systemImage: "gearshape")
        }
        if case .failed(let message) = account.phase {
            Hint(message, systemImage: "exclamationmark.triangle")
        } else if account.phase == .needsLogin {
            signInCard
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 6)
            content()
        }
    }

    private func rows(_ sites: [(URL, String, String?)]) -> some View {
        VStack(spacing: 0) {
            ForEach(sites, id: \.0) { site in
                SiteRow(url: site.0, title: site.1, iconDataURL: site.2) { browser.open(site.0) }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(account.phase == .needsLogin ? "Sign in again" : "Pull in from Zen").font(.headline)
            Text("Sign in to your Firefox account to get your spaces, Essentials and desktop tabs here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Sign In", action: onSignIn).buttonStyle(.glassProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

#Preview("Zen and phone") {
    let models = PreviewData.models()
    StartPage(account: models.account, spaces: models.spaces, browser: PreviewData.browser)
}

#Preview("Dark theme") {
    let models = PreviewData.models()
    StartPage(account: models.account, spaces: models.spaces, browser: PreviewData.browser)
        .preferredColorScheme(.dark)
}

#Preview("Signed out, own spaces") {
    let models = PreviewData.models(signedIn: false)
    StartPage(account: models.account, spaces: models.spaces, browser: PreviewData.browser)
}

#Preview("First launch") {
    let account = AccountModel.signedOutPreview
    StartPage(account: account, spaces: SpacesModel(account: account, library: SpacesModel.starter), browser: BrowserModel(tabs: [BrowserTab()]))
}
