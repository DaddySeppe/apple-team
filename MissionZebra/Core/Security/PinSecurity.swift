import Foundation
import CommonCrypto

struct PinSecurity {

    private static let saltLengthBytes = 16

    static func generateSalt() -> String {
        var salt = [UInt8](repeating: 0, count: saltLengthBytes)
        _ = SecRandomCopyBytes(kSecRandomDefault, saltLengthBytes, &salt)
        return salt.map { String(format: "%02x", $0) }.joined()
    }

    static func hashPin(_ pin: String, salt: String) -> String {
        let input = (pin + salt).data(using: .utf8)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        input.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    static func verifyPin(_ enteredPin: String, salt: String, expectedHash: String) -> Bool {
        let hash = hashPin(enteredPin, salt: salt)
        return hash == expectedHash
    }
}
