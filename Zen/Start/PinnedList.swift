import FirefoxSyncKit
import SwiftUI

// Row for a tab from a space or another device.
struct SiteRow: View {
    let url: URL
    let title: String
    var iconDataURL: String?
    var badge: String?
    var isLive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                FaviconView(url: url, dataURL: iconDataURL, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body).lineLimit(1)
                    Text(AddressResolver.display(url)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if isLive {
                    Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                }
                if let badge {
                    Image(systemName: badge).font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// Pinned tabs of a space, with folders that expand in place.
struct PinnedList: View {
    let items: [SpaceItem]
    var markLocal = false
    var liveURLs: Set<URL> = []
    var onRemove: ((SpaceTab) -> Void)?
    let open: (SpaceTab) -> Void
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                row(item, depth: 0)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func row(_ item: SpaceItem, depth: CGFloat) -> AnyView {
        switch item {
        case .tab(let tab):
            let isLocal = tab.id.hasPrefix(LocalSpace.prefix)
            return AnyView(
                SiteRow(url: tab.url, title: tab.title, iconDataURL: tab.iconDataURL, badge: markLocal && isLocal ? "iphone" : nil, isLive: liveURLs.contains(tab.url)) { open(tab) }
                    .padding(.leading, depth * 18)
                    .contextMenu {
                        if isLocal, let onRemove {
                            Button("Unpin", systemImage: "pin.slash", role: .destructive) { onRemove(tab) }
                        } else if !isLocal {
                            Text("From Zen, edit it on desktop")
                        }
                        Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = tab.url }
                    }
            )
        case .folder(let folder):
            let isOpen = expanded.contains(folder.id)
            return AnyView(VStack(spacing: 0) {
                Button {
                    withAnimation(.snappy) { _ = isOpen ? expanded.remove(folder.id) : expanded.insert(folder.id).memberAfterInsert }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isOpen ? "folder.fill" : "folder").frame(width: 24)
                        Text(folder.name.isEmpty ? "Folder" : folder.name)
                        Spacer()
                        Text("\(folder.items.count)").font(.caption).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).rotationEffect(.degrees(isOpen ? 90 : 0)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if isOpen {
                    ForEach(folder.items) { child in
                        row(child, depth: depth + 1)
                    }
                }
            }
            .padding(.leading, depth * 18))
        }
    }
}

#Preview("Pins with a folder") {
    ZStack {
        SpaceBackground(theme: PreviewData.homeTheme)
        PinnedList(items: PreviewData.home.pinned) { _ in }.padding()
    }
}

#Preview("Site row", traits: .sizeThatFitsLayout) {
    SiteRow(url: URL(string: "https://docs.example.com/guide")!, title: "Sync documentation") {}
}
