import FirefoxSyncKit
import SwiftUI

// Safari-style bottom bar: back, address capsule and a tabs button on glass.
struct BottomBar: View {
    let tab: BrowserTab
    var tabCount = 1
    var onAddress: () -> Void = {}
    var onTabs: () -> Void = {}
    var onEssentials: () -> Void = {}
    var onStep: (Int) -> Void = { _ in }
    var onAccount: () -> Void = {}
    var onNewTab: () -> Void = {}
    var spaces: [Space] = []
    var onPin: (String) -> Void = { _ in }
    var onEssential: () -> Void = {}
    @Namespace private var glass
    @State private var drag: CGFloat = 0

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                if tab.canGoBack {
                    Button("Back", systemImage: "chevron.backward") { tab.webView.goBack() }
                        .labelStyle(.iconOnly)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("back", in: glass)
                }
                capsule
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("address", in: glass)
                    .offset(x: drag * 0.35)
                    .gesture(swipe)
                Menu {
                    Button("New Tab", systemImage: "plus", action: onNewTab)
                    if !tab.isBlank {
                        pinActions
                    }
                    Button("Essentials", systemImage: "square.grid.2x2", action: onEssentials)
                    Button("Account and Sync", systemImage: "person.crop.circle", action: onAccount)
                } label: {
                    Text("\(tabCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 24, height: 24)
                        .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(.primary, lineWidth: 1.8) }
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("tabs", in: glass)
                } primaryAction: {
                    onTabs()
                }
            }
            .font(.system(size: 17, weight: .medium))
            .tint(.primary)
            .animation(.snappy, value: tab.canGoBack)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var capsule: some View {
        HStack(spacing: 8) {
            Image(systemName: tab.isBlank ? "magnifyingglass" : (tab.pinnedURL == nil ? "lock.fill" : "pin.fill"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(tab.isBlank ? "Search or enter address" : AddressResolver.display(tab.url))
                .foregroundStyle(tab.isBlank ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            if !tab.isBlank {
                Button(tab.isLoading ? "Stop" : "Reload", systemImage: tab.isLoading ? "xmark" : "arrow.clockwise") {
                    tab.isLoading ? tab.webView.stopLoading() : tab.reload()
                }
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .contentShape(.capsule)
        .onTapGesture(perform: onAddress)
        .contextMenu {
            if !tab.isBlank {
                pinActions
                Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = tab.url }
            }
        }
        .overlay(alignment: .bottom) {
            if tab.isLoading {
                Capsule().fill(.tint).frame(height: 2).scaleEffect(x: max(0.05, tab.progress), anchor: .leading).padding(.horizontal, 18)
            }
        }
    }

    // Pins the current page into a chosen space or into Essentials.
    @ViewBuilder private var pinActions: some View {
        Menu("Pin to Space", systemImage: "pin") {
            ForEach(spaces) { space in
                Button(space.name) { onPin(space.id) }
            }
        }
        .disabled(spaces.isEmpty)
        Button("Add to Essentials", systemImage: "square.grid.2x2", action: onEssential)
    }

    // Swipe on the capsule: sideways flips tabs, up opens the overview.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { drag = abs($0.translation.width) > abs($0.translation.height) ? $0.translation.width : 0 }
            .onEnded { value in
                let side = value.translation.width
                withAnimation(.snappy) { drag = 0 }
                if value.translation.height < -40, abs(side) < 60 {
                    onTabs()
                } else if abs(side) > 60 {
                    onStep(side < 0 ? 1 : -1)
                }
            }
    }
}

#Preview("Page open") {
    let tab = BrowserTab(url: URL(string: "https://news.example.com/")!, title: "News")
    ZStack(alignment: .bottom) {
        SpaceBackground(theme: PreviewData.homeTheme)
        BottomBar(tab: tab, tabCount: 4)
    }
}

#Preview("Blank tab, dark") {
    ZStack(alignment: .bottom) {
        SpaceBackground(theme: PreviewData.tripleTheme)
        BottomBar(tab: BrowserTab(), tabCount: 1)
    }
    .preferredColorScheme(.dark)
}

#Preview("Pinned, loading") {
    let tab: BrowserTab = {
        let tab = BrowserTab(url: URL(string: "https://mail.example.com/")!, pinnedURL: URL(string: "https://mail.example.com/"))
        tab.isLoading = true
        tab.progress = 0.6
        tab.canGoBack = true
        return tab
    }()
    ZStack(alignment: .bottom) {
        SpaceBackground(theme: PreviewData.workTheme)
        BottomBar(tab: tab, tabCount: 12)
    }
}
