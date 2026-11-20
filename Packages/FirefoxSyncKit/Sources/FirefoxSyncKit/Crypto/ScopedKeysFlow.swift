import CryptoKit
import Foundation

// The sync key the account hands the app along with the tokens.
public struct ScopedKey: Sendable, Equatable, Codable {
    public var k: String
    public var kid: String

    public static let syncScope = "https://identity.mozilla.com/apps/oldsync"

    public func bundle() throws -> KeyBundle {
        guard let raw = Data(base64URL: k) else { throw SyncCryptoError.badKey }
        return try KeyBundle(syncKey: raw)
    }
}

// One-off P-256 pair: the public half goes into keys_jwk, the private half opens keys_jwe.
public struct ScopedKeysFlow: Sendable {
    let privateKey: P256.KeyAgreement.PrivateKey

    public init() {
        privateKey = P256.KeyAgreement.PrivateKey()
    }

    public init(rawPrivateKey: Data) throws {
        privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: rawPrivateKey)
    }

    public var rawPrivateKey: Data {
        privateKey.rawRepresentation
    }

    // Value of the keys_jwk parameter for the sign-in page.
    public var publicJWK: String {
        let point = privateKey.publicKey.x963Representation.dropFirst()
        let jwk = ["kty": "EC", "crv": "P-256", "x": Data(point.prefix(32)).base64URL, "y": Data(point.suffix(32)).base64URL]
        let json = try? JSONSerialization.data(withJSONObject: jwk, options: [.sortedKeys])
        return (json ?? Data()).base64URL
    }

    // Decrypts keys_jwe (ECDH-ES + A256GCM) and extracts the sync key.
    public func syncKey(fromJWE jwe: String) throws -> ScopedKey {
        let json = try decrypt(jwe: jwe)
        let keys = try JSONDecoder().decode([String: ScopedKey].self, from: json)
        guard let key = keys[ScopedKey.syncScope] else { throw SyncCryptoError.badPayload }
        return key
    }

    func decrypt(jwe: String) throws -> Data {
        let parts = jwe.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              let headerData = Data(base64URL: parts[0]),
              let iv = Data(base64URL: parts[2]),
              let ciphertext = Data(base64URL: parts[3]),
              let tag = Data(base64URL: parts[4])
        else { throw SyncCryptoError.badPayload }
        let header = try JSONDecoder().decode(Header.self, from: headerData)
        guard header.alg == "ECDH-ES", header.enc == "A256GCM",
              let x = Data(base64URL: header.epk.x), let y = Data(base64URL: header.epk.y)
        else { throw SyncCryptoError.badPayload }
        let peer = try P256.KeyAgreement.PublicKey(x963Representation: Data([0x04]) + x + y)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peer).withUnsafeBytes { Data($0) }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(box, using: Self.contentKey(secret: secret), authenticating: Data(parts[0].utf8))
    }

    // Concat KDF in a single round with empty apu and apv.
    static func contentKey(secret: Data) -> SymmetricKey {
        let algorithm = Data("A256GCM".utf8)
        var input = UInt32(1).bigEndianData + secret
        input += UInt32(algorithm.count).bigEndianData + algorithm
        input += UInt32(0).bigEndianData + UInt32(0).bigEndianData + UInt32(256).bigEndianData
        return SymmetricKey(data: Data(SHA256.hash(data: input)))
    }

    struct Header: Decodable {
        var alg: String
        var enc: String
        var epk: Point

        struct Point: Decodable {
            var x: String
            var y: String
        }
    }
}
