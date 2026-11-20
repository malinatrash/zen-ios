import FirefoxSyncKit
import SwiftUI

// A space's tabs from the phone and from Zen in one list, like Zen's sidebar.
struct SpaceTabList: View {
    let entries: [TabEntry]
    var selectedID: UUID?
    let onOpen: (TabEntry) -> Void
    let onClose: (TabEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                row(entry)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .animation(.snappy, value: entries.map(\.id))
    }

    private func row(_ entry: TabEntry) -> some View {
        let isSelected: Bool = if case .phone(let tab) = entry { tab.id == selectedID } else { false }
        return HStack(spacing: 12) {
            FaviconView(url: entry.url, dataURL: entry.iconDataURL, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title).font(.body).lineLimit(1)
                Text(AddressResolver.display(entry.url)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            status(entry)
            Button("Close Tab", systemImage: "xmark") { onClose(entry) }
                .labelStyle(.iconOnly)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.14) : .clear)
        .contentShape(.rect)
        .onTapGesture { onOpen(entry) }
        .contextMenu {
            Button("Copy Link", systemImage: "link") { UIPasteboard.general.url = entry.url }
            Button("Close Tab", systemImage: "xmark", role: .destructive) { onClose(entry) }
        }
    }

    // A dot marks a page loaded on the phone; a laptop marks a tab that so far lives only in Zen.
    @ViewBuilder private func status(_ entry: TabEntry) -> some View {
        switch entry {
        case .phone(let tab) where tab.isLive:
            Circle().fill(Color.accentColor).frame(width: 7, height: 7)
        case .zen:
            Image(systemName: "laptopcomputer").font(.caption).foregroundStyle(.tertiary)
        default:
            EmptyView()
        }
    }
}

#Preview("Phone and Zen tabs") {
    let browser = PreviewData.browser
    let entries: [TabEntry] = [
        .zen(PreviewData.tab("github.com", "zen-browser/desktop", pinned: false)),
        .phone(browser.tabs[1]),
        .zen(PreviewData.tab("macrumors.com", "Safari in iOS 26: Everything New", pinned: false)),
        .phone(browser.tabs[2]),
    ]
    ZStack {
        SpaceBackground(theme: PreviewData.homeTheme)
        SpaceTabList(entries: entries, selectedID: browser.tabs[1].id, onOpen: { _ in }, onClose: { _ in })
            .padding()
    }
}

#Preview("Dark") {
    let browser = PreviewData.browser
    SpaceTabList(entries: [.phone(browser.tabs[1]), .zen(PreviewData.tab("google.com", "Search", pinned: false))], onOpen: { _ in }, onClose: { _ in })
        .padding()
        .preferredColorScheme(.dark)
}
