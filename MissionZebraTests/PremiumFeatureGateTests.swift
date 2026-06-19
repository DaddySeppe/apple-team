import XCTest
@testable import MissionZebra

final class PremiumFeatureGateTests: XCTestCase {
    func testPremiumDashboardRequiresActivePremiumStatus() {
        XCTAssertFalse(PremiumFeatureGate.canAccessPremiumDashboard(status: PremiumStatus(isPremium: false)))
        XCTAssertTrue(PremiumFeatureGate.canAccessPremiumDashboard(status: PremiumStatus(isPremium: true)))
    }

    func testNudgesMatchAndroidThresholdsAndDisappearForPremium() {
        XCTAssertEqual(
            PremiumFeatureGate.nudgeVariant(childrenCount: 2, tasksCount: 0, rewardsCount: 0, isPremium: false),
            .insights
        )
        XCTAssertEqual(
            PremiumFeatureGate.nudgeVariant(childrenCount: 1, tasksCount: 3, rewardsCount: 0, isPremium: false),
            .alerts
        )
        XCTAssertEqual(
            PremiumFeatureGate.nudgeVariant(childrenCount: 1, tasksCount: 1, rewardsCount: 2, isPremium: false),
            .ads
        )
        XCTAssertNil(PremiumFeatureGate.nudgeVariant(childrenCount: 3, tasksCount: 4, rewardsCount: 4, isPremium: true))
    }
}
