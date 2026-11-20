import CryptoKit
import Foundation

// The Hawk signature the storage server checks on every request.
struct Hawk: Sendable {
    var id: String
    var key: String

    func header(method: String, url: URL, timestamp: Int = Int(Date().timeIntervalSince1970), nonce: String = Data.random(6).base64URL, ext: String = "") -> String {
        let signature = mac(method: method, url: url, timestamp: timestamp, nonce: nonce, ext: ext)
        return "Hawk id=\"\(id)\", ts=\"\(timestamp)\", nonce=\"\(nonce)\", mac=\"\(signature)\""
    }

    func mac(method: String, url: URL, timestamp: Int, nonce: String, ext: String) -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var resource = components?.percentEncodedPath ?? url.path
        if let query = components?.percentEncodedQuery { resource += "?" + query }
        let port = url.port ?? (url.scheme == "http" ? 80 : 443)
        let lines = ["hawk.1.header", "\(timestamp)", nonce, method.uppercased(), resource, (url.host() ?? "").lowercased(), "\(port)", "", ext]
        let normalized = lines.joined(separator: "\n") + "\n"
        let code = HMAC<SHA256>.authenticationCode(for: Data(normalized.utf8), using: SymmetricKey(data: Data(key.utf8)))
        return Data(code).base64EncodedString()
    }
}
