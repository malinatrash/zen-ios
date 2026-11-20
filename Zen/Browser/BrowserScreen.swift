import FirefoxSyncKit
import SwiftUI

// Main screen: page or start page under the bottom bar, with the tabs overview and address entry on top.
struct BrowserScreen: View {
    let browser: BrowserModel
    let account: AccountModel
    let spaces: SpacesModel
    @State private var isEditing = false
    @State private var toast: String?
    @State private var showsTabs = false
    @State private var showsEssentials = false
    @State private var showsAccount = false
    @State private var showsLogin = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let tab = browser.selected
        ZStack {
            if tab.isBlank {
                StartPage(account: account, spaces: spaces, browser: browser) { showsLogin = true }
            } else {
                WebContainer(tab: tab).ignoresSafeArea(edges: .bottom)
            }
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 10) {
                if showsEssentials {
                    EssentialsGrid(tabs: spaces.essentials(for: currentSpace)) {
                        browser.open($0.url, essential: true)
                        showsEssentials = false
                    }
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                BottomBar(
                    tab: tab,
                    tabCount: browser.tabs.count,
                    onAddress: { isEditing = true },
                    onTabs: openTabs,
                    onEssentials: { withAnimation(.snappy) { showsEssentials.toggle() } },
                    onStep: { offset in withAnimation(.snappy) { browser.step(offset) } },
                    onAccount: { showsAccount = true },
                    onNewTab: { browser.newTab() },
                    spaces: spaces.spaces,
                    onPin: { pin(tab, in: $0) },
                    onEssential: { addEssential(tab) }
                )
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                Label(toast, systemImage: "pin.fill")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: toast) { _, new in new != nil }
        .fullScreenCover(isPresented: $isEditing) {
            AddressEditor(
                initial: tab.url?.absoluteString ?? "",
                essentials: spaces.essentials(for: currentSpace),
                remote: account.snapshot.devices.flatMap(\.tabs),
                onSubmit: { url in
                    tab.load(url)
                    browser.save()
                    isEditing = false
                },
                onCancel: { isEditing = false }
            )
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showsTabs) {
            TabsOverview(browser: browser, spaces: spaces, isSignedIn: account.isSignedIn) { showsTabs = false }
        }
        .sheet(isPresented: $showsAccount) {
            AccountSheet(account: account) { showsLogin = true }
        }
        .sheet(isPresented: $showsLogin) {
            LoginSheet(account: account)
        }
        .task {
            browser.adopt(into: spaces.spaces.first?.id)
            await account.refresh()
        }
        .task(id: browser.syncSignature + [account.isSignedIn ? "in" : "out", "\(browser.revision)"]) {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await publish()
        }
        .onChange(of: account.snapshot.spaceTombstones) { _, tombstones in
            browser.closeRemoved(tombstones)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await account.refresh() }
            } else {
                browser.save()
                Task { await publish() }
            }
        }
    }

    // Tabs go to the tabs collection for every browser, and into Zen spaces when the tab sits in a Zen space.
    private func publish() async {
        await account.publish(browser.localTabs)
        let zenSpaces = Set(account.snapshot.spaces.spaces.map(\.id))
        let plan = browser.mirrorPlan { zenSpaces.contains($0) }
        guard !plan.changed.isEmpty || !plan.removed.isEmpty else { return }
        if await account.mirror(plan.changed, removed: plan.removed) {
            browser.confirmMirror(plan.next)
            await account.refresh()
        }
    }

    private var currentSpace: Space? {
        spaces.spaces.first { $0.id == browser.selectedSpaceID } ?? spaces.spaces.first
    }

    private func pin(_ tab: BrowserTab, in spaceID: String) {
        guard let url = tab.url else { return }
        let name = spaces.spaces.first { $0.id == spaceID }?.name ?? ""
        let added = spaces.pin(url, title: tab.title, in: spaceID)
        tab.pinnedURL = url
        browser.selectedSpaceID = spaceID
        browser.save()
        show(added ? "Pinned to “\(name)”" : "Already in “\(name)”")
    }

    private func addEssential(_ tab: BrowserTab) {
        guard let url = tab.url else { return }
        let added = spaces.addEssential(url, title: tab.title)
        tab.pinnedURL = url
        browser.save()
        show(added ? "Added to Essentials" : "Already in Essentials")
    }

    private func show(_ text: String) {
        withAnimation(.snappy) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { if toast == text { toast = nil } }
        }
    }

    private func openTabs() {
        showsTabs = true
    }
}

#Preview("Start page with Zen data") {
    let models = PreviewData.models()
    BrowserScreen(browser: PreviewData.browser, account: models.account, spaces: models.spaces)
}

#Preview("Signed out, dark") {
    let account = AccountModel.signedOutPreview
    BrowserScreen(browser: BrowserModel(tabs: [BrowserTab()]), account: account, spaces: SpacesModel(account: account, library: SpacesModel.starter))
        .preferredColorScheme(.dark)
}
