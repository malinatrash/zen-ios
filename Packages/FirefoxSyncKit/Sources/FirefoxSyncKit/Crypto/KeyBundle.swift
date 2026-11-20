import CommonCrypto
import CryptoKit
import Foundation

public enum SyncCryptoError: Error, Equatable {
    case badKey
    case badPayload
    case hmacMismatch
    case cipherFailed
}

// A Sync key pair: AES-256-CBC for encryption and HMAC-SHA256 for signing.
public struct KeyBundle: Sendable, Equatable {
    let encryptionKey: Data
    let hmacKey: Data

    public init(encryptionKey: Data, hmacKey: Data) throws {
        guard encryptionKey.count == 32, hmacKey.count == 32 else { throw SyncCryptoError.badKey }
        self.encryptionKey = encryptionKey
        self.hmacKey = hmacKey
    }

    // The account's kSync key: the first 32 bytes encrypt, the second 32 sign.
    public init(syncKey: Data) throws {
        guard syncKey.count == 64 else { throw SyncCryptoError.badKey }
        try self.init(encryptionKey: syncKey.prefix(32), hmacKey: syncKey.suffix(32))
    }

    // Decrypts a record envelope; the HMAC covers the base64 ciphertext string.
    public func decrypt(_ payload: EncryptedPayload) throws -> Data {
        guard let expected = Data(hex: payload.hmac),
              let iv = Data(base64Encoded: payload.IV), iv.count == kCCBlockSizeAES128,
              let ciphertext = Data(base64Encoded: payload.ciphertext)
        else { throw SyncCryptoError.badPayload }
        let key = SymmetricKey(data: hmacKey)
        guard HMAC<SHA256>.isValidAuthenticationCode(expected, authenticating: Data(payload.ciphertext.utf8), using: key) else {
            throw SyncCryptoError.hmacMismatch
        }
        return try crypt(ciphertext, iv: iv, operation: CCOperation(kCCDecrypt))
    }

    public func encrypt(_ cleartext: Data) throws -> EncryptedPayload {
        try encrypt(cleartext, iv: .random(16))
    }

    func encrypt(_ cleartext: Data, iv: Data) throws -> EncryptedPayload {
        let ciphertext = try crypt(cleartext, iv: iv, operation: CCOperation(kCCEncrypt)).base64EncodedString()
        let mac = HMAC<SHA256>.authenticationCode(for: Data(ciphertext.utf8), using: SymmetricKey(data: hmacKey))
        return EncryptedPayload(ciphertext: ciphertext, IV: iv.base64EncodedString(), hmac: Data(mac).hex)
    }

    private func crypt(_ input: Data, iv: Data, operation: CCOperation) throws -> Data {
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var moved = 0
        let status = CCCrypt(
            operation, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
            [UInt8](encryptionKey), encryptionKey.count, [UInt8](iv),
            [UInt8](input), input.count, &output, output.count, &moved
        )
        guard status == kCCSuccess else { throw SyncCryptoError.cipherFailed }
        return Data(output.prefix(moved))
    }
}

public struct EncryptedPayload: Sendable, Equatable, Codable {
    public var ciphertext: String
    public var IV: String
    public var hmac: String
}
