import Observation
import UIKit
import WebKit

// One tab: the web view is created only on first display.
@Observable
final class BrowserTab: Identifiable {
    let id: UUID
    var url: URL?
    var title: String
    var isLoading = false
    var progress = 0.0
    var canGoBack = false
    var canGoForward = false
    var pinnedURL: URL?
    var spaceID: String?
    var lastUsed: Date
    let syncID: String

    @ObservationIgnored private var storedWebView: WKWebView?
    @ObservationIgnored private var observers: [NSKeyValueObservation] = []

    init(id: UUID = UUID(), url: URL? = nil, title: String = "", pinnedURL: URL? = nil, spaceID: String? = nil, lastUsed: Date = .now, syncID: String? = nil) {
        self.syncID = syncID ?? "\(Int(Date.now.timeIntervalSince1970 * 1000))-\(id.uuidString.lowercased())"
        self.id = id
        self.url = url
        self.title = title
        self.pinnedURL = pinnedURL
        self.spaceID = spaceID
        self.lastUsed = lastUsed
    }

    var isBlank: Bool { url == nil }

    var isLive: Bool { storedWebView != nil }

    var displayTitle: String {
        title.isEmpty ? (AddressResolver.display(url).isEmpty ? "New Tab" : AddressResolver.display(url)) : title
    }

    // Returns the web view, creating it and loading the tab's address on first use.
    var webView: WKWebView {
        if let storedWebView { return storedWebView }
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsBackForwardNavigationGestures = true
        view.allowsLinkPreview = true
        view.isFindInteractionEnabled = true
        view.scrollView.contentInsetAdjustmentBehavior = .always
        observe(view)
        storedWebView = view
        if let url { view.load(URLRequest(url: url)) }
        return view
    }

    func load(_ url: URL) {
        self.url = url
        webView.load(URLRequest(url: url))
    }

    func reload() {
        storedWebView?.reload()
    }

    // Returns a pinned tab to its original address, like Zen's pin reset.
    func resetToPinned() {
        guard let pinnedURL else { return }
        load(pinnedURL)
    }

    // Unloads the page from memory; the address stays.
    func unload() {
        observers = []
        storedWebView = nil
        isLoading = false
    }

    private func observe(_ view: WKWebView) {
        observers = [
            view.observe(\.url) { [weak self] _, _ in Task { @MainActor in self?.sync() } },
            view.observe(\.title) { [weak self] _, _ in Task { @MainActor in self?.sync() } },
            view.observe(\.isLoading) { [weak self] _, _ in Task { @MainActor in self?.sync() } },
            view.observe(\.estimatedProgress) { [weak self] _, _ in Task { @MainActor in self?.sync() } },
            view.observe(\.canGoBack) { [weak self] _, _ in Task { @MainActor in self?.sync() } },
        ]
    }

    // Copies page state into the tab's observable fields.
    private func sync() {
        guard let view = storedWebView else { return }
        if let current = view.url, current != url { url = current }
        let name = view.title ?? ""
        if name != title { title = name }
        if view.isLoading != isLoading { isLoading = view.isLoading }
        if view.estimatedProgress != progress { progress = view.estimatedProgress }
        if view.canGoBack != canGoBack { canGoBack = view.canGoBack }
        if view.canGoForward != canGoForward { canGoForward = view.canGoForward }
    }
}
