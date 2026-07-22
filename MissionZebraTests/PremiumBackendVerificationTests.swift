import XCTest
@testable import MissionZebra

final class PremiumBackendVerificationTests: XCTestCase {
    func testPremiumProductConfigurationMatchesAppStoreProductId() {
        XCTAssertEqual(PremiumProductConfiguration.primaryProductId, "premium_monthly")
        XCTAssertTrue(PremiumProductConfiguration.productIds.contains("premium_monthly"))
        XCTAssertTrue(PremiumProductConfiguration.isKnownProductId("premium_monthly"))
    }

    func testApplePremiumVerificationPayloadContainsSignedTransaction() {
        let request = ApplePremiumVerificationRequest(
            transactionId: "2000000123",
            originalTransactionId: "1000000456",
            productId: PremiumProductConfiguration.primaryProductId,
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
