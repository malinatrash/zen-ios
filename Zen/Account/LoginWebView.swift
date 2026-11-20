import SwiftUI
import WebKit

// Mozilla sign-in page: the password is typed there, the app only gets a code.
struct LoginWebView: UIViewRepresentable {
    let url: URL
    let onCode: (_ code: String, _ state: String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(origin: url, onCode: onCode)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Non-persistent store: each sign-in starts clean and Mozilla's cookies never outlive the sheet.
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let script = WKUserScript(source: Coordinator.bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
        configuration.userContentController.add(context.coordinator, name: Coordinator.handler)
        let view = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = view
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.handler)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        static let handler = "accountsCommandHandler"
        static let bridge = """
        window.addEventListener("WebChannelMessageToChrome", function (e) {
          webkit.messageHandlers.accountsCommandHandler.postMessage({ type: e.type, detail: e.detail });
        });
        """

        let origin: URL
        let onCode: (String, String) -> Void
        weak var webView: WKWebView?

        init(origin: URL, onCode: @escaping (String, String) -> Void) {
            self.origin = origin
            self.onCode = onCode
        }

        // Accepts WebChannel commands only from the account page's main frame.
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            let source = message.frameInfo.securityOrigin
            guard message.frameInfo.isMainFrame, source.host == origin.host(), source.protocol == "https" else { return }
            guard let body = message.body as? [String: Any], let detail = Self.object(body["detail"]),
                  let inner = detail["message"] as? [String: Any], let command = inner["command"] as? String
            else { return }
            let id = inner["messageId"]
            let data = inner["data"] as? [String: Any] ?? [:]
            switch command {
            case "fxaccounts:fxa_status":
                reply(command, id, ["capabilities": ["engines": ["tabs"], "choose_what_to_sync": false]])
            case "fxaccounts:can_link_account":
                reply(command, id, ["ok": true])
            case "fxaccounts:oauth_login":
                guard let code = data["code"] as? String, let state = data["state"] as? String else { return }
                onCode(code, state)
            case "fxaccounts:loaded", "fxaccounts:login":
                break
            default:
                reply(command, id, ["error": "Unrecognized FxAccountsWebChannel command: \(command)"])
            }
        }

        static func object(_ detail: Any?) -> [String: Any]? {
            if let ready = detail as? [String: Any] { return ready }
            guard let text = detail as? String else { return nil }
            return (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
        }

        func reply(_ command: String, _ id: Any?, _ data: [String: Any]) {
            var message: [String: Any] = ["command": command, "data": data]
            message["messageId"] = id
            let envelope: [String: Any] = ["id": "account_updates", "message": message]
            guard let json = try? JSONSerialization.data(withJSONObject: envelope),
                  let quoted = try? JSONSerialization.data(withJSONObject: [String(decoding: json, as: UTF8.self)])
            else { return }
            let argument = String(decoding: quoted, as: UTF8.self).dropFirst().dropLast()
            let script = "window.dispatchEvent(new CustomEvent('WebChannelMessageToContent', { detail: \(argument) }));"
            webView?.evaluateJavaScript(script)
        }
    }
}
