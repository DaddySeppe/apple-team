import Foundation

enum PremiumProductConfiguration {
    static let primaryProductId = "premium_monthly"

    static var productIds: [String] {
        let configuredIds = Bundle.main.object(forInfoDictionaryKey: "MZ_PREMIUM_PRODUCT_IDS") as? String
        let ids = configuredIds?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        return ids.isEmpty ? [primaryProductId] : ids
    }

    static func isKnownProductId(_ productId: String) -> Bool {
        productIds.contains(productId)
    }
}

struct ApplePremiumVerificationRequest: Equatable {
    let transactionId: String
    let originalTransactionId: String
    let productId: String
    let signedTransactionInfo: String
    let source: String

    var callableData: [String: Any] {
        [
            "transactionId": transactionId,
            "originalTransactionId": originalTransactionId,
            "productId": productId,
            "signedTransactionInfo": signedTransactionInfo,
            "source": source
        ]
    }
}
