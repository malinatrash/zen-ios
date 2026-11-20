import FirefoxSyncKit
import Foundation

// Preview data: spaces, Essentials and tabs, no network and no account.
enum PreviewData {
    static let homeTheme = SpaceTheme(
        gradientColors: [.init(rgb: RGB(244, 93, 74), isPrimary: true), .init(rgb: RGB(120, 96, 220))],
        opacity: 0.62
    )

    static let workTheme = SpaceTheme(gradientColors: [.init(rgb: RGB(64, 132, 214), isPrimary: true)], opacity: 0.55)

    static let tripleTheme = SpaceTheme(
        gradientColors: [.init(rgb: RGB(52, 168, 140), isPrimary: true), .init(rgb: RGB(60, 110, 220)), .init(rgb: RGB(190, 80, 200))],
        opacity: 0.7
    )

    static func tab(_ host: String, _ title: String, essential: Bool = false, pinned: Bool = true) -> SpaceTab {
        SpaceTab(id: host, url: URL(string: "https://\(host)/")!, title: title, isEssential: essential, isPinned: pinned)
    }

    static let essentials = [
        tab("mail.example.com", "Mail", essential: true), tab("calendar.example.com", "Calendar", essential: true),
        tab("music.example.com", "Music", essential: true), tab("chat.example.com", "Chat", essential: true),
        tab("notes.example.com", "Notes", essential: true), tab("git.example.com", "Git", essential: true),
    ]

    static let home = Space(
        id: "{home}", name: "Home", icon: .emoji("🏠"), theme: homeTheme,
        items: [
            .tab(tab("news.example.com", "News")),
            .folder(SpaceFolder(id: "f1", name: "Reading", items: [
                .tab(tab("blog.example.com", "Swift blog")), .tab(tab("docs.example.com", "Docs")),
            ])),
            .tab(tab("video.example.com", "Video")),
            .tab(tab("shop.example.com", "Order on the way", pinned: false)),
        ]
    )

    static let work = Space(
        id: "{work}", name: "Work", icon: .named("briefcase"), theme: workTheme,
        items: [.tab(tab("jira.example.com", "Task board")), .tab(tab("gitlab.example.com", "Merge requests"))]
    )

    static let records: [SpacesRecord] = {
        let json = """
        [{"id":"layout","kind":"layout","data":{"spaces":["{home}","{work}"],"essentials":{"default":["e1","e2","e3","e4","e5","e6"]}}},
         {"id":"{home}","kind":"space","data":{"uuid":"{home}","name":"Home","icon":"🏠","children":["p1","f1","p4","n1"],
          "theme":{"opacity":0.62,"gradientColors":[{"c":[244,93,74],"isPrimary":true},{"c":[120,96,220]}]}}},
         {"id":"{work}","kind":"space","data":{"uuid":"{work}","name":"Work","icon":"chrome://browser/skin/zen-icons/selectable/briefcase.svg","children":["w1","w2"],
          "theme":{"opacity":0.55,"gradientColors":[{"c":[64,132,214],"isPrimary":true}]}}},
         {"id":"e1","kind":"tab","data":{"tabId":"e1","url":"https://mail.example.com/","title":"Mail","essential":true,"pinned":true}},
         {"id":"e2","kind":"tab","data":{"tabId":"e2","url":"https://calendar.example.com/","title":"Calendar","essential":true,"pinned":true}},
         {"id":"e3","kind":"tab","data":{"tabId":"e3","url":"https://music.example.com/","title":"Music","essential":true,"pinned":true}},
         {"id":"e4","kind":"tab","data":{"tabId":"e4","url":"https://chat.example.com/","title":"Chat","essential":true,"pinned":true}},
         {"id":"e5","kind":"tab","data":{"tabId":"e5","url":"https://notes.example.com/","title":"Notes","essential":true,"pinned":true}},
         {"id":"e6","kind":"tab","data":{"tabId":"e6","url":"https://git.example.com/","title":"Git","essential":true,"pinned":true}},
         {"id":"p1","kind":"tab","data":{"tabId":"p1","url":"https://news.example.com/","title":"News","pinned":true}},
         {"id":"f1","kind":"folder","data":{"folderId":"f1","name":"Reading","children":["p2","p3"]}},
         {"id":"p2","kind":"tab","data":{"tabId":"p2","url":"https://blog.example.com/","title":"Swift blog","pinned":true}},
         {"id":"p3","kind":"tab","data":{"tabId":"p3","url":"https://docs.example.com/","title":"Docs","pinned":true}},
         {"id":"p4","kind":"tab","data":{"tabId":"p4","url":"https://video.example.com/","title":"Video","pinned":true}},
         {"id":"n1","kind":"tab","data":{"tabId":"n1","url":"https://shop.example.com/","title":"Order on the way","pinned":false}},
         {"id":"w1","kind":"tab","data":{"tabId":"w1","url":"https://jira.example.com/","title":"Task board","pinned":true}},
         {"id":"w2","kind":"tab","data":{"tabId":"w2","url":"https://gitlab.example.com/","title":"Merge requests","pinned":true}}]
        """
        return (try? JSONDecoder().decode([SpacesRecord].self, from: Data(json.utf8))) ?? []
    }()

    static let devices = [
        RemoteDevice(id: "mac", name: "Zen on MacBook", application: "Zen", tabs: [
            RemoteTab(url: URL(string: "https://developer.example.com/swiftui")!, title: "SwiftUI: overview"),
            RemoteTab(url: URL(string: "https://maps.example.com/route")!, title: "Route to the office", lastUsed: .now.addingTimeInterval(-3600)),
            RemoteTab(url: URL(string: "https://wiki.example.com/zen")!, title: "Project notes", lastUsed: .now.addingTimeInterval(-86400)),
        ]),
        RemoteDevice(id: "pc", name: "Home PC", tabs: [
            RemoteTab(url: URL(string: "https://forum.example.com/t/42")!, title: "Build discussion"),
        ]),
    ]

    static let snapshot = SyncSnapshot(spaces: SpacesLibrary(records: records), devices: devices, spacesState: .available)

    static var account: AccountModel { AccountModel(preview: snapshot) }

    static let localLibrary = LocalLibrary(
        spaces: [LocalSpace(id: "local-study", name: "Study", icon: "📚", colors: [[52, 168, 140], [64, 132, 214]], opacity: 0.65)],
        pins: [
            "local-study": [LocalPin(id: "local-p1", url: URL(string: "https://course.example.com/")!, title: "Swift course")],
            "{home}": [LocalPin(id: "local-p2", url: URL(string: "https://recipes.example.com/")!, title: "Recipes")],
        ],
        essentials: [LocalPin(id: "local-e1", url: URL(string: "https://weather.example.com/")!, title: "Weather")]
    )

    // Account and spaces wired together for whole-screen previews.
    static func models(signedIn: Bool = true) -> (account: AccountModel, spaces: SpacesModel) {
        let account = signedIn ? AccountModel(preview: snapshot) : AccountModel.signedOutPreview
        return (account, SpacesModel(account: account, library: localLibrary))
    }

    static var browser: BrowserModel {
        BrowserModel(tabs: [
            BrowserTab(),
            BrowserTab(url: URL(string: "https://news.example.com/")!, title: "Daily news", spaceID: "{home}"),
            BrowserTab(url: URL(string: "https://blog.example.com/swift")!, title: "Swift blog", spaceID: "{home}"),
            BrowserTab(url: URL(string: "https://weather.example.com/today")!, title: "Weekly weather", spaceID: "{home}"),
            BrowserTab(url: URL(string: "https://jira.example.com/board")!, title: "Task board", spaceID: "{work}"),
            BrowserTab(url: URL(string: "https://mail.example.com/")!, title: "Mail", pinnedURL: URL(string: "https://mail.example.com/")),
        ])
    }
}
