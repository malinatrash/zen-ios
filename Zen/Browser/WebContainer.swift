import SwiftUI
import WebKit

// Hosts the selected tab's web view and swaps it on switch.
struct WebContainer: UIViewRepresentable {
    let tab: BrowserTab

    // Keep in sync with BottomBar's height, or page content slides under the bar.
    static let barHeight: CGFloat = 96

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ host: UIView, context: Context) {
        let view = tab.webView
        guard view.superview !== host else { return }
        host.subviews.forEach { $0.removeFromSuperview() }
        view.scrollView.contentInset.bottom = Self.barHeight
        view.scrollView.verticalScrollIndicatorInsets.bottom = Self.barHeight
        view.obscuredContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: Self.barHeight, right: 0)
        view.frame = host.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(view)
    }
}
