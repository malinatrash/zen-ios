import Foundation

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.badResponse }
        return (data, http)
    }
}

public enum SyncError: Error, Equatable {
    case badResponse
    case http(status: Int, body: String)
    case signedOut
    case stateMismatch
    case keysChanged
    case unsupportedStorage
    case backoff(seconds: Int)
}

extension HTTPTransport {
    // Sends the request and decodes JSON; any non-2xx status becomes an error.
    func json<T: Decodable>(_ request: URLRequest, as type: T.Type = T.self) async throws -> T {
        let data = try await success(request).0
        return try JSONDecoder().decode(type, from: data)
    }

    func success(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else {
            if let wait = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init), [429, 503].contains(response.statusCode) {
                throw SyncError.backoff(seconds: wait)
            }
            throw SyncError.http(status: response.statusCode, body: String(decoding: data.prefix(500), as: UTF8.self))
        }
        return (data, response)
    }
}

extension URLRequest {
    static func postJSON(_ url: URL, body: [String: Any], bearer: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        return request
    }
}
