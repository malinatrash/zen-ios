import FirefoxSyncKit
import SwiftUI

// Space editor: name, icon, up to three gradient colors and intensity.
struct SpaceEditor: View {
    @State var draft: LocalSpace
    var isNew = true
    let onSave: (LocalSpace) -> Void
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.self) private var environment
    @State private var iconKind = IconKind.emoji
    @State private var custom = Color.orange
    @FocusState private var nameFocused: Bool

    enum IconKind: String, CaseIterable {
        case emoji = "Emoji"
        case symbol = "Symbols"
    }

    static let emojis = ["🏠", "💼", "🎨", "📚", "🎵", "🎮", "🛒", "✈️", "💡", "🔬", "🧘", "🍿", "💰", "❤️", "🌱", "⚡️", "🚀", "🧩", "📷", "🍕", "⭐️", "🔥", "🐾", "🌙"]

    static let symbols = ["briefcase", "code", "book", "music", "game-controller", "globe", "heart", "star", "terminal", "palette", "rocket", "leaf", "cafe", "mail", "chat", "wallet", "airplane", "flask", "folder", "people", "moon", "sun", "lightning", "stats-chart"]

    static let palette: [[Double]] = [
        [244, 93, 74], [246, 166, 35], [240, 210, 80], [86, 190, 120], [52, 168, 140], [64, 132, 214],
        [120, 96, 220], [200, 90, 200], [236, 120, 160], [150, 150, 160], [40, 40, 48],
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    card("Icon") { iconPicker }
                    card("Colors") { colorPicker }
                    if let onDelete {
                        Button("Delete Space", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { SpaceBackground(theme: draft.theme) }
            .animation(.smooth, value: draft.colors)
            .navigationTitle(isNew ? "New Space" : "Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                iconKind = draft.icon.hasPrefix("chrome://") ? .symbol : .emoji
                nameFocused = isNew
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            SpaceIconView(icon: SpaceIcon(raw: draft.icon), size: 40)
                .frame(width: 84, height: 84)
                .glassEffect(.regular, in: .circle)
            TextField("Name", text: $draft.name)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .focused($nameFocused)
                .submitLabel(.done)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
        }
        .padding(.top, 8)
    }

    private var iconPicker: some View {
        VStack(spacing: 12) {
            Picker("Kind", selection: $iconKind) {
                ForEach(IconKind.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                let options = iconKind == .emoji ? Self.emojis : Self.symbols.map(LocalSpace.symbolIcon)
                ForEach(options, id: \.self) { raw in
                    Button {
                        draft.icon = raw
                    } label: {
                        SpaceIconView(icon: SpaceIcon(raw: raw), size: 22)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(draft.icon == raw ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: draft.icon)
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(Self.palette, id: \.self) { rgb in
                    swatch(rgb)
                }
                ColorPicker("Custom color", selection: $custom, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 40, height: 40)
            }
            Text(draft.colors.isEmpty ? "No color: neutral background" : "The first color is primary, up to three")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
                Slider(value: $draft.opacity, in: 0.3...0.8)
                Image(systemName: "circle.fill").foregroundStyle(.secondary)
            }
            .disabled(draft.colors.isEmpty)
        }
        .onChange(of: custom) { _, color in
            let resolved = color.resolve(in: environment)
            toggle([Double(resolved.red * 255).rounded(), Double(resolved.green * 255).rounded(), Double(resolved.blue * 255).rounded()])
        }
    }

    private func swatch(_ rgb: [Double]) -> some View {
        let order = draft.colors.firstIndex(of: rgb)
        return Button {
            toggle(rgb)
        } label: {
            Circle()
                .fill(Color(RGB(rgb[0], rgb[1], rgb[2])))
                .frame(width: 40, height: 40)
                .overlay {
                    if let order {
                        Text("\(order + 1)").font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
                }
                .overlay { Circle().strokeBorder(.white.opacity(order == nil ? 0 : 0.9), lineWidth: 3) }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: order)
    }

    // Tapping a selected color removes it, otherwise adds it; a fourth replaces the last.
    private func toggle(_ rgb: [Double]) {
        if let index = draft.colors.firstIndex(of: rgb) {
            draft.colors.remove(at: index)
        } else if draft.colors.count < 3 {
            draft.colors.append(rgb)
        } else {
            draft.colors[2] = rgb
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

#Preview("New") {
    SpaceEditor(draft: LocalSpace(name: "", icon: "🚀"), onSave: { _ in })
}

#Preview("Editing, three colors") {
    SpaceEditor(
        draft: LocalSpace(name: "Study", icon: LocalSpace.symbolIcon("book"), colors: [[52, 168, 140], [64, 132, 214], [200, 90, 200]], opacity: 0.7),
        isNew: false,
        onSave: { _ in },
        onDelete: {}
    )
}

#Preview("Dark") {
    SpaceEditor(draft: LocalSpace(name: "Music", icon: "🎵", colors: [[246, 166, 35]]), onSave: { _ in })
        .preferredColorScheme(.dark)
}
