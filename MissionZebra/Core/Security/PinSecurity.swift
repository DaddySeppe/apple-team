import Foundation
import CommonCrypto
import Security

struct PinSecurity {

    private static let saltLengthBytes = 16
    private static let hashLengthBytes = 32
    private static let iterations = 210_000
    private static let currentAlgorithm = "pbkdf2_sha256"
    private static let fieldSeparator = "$"

    static func generateSalt() -> String {
        var salt = [UInt8](repeating: 0, count: saltLengthBytes)
        _ = SecRandomCopyBytes(kSecRandomDefault, saltLengthBytes, &salt)
        return Data(salt).base64EncodedString()
    }

    static func hashPin(_ pin: String, salt: String) -> String {
        let saltBytes = decodeSalt(salt)
        let hash = pbkdf2(pin: pin, salt: saltBytes, iterations: iterations)
        return [
            currentAlgorithm,
            String(iterations),
            Data(saltBytes).base64EncodedString(),
            Data(hash).base64EncodedString()
        ].joined(separator: fieldSeparator)
    }

    static func verifyPin(_ enteredPin: String, salt: String, expectedHash: String) -> Bool {
        if isVersionedHash(expectedHash) {
            return verifyVersionedPin(enteredPin, encoded: expectedHash)
        }

        let legacyHash = legacySha256(pin: enteredPin, salt: salt)
        return constantTimeEquals(
            Array(legacyHash.utf8),
            Array(expectedHash.utf8)
        )
    }

    static func isVersionedHash(_ hash: String) -> Bool {
        hash.hasPrefix(currentAlgorithm + fieldSeparator)
    }

    private static func verifyVersionedPin(_ enteredPin: String, encoded: String) -> Bool {
        let parts = encoded.components(separatedBy: fieldSeparator)
        guard parts.count == 4,
              parts[0] == currentAlgorithm,
              let iterations = Int(parts[1]),
              let salt = Data(base64Encoded: parts[2]),
              let expected = Data(base64Encoded: parts[3]) else {
            return false
        }

        let actual = pbkdf2(pin: enteredPin, salt: Array(salt), iterations: iterations)
        return constantTimeEquals(actual, Array(expected))
    }

    private static func pbkdf2(pin: String, salt: [UInt8], iterations: Int) -> [UInt8] {
        var derived = [UInt8](repeating: 0, count: hashLengthBytes)
        let password = Array(pin.utf8)

        let status = salt.withUnsafeBytes { saltBuffer in
            password.withUnsafeBytes { passwordBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.bindMemory(to: Int8.self).baseAddress,
                    password.count,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derived,
                    hashLengthBytes
                )
            }
        }

        guard status == kCCSuccess else { return [] }
        return derived
    }

    private static func decodeSalt(_ salt: String) -> [UInt8] {
        if let data = Data(base64Encoded: salt), !data.isEmpty {
            return Array(data)
        }
        return hexToBytes(salt) ?? Array(salt.utf8)
    }

    private static func legacySha256(pin: String, salt: String) -> String {
        let input = (pin + salt).data(using: .utf8) ?? Data()
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        input.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func hexToBytes(_ hex: String) -> [UInt8]? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    private static func constantTimeEquals(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }
}
