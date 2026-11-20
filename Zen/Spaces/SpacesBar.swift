import FirefoxSyncKit
import SwiftUI

// Space switcher with create, edit and delete for the phone's own spaces.
struct SpacesBar: View {
    let spaces: SpacesModel
    let browser: BrowserModel
    @State private var editing: LocalSpace?
    @State private var pendingDelete: Space?

    private var currentID: String? {
        let all = spaces.spaces
        return (all.first { $0.id == browser.selectedSpaceID } ?? all.first)?.id
    }

    var body: some View {
        SpaceSwitcher(
            spaces: spaces.spaces,
            selection: Binding(get: { currentID }, set: { browser.selectedSpaceID = $0 }),
            isEditable: { spaces.localSpace($0.id) != nil },
            onAdd: { editing = LocalSpace(name: "", icon: SpaceEditor.emojis.randomElement() ?? "🏠") },
            onEdit: { editing = spaces.localSpace($0.id) },
            onDelete: { pendingDelete = $0 }
        )
        .sheet(item: $editing) { draft in
            let exists = spaces.localSpace(draft.id) != nil
            SpaceEditor(
                draft: draft,
                isNew: !exists,
                onSave: { saved in
                    spaces.save(saved)
                    browser.selectedSpaceID = saved.id
                },
                onDelete: exists ? { spaces.delete(space: draft.id) } : nil
            )
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete with pins", role: .destructive) {
                if let pendingDelete { spaces.delete(space: pendingDelete.id) }
            }
        } message: {
            Text("Open tabs stay; only this space's pins are removed.")
        }
    }
}

#Preview {
    let models = PreviewData.models()
    ZStack(alignment: .top) {
        SpaceBackground(theme: PreviewData.homeTheme)
        SpacesBar(spaces: models.spaces, browser: PreviewData.browser)
    }
}
