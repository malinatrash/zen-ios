import FirefoxSyncKit
import Foundation

// One row of a space's tab list: a tab living on the phone or one still only in Zen.
enum TabEntry: Identifiable {
    case phone(BrowserTab)
    case zen(SpaceTab)

    var id: String {
        switch self {
        case .phone(let tab): tab.syncID
        case .zen(let tab): tab.id
        }
    }

    var url: URL {
        switch self {
        case .phone(let tab): tab.url ?? URL(string: "about:blank")!
        case .zen(let tab): tab.url
        }
    }

    var title: String {
        switch self {
        case .phone(let tab): tab.displayTitle
        case .zen(let tab): tab.title
        }
    }

    var iconDataURL: String? {
        if case .zen(let tab) = self { return tab.iconDataURL }
        return nil
    }
}
