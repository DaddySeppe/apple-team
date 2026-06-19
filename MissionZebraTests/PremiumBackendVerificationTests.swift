import XCTest
@testable import MissionZebra

final class PremiumBackendVerificationTests: XCTestCase {
    func testApplePremiumVerificationPayloadContainsSignedTransaction() {
        let request = ApplePremiumVerificationRequest(
            transactionId: "2000000123",
            originalTransactionId: "1000000456",
            productId: "premium_monthly",
            signedTransactionInfo: "signed-jws",
            source: "iosStoreKitPurchase"
        )

        XCTAssertEqual(request.callableData["transactionId"] as? String, "2000000123")
        XCTAssertEqual(request.callableData["originalTransactionId"] as? String, "1000000456")
        XCTAssertEqual(request.callableData["productId"] as? String, "premium_monthly")
        XCTAssertEqual(request.callableData["signedTransactionInfo"] as? String, "signed-jws")
        XCTAssertEqual(request.callableData["source"] as? String, "iosStoreKitPurchase")
    }
}
