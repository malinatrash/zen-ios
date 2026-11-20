import FirefoxSyncKit
import SwiftUI

// Space switcher: icons in a row, the selected one expands with its name, plus at the end.
struct SpaceSwitcher: View {
    let spaces: [Space]
    @Binding var selection: String?
    var isEditable: (Space) -> Bool = { _ in false }
    var onAdd: (() -> Void)?
    var onEdit: ((Space) -> Void)?
    var onDelete: ((Space) -> Void)?
    @Namespace private var glass

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(spaces) { space in
                        chip(space)
                    }
                    if let onAdd {
                        Button("New Space", systemImage: "plus", action: onAdd)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .glassEffectID("add", in: glass)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
        .scrollIndicators(.hidden)
        .tint(.primary)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(_ space: Space) -> some View {
        let isSelected = space.id == selection
        return Button {
            withAnimation(.snappy) { selection = space.id }
        } label: {
            HStack(spacing: 6) {
                SpaceIconView(icon: space.icon, size: 18)
                if isSelected {
                    Text(space.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
            }
            .padding(.horizontal, isSelected ? 14 : 0)
            .frame(minWidth: 40, minHeight: 40)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID(space.id, in: glass)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(space.name)
        .contextMenu {
            if isEditable(space) {
                if let onEdit {
                    Button("Edit", systemImage: "pencil") { onEdit(space) }
                }
                if let onDelete {
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(space) }
                }
            } else {
                Text("Space from Zen, edit it on desktop")
            }
        }
    }
}

#Preview("From Zen and phone") {
    @Previewable @State var selection: String? = "{home}"
    let spaces = [PreviewData.home, PreviewData.work, Space(id: "local-1", name: "Study", icon: .emoji("📚"))]
    ZStack {
        SpaceBackground(theme: spaces.first { $0.id == selection }?.theme)
        SpaceSwitcher(spaces: spaces, selection: $selection, isEditable: { $0.id.hasPrefix("local-") }, onAdd: {}, onEdit: { _ in }, onDelete: { _ in })
    }
}

#Preview("Plus only") {
    @Previewable @State var selection: String?
    SpaceSwitcher(spaces: [], selection: $selection, onAdd: {})
}
