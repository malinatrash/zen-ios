import SwiftUI

// Glass note for anything that needs an action outside the app.
struct Hint: View {
    let text: String
    var systemImage = "lightbulb"

    init(_ text: String, systemImage: String = "lightbulb") {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.tint)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

#Preview {
    VStack(spacing: 12) {
        Hint("To sync open tabs with Zen, set zen.spaces-sync.normal-tabs to true in about:config on desktop.", systemImage: "gearshape")
        Hint("Long-press the address bar to pin a site.")
    }
    .padding()
}
