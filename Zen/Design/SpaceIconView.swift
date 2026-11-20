import FirefoxSyncKit
import SwiftUI

// Space icon: emoji as is, Zen's named icons map to SF Symbols.
struct SpaceIconView: View {
    let icon: SpaceIcon
    var size: CGFloat = 20

    var body: some View {
        switch icon {
        case .emoji(let emoji):
            Text(emoji).font(.system(size: size))
        case .named(let name):
            Image(systemName: Self.symbols[name] ?? "circle.grid.2x2")
                .font(.system(size: size * 0.85, weight: .medium))
        case .none:
            Image(systemName: "circle.fill")
                .font(.system(size: size * 0.4))
        }
    }

    static let symbols: [String: String] = [
        "airplane": "airplane", "bed": "bed.double", "bell": "bell", "book": "book", "bookmark": "bookmark",
        "briefcase": "briefcase", "brush": "paintbrush", "bug": "ladybug", "build": "hammer", "cafe": "cup.and.saucer",
        "call": "phone", "card": "creditcard", "chat": "bubble.left", "checkbox": "checkmark.square", "circle": "circle",
        "cloud": "cloud", "code": "chevron.left.forwardslash.chevron.right", "coins": "dollarsign.circle",
        "construct": "wrench.and.screwdriver", "cutlery": "fork.knife", "extension-puzzle": "puzzlepiece", "eye": "eye",
        "fast-food": "takeoutbag.and.cup.and.straw", "fish": "fish", "flag": "flag", "flame": "flame", "flask": "flask",
        "folder": "folder", "game-controller": "gamecontroller", "globe": "globe", "globe-1": "globe.europe.africa",
        "grid-2x2": "square.grid.2x2", "grid-3x3": "square.grid.3x3", "heart": "heart", "image": "photo", "inbox": "tray",
        "key": "key", "layers": "square.3.layers.3d", "leaf": "leaf", "lightning": "bolt", "location": "location",
        "lock-closed": "lock", "mail": "envelope", "map": "map", "megaphone": "megaphone", "moon": "moon",
        "music": "music.note", "navigate": "location.north", "page": "doc", "palette": "paintpalette", "paw": "pawprint",
        "people": "person.2", "planet": "globe.asia.australia", "present": "gift", "rocket": "paperplane",
        "school": "graduationcap", "shapes": "square.on.circle", "shirt": "tshirt", "square": "square", "star": "star",
        "star-1": "star.fill", "stats-chart": "chart.bar", "sun": "sun.max", "tada": "party.popper", "terminal": "terminal",
        "ticket": "ticket", "time": "clock", "trash": "trash", "triangle": "triangle", "video": "video",
        "volume-high": "speaker.wave.3", "wallet": "wallet.bifold", "warning": "exclamationmark.triangle", "water": "drop",
        "weight": "dumbbell",
    ]
}

#Preview {
    HStack(spacing: 20) {
        SpaceIconView(icon: .emoji("🏠"))
        SpaceIconView(icon: .named("briefcase"))
        SpaceIconView(icon: .named("code"), size: 32)
        SpaceIconView(icon: .none)
    }
    .padding()
}
