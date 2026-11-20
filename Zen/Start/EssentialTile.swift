import FirefoxSyncKit
import SwiftUI

// Essentials tile: just an icon on glass, like Zen's sidebar.
struct EssentialTile: View {
    let tab: SpaceTab
    var isLive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FaviconView(url: tab.url, dataURL: tab.iconDataURL, size: 30)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .overlay(alignment: .bottom) {
                    if isLive {
                        Circle().fill(.primary.opacity(0.7)).frame(width: 5, height: 5).padding(.bottom, 6)
                    }
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

// Four-column Essentials grid shared by the start page and the tray above the bar.
struct EssentialsGrid: View {
    let tabs: [SpaceTab]
    var liveURLs: Set<URL> = []
    var onRemove: ((SpaceTab) -> Void)?
    var onMove: ((SpaceTab, Int) -> Void)?
    let open: (SpaceTab) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(tabs) { tab in
                    EssentialTile(tab: tab, isLive: liveURLs.contains(tab.url)) { open(tab) }
                        .contextMenu { menu(for: tab) }
                }
            }
        }
    }
}

// Phone Essentials can be moved and removed; the ones from Zen change only on desktop.
extension EssentialsGrid {
    @ViewBuilder func menu(for tab: SpaceTab) -> some View {
        Text(tab.title)
        if tab.id.hasPrefix(LocalSpace.prefix) {
            if let onMove {
                Button("Move Left", systemImage: "arrow.left") { onMove(tab, -1) }
                Button("Move Right", systemImage: "arrow.right") { onMove(tab, 1) }
            }
            if let onRemove {
                Button("Remove from Essentials", systemImage: "pin.slash", role: .destructive) { onRemove(tab) }
            }
        } else {
            Text("From Zen, edit it on desktop")
        }
        Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = tab.url }
    }
}

#Preview("Grid on space background") {
    ZStack {
        SpaceBackground(theme: PreviewData.homeTheme)
        EssentialsGrid(tabs: PreviewData.essentials, liveURLs: [PreviewData.essentials[0].url]) { _ in }
            .padding()
    }
}

#Preview("Single tile", traits: .sizeThatFitsLayout) {
    EssentialTile(tab: PreviewData.essentials[1], isLive: true) {}
        .frame(width: 84)
        .padding()
}
