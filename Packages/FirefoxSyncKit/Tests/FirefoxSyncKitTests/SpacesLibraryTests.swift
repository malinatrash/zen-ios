import Foundation
import Testing
@testable import FirefoxSyncKit

struct SpacesLibraryTests {
    let library: SpacesLibrary

    init() throws {
        let url = try #require(Bundle.module.url(forResource: "spaces-records", withExtension: "json", subdirectory: "Fixtures"))
        let records = try JSONDecoder().decode([SpacesRecord].self, from: Data(contentsOf: url))
        library = SpacesLibrary(records: records)
    }

    @Test func spacesFollowLayoutOrder() {
        #expect(library.spaces.map(\.name) == ["Work", "Home"])
        #expect(library.spaces[0].icon == .named("briefcase"))
        #expect(library.spaces[1].icon == .emoji("🏠"))
    }

    @Test func essentialsAreSplitByContainer() {
        let work = library.spaces[0]
        let home = library.spaces[1]
        #expect(library.essentials(for: home).map(\.title) == ["Mail", "Calendar"])
        #expect(library.essentials(for: work).map(\.title) == ["Jira"])
        #expect(library.essentials(for: home, separateByContainer: false).count == 3)
    }

    @Test func childrenBuildTreeWithFoldersAndSplits() throws {
        let home = library.spaces[1]
        #expect(home.items.map(\.id) == ["1700000000010-news", "folder-1", "1700000000013-left", "1700000000014-right", "1700000000020-open"])
        #expect(home.openTabs.map(\.title) == ["Open tab"])
        #expect(home.pinned.count == 4)
        guard case .folder(let folder) = home.items[1] else {
            Issue.record("expected a folder")
            return
        }
        #expect(folder.name == "Reading")
        #expect(folder.items.map(\.id) == ["1700000000011-blog", "folder-2"])
        guard case .folder(let nested) = folder.items[1] else {
            Issue.record("expected a nested folder")
            return
        }
        #expect(nested.items.map(\.id) == ["1700000000012-docs"])
    }

    @Test func tabLabelFallsBackToHost() throws {
        let home = library.spaces[1]
        guard case .folder(let folder) = home.items[1], case .tab(let blog) = folder.items[0] else {
            Issue.record("expected a tab in the folder")
            return
        }
        #expect(blog.title == "blog.example.com")
        #expect(library.essentials(for: home)[1].iconDataURL == "data:image/png;base64,AAAA")
        #expect(library.essentials(for: home)[0].iconDataURL == nil)
    }

    @Test func themeDecodesBothColorForms() throws {
        let work = try #require(library.spaces[0].theme)
        let home = try #require(library.spaces[1].theme)
        #expect(work.gradientColors == [.init(rgb: RGB(0x33, 0x66, 0xFF), isCustom: true)])
        #expect(home.gradientColors.count == 2)
        #expect(home.gradientColors[0].isPrimary)
    }

    @Test func paintMatchesZenRules() throws {
        let home = try #require(library.spaces[1].theme)
        let gradient = home.paint(dark: true)
        #expect(gradient.stops.count == 12)
        #expect(gradient.stops[9] == gradient.stops[11])
        let alpha = SpaceTheme.layerAlpha(opacity: 0.5)
        #expect(abs(alpha - (0.2 + 0.68 * 0.16)) < 1e-9)
        #expect(gradient.stops[0] == ColorMath.composite(RGB(244, 93, 74), over: RGB(19, 19, 19), alpha: alpha))
        let solid = try #require(library.spaces[0].theme).paint(dark: false)
        #expect(solid.stops == [RGB(0x33, 0x66, 0xFF)])
        #expect(SpaceTheme().paint(dark: true).stops == [RGB(19, 19, 19)])
    }

    @Test func oklabRoundTrips() {
        let color = RGB(120, 45, 200)
        let back = ColorMath.rgb(oklab: ColorMath.oklab(color))
        #expect(abs(back.r - color.r) < 0.01 && abs(back.g - color.g) < 0.01 && abs(back.b - color.b) < 0.01)
    }
}
