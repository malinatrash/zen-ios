import FirefoxSyncKit
import Foundation

// Everything the user created on the phone: own spaces, pins and Essentials.
struct LocalLibrary: Codable, Equatable {
    var spaces: [LocalSpace] = []
    var pins: [String: [LocalPin]] = [:]
    var essentials: [LocalPin] = []
}

// Phone space: the icon is stored the same way Zen does.
struct LocalSpace: Codable, Equatable, Identifiable {
    var id = LocalSpace.newID()
    var name: String
    var icon: String
    var colors: [[Double]] = []
    var opacity = 0.55

    static let prefix = "local-"

    static func newID() -> String {
        prefix + UUID().uuidString
    }

    static func symbolIcon(_ name: String) -> String {
        "chrome://browser/skin/zen-icons/selectable/\(name).svg"
    }

    var theme: SpaceTheme? {
        let rgbs = colors.filter { $0.count == 3 }
        guard !rgbs.isEmpty else { return nil }
        let gradient = rgbs.enumerated().map { index, c in
            SpaceTheme.GradientColor(rgb: RGB(c[0], c[1], c[2]), isPrimary: index == 0)
        }
        return SpaceTheme(gradientColors: gradient, opacity: opacity)
    }
}

struct LocalPin: Codable, Equatable, Identifiable {
    var id = LocalSpace.newID()
    var url: URL
    var title: String

    func tab(essential: Bool) -> SpaceTab {
        SpaceTab(id: id, url: url, title: title.isEmpty ? AddressResolver.display(url) : title, isEssential: essential, isPinned: true)
    }
}
