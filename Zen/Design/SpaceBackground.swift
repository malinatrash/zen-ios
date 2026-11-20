import FirefoxSyncKit
import SwiftUI

extension Color {
    init(_ rgb: RGB) {
        self.init(red: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255)
    }
}

// Space background: the same gradient Zen draws on desktop.
struct SpaceBackground: View {
    let theme: SpaceTheme?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let paint = (theme ?? SpaceTheme()).paint(dark: scheme == .dark)
        ZStack {
            if paint.stops.count == 1 {
                Color(paint.stops[0])
            } else {
                LinearGradient(
                    colors: paint.stops.map(Color.init),
                    startPoint: paint.isDiagonal ? .topLeading : .bottomLeading,
                    endPoint: paint.isDiagonal ? .bottomTrailing : .topTrailing
                )
            }
            if let overlay = paint.overlay {
                LinearGradient(colors: [.clear, Color(overlay).opacity(paint.overlayMaxAlpha)], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Two colors") {
    SpaceBackground(theme: PreviewData.homeTheme)
}

#Preview("Three colors, dark") {
    SpaceBackground(theme: PreviewData.tripleTheme)
        .preferredColorScheme(.dark)
}

#Preview("No theme") {
    SpaceBackground(theme: nil)
}
