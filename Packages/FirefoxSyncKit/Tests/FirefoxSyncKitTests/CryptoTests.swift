import Foundation
import Testing
@testable import FirefoxSyncKit

// Known-answer values taken from the mozilla/application-services tests.
struct CryptoTests {
    @Test func scopedKeysFlowDecryptsMozillaVector() throws {
        let raw = try #require(Data(base64URL: "UayD4kn_4QHvLvLLSSaANfDUp9AcQndQu_TohQKoyn8"))
        let flow = try ScopedKeysFlow(rawPrivateKey: raw)
        let jwk = try #require(Data(base64URL: flow.publicJWK))
        let point = try JSONDecoder().decode([String: String].self, from: jwk)
        #expect(point["x"] == "ARvGIPJ5eIFdp6YTM-INVDqwfun2R9FfCUvXbH7QCIU")
        #expect(point["y"] == "hk8gP0Po8nBh-WSiTsvsyesC5c1L6fGOEVuX8FHsvTs")

        let jwe = "eyJhbGciOiJFQ0RILUVTIiwia2lkIjoiNFBKTTl5dGVGeUtsb21ILWd2UUtyWGZ0a0N3ak9HNHRfTmpYVXhLM1VqSSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMjU2IiwieCI6IlB3eG9Na1RjSVZ2TFlKWU4wM2R0Y3o2TEJrR0FHaU1hZWlNQ3lTZXEzb2MiLCJ5IjoiLUYtTllRRDZwNUdSQ2ZoYm1hN3NvNkhxdExhVlNub012S0pFcjFBeWlaSSJ9LCJlbmMiOiJBMjU2R0NNIn0..b9FPhjjpmAmo_rP8.ur9jTry21Y2trvtcanSFmAtiRfF6s6qqyg6ruRal7PCwa7PxDzAuMN6DZW5BiK8UREOH08-FyRcIgdDOm5Zq8KwVAn56PGfcH30aNDGQNkA_mpfjx5Tj2z8kI6ryLWew4PGZb-PsL1g-_eyXhktq7dAhetjNYttKwSREWQFokv7N3nJGpukBqnwL1ost-MjDXlINZLVJKAiMHDcu-q7Epitwid2c2JVGOSCJjbZ4-zbxVmZ4o9xhFb2lbvdiaMygH6bPlrjEK99uT6XKtaIZmyDwftbD6G3x4On-CqA2TNL6ILRaJMtmyX--ctL0IrngUIHg_F0Wz94v.zBD8NACkUcZTPLH0tceGnA"
        let key = try flow.syncKey(fromJWE: jwe)
        #expect(key.kid == "1526414944666-zgTjf5oXmPmBjxwXWFsDWg")
        #expect(key.k == "8ek1VNk4sjrNP0DhGC4crzQtwmpoR64zHuFMHb4Tw-exR70Z2SSIfMSrJDTLEZid9lD05-hbA3n2Q4Esjlu1tA")
        _ = try key.bundle()
    }

    static let ciphertext = [
        "NMsdnRulLwQsVcwxKW9XwaUe7ouJk5Wn80QhbD80l0HEcZGCynh45qIbeYBik0lgcHbK",
        "mlIxTJNwU+OeqipN+/j7MqhjKOGIlvbpiPQQLC6/ffF2vbzL0nzMUuSyvaQzyGGkSYM2",
        "xUFt06aNivoQTvU2GgGmUK6MvadoY38hhW2LCMkoZcNfgCqJ26lO1O0sEO6zHsk3IVz6",
        "vsKiJ2Hq6VCo7hu123wNegmujHWQSGyf8JeudZjKzfi0OFRRvvm4QAKyBWf0MgrW1F8S",
        "FDnVfkq8amCB7NhdwhgLWbN+21NitNwWYknoEWe1m6hmGZDgDT32uxzWxCV8QqqrpH/Z",
        "ggViEr9uMgoy4lYaWqP7G5WKvvechc62aqnsNEYhH26A5QgzmlNyvB+KPFvPsYzxDnSC",
        "jOoRSLx7GG86wT59QZw=",
    ].joined()

    static let cleartext = [
        "eyJpZCI6IjVxUnNnWFdSSlpYciIsImhpc3RVcmkiOiJmaWxlOi8vL1VzZXJzL2phc29u",
        "L0xpYnJhcnkvQXBwbGljYXRpb24lMjBTdXBwb3J0L0ZpcmVmb3gvUHJvZmlsZXMva3Nn",
        "ZDd3cGsuTG9jYWxTeW5jU2VydmVyL3dlYXZlL2xvZ3MvIiwidGl0bGUiOiJJbmRleCBv",
        "ZiBmaWxlOi8vL1VzZXJzL2phc29uL0xpYnJhcnkvQXBwbGljYXRpb24gU3VwcG9ydC9G",
        "aXJlZm94L1Byb2ZpbGVzL2tzZ2Q3d3BrLkxvY2FsU3luY1NlcnZlci93ZWF2ZS9sb2dz",
        "LyIsInZpc2l0cyI6W3siZGF0ZSI6MTMxOTE0OTAxMjM3MjQyNSwidHlwZSI6MX1dfQ==",
    ].joined()

    func vectorBundle() throws -> KeyBundle {
        try KeyBundle(
            encryptionKey: #require(Data(base64Encoded: "9K/wLdXdw+nrTtXo4ZpECyHFNr4d7aYHqeg3KW9+m6Q=")),
            hmacKey: #require(Data(base64Encoded: "MMntEfutgLTc8FlTLQFms8/xMPmCldqPlq/QQXEjx70="))
        )
    }

    @Test func keyBundleDecryptsMozillaVector() throws {
        let payload = EncryptedPayload(
            ciphertext: Self.ciphertext,
            IV: "GX8L37AAb2FZJMzIoXlX8w==",
            hmac: "b1e6c18ac30deb70236bc0d65a46f7a4dce3b8b0e02cf92182b914e3afa5eebc"
        )
        let clear = try vectorBundle().decrypt(payload)
        #expect(clear == Data(base64Encoded: Self.cleartext))
    }

    @Test func keyBundleEncryptsMozillaVector() throws {
        let bundle = try vectorBundle()
        let clear = try #require(Data(base64Encoded: Self.cleartext))
        let iv = try #require(Data(base64Encoded: "GX8L37AAb2FZJMzIoXlX8w=="))
        let payload = try bundle.encrypt(clear, iv: iv)
        #expect(payload.ciphertext == Self.ciphertext)
        #expect(payload.hmac == "b1e6c18ac30deb70236bc0d65a46f7a4dce3b8b0e02cf92182b914e3afa5eebc")
        #expect(try bundle.decrypt(bundle.encrypt(clear)) == clear)
    }

    @Test func keyBundleRejectsTamperedCiphertext() throws {
        var payload = try vectorBundle().encrypt(Data("{}".utf8))
        payload.hmac = String(repeating: "0", count: 64)
        #expect(throws: SyncCryptoError.hmacMismatch) {
            try vectorBundle().decrypt(payload)
        }
    }

    @Test func hawkMatchesReferenceMac() throws {
        let hawk = Hawk(id: "dh37fgj492je", key: "werxhqb98rpaxn39848xrunpaw3489ruxnpa98w4rxn")
        let url = try #require(URL(string: "http://example.com:8000/resource/1?b=1&a=2"))
        let mac = hawk.mac(method: "GET", url: url, timestamp: 1_353_832_234, nonce: "j4h3g2", ext: "some-app-ext-data")
        #expect(mac == "6R4rV5iE+NPoym+WwjeHzjAGXUtLNIxmo1vpMofpLAE=")
    }
}
