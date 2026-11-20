import SwiftUI

@main
struct ZenApp: App {
    @State private var browser: BrowserModel
    @State private var account: AccountModel
    @State private var spaces: SpacesModel

    init() {
        if CommandLine.arguments.contains("-demo") {
            let models = PreviewData.models()
            _browser = State(initialValue: PreviewData.browser)
            _account = State(initialValue: models.account)
            _spaces = State(initialValue: models.spaces)
        } else {
            let account = AccountModel()
            _browser = State(initialValue: BrowserModel())
            _account = State(initialValue: account)
            _spaces = State(initialValue: SpacesModel(account: account))
        }
    }

    var body: some Scene {
        WindowGroup {
            BrowserScreen(browser: browser, account: account, spaces: spaces)
        }
    }
}
