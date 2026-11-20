import Foundation

// Turns typed text into an address or a search query.
enum AddressResolver {
    static let search = "https://duckduckgo.com/?q="

    static func url(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let direct = URL(string: text), let scheme = direct.scheme, ["http", "https"].contains(scheme.lowercased()), direct.host() != nil {
            return direct
        }
        if looksLikeHost(text), let guessed = URL(string: "https://" + text) {
            return guessed
        }
        let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? text
        return URL(string: search + query)
    }

    // Short address form for the bar: host without www.
    static func display(_ url: URL?) -> String {
        guard let host = url?.host() else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func looksLikeHost(_ text: String) -> Bool {
        guard !text.contains(" ") else { return false }
        let host = text.split(separator: "/").first.map(String.init) ?? text
        let name = host.split(separator: ":").first.map(String.init) ?? host
        if name == "localhost" { return true }
        let parts = name.split(separator: ".")
        return parts.count >= 2 && (parts.last?.count ?? 0) >= 2
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&+=?#")
        return set
    }()
}
