import Foundation

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
