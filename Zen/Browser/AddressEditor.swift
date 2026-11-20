import FirefoxSyncKit
import SwiftUI

// Address entry: field above the keyboard, suggestions from Essentials and other devices above it.
struct AddressEditor: View {
    let initial: String
    var essentials: [SpaceTab] = []
    var remote: [RemoteTab] = []
    let onSubmit: (URL) -> Void
    let onCancel: () -> Void
    @State private var text = ""
    @State private var selection: TextSelection?
    @FocusState private var focused: Bool

    private var matches: [RemoteTab] {
        let query = text.lowercased()
        guard !query.isEmpty, query != initial.lowercased() else { return Array(remote.prefix(6)) }
        return remote.filter { $0.title.lowercased().contains(query) || $0.url.absoluteString.lowercased().contains(query) }.prefix(8).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !essentials.isEmpty {
                    EssentialsGrid(tabs: essentials) { onSubmit($0.url) }
                }
                if !matches.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(matches) { tab in
                            SiteRow(url: tab.url, title: tab.title) { onSubmit(tab.url) }
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Rectangle().fill(.regularMaterial).ignoresSafeArea() }
        .safeAreaBar(edge: .bottom) { field }
        .onAppear {
            text = initial
            selection = TextSelection(range: text.startIndex..<text.endIndex)
            focused = true
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or enter address", text: $text, selection: $selection)
                    .focused($focused)
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { AddressResolver.url(for: text).map(onSubmit) }
                if !text.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .glassEffect(.regular, in: .capsule)
            Button("Cancel", systemImage: "xmark", action: onCancel)
                .labelStyle(.iconOnly)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .tint(.primary)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

#Preview("With suggestions") {
    AddressEditor(initial: "news.example.com", essentials: PreviewData.essentials, remote: PreviewData.devices.flatMap(\.tabs), onSubmit: { _ in }, onCancel: {})
}

#Preview("Empty") {
    AddressEditor(initial: "", onSubmit: { _ in }, onCancel: {})
        .preferredColorScheme(.dark)
}
