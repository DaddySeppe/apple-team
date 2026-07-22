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
            .rewardsOverview
        )
        XCTAssertNil(PremiumFeatureGate.nudgeVariant(childrenCount: 3, tasksCount: 4, rewardsCount: 4, isPremium: true))
    }

    func testParentAdsOnlyShowForNonPremiumParentSessions() {
        let parentSession = RoleSession(
            role: SessionManager.roleParent,
            isLoggedIn: true,
            firebaseUid: "parent-1",
            childId: nil,
            childName: nil
        )
        let childSession = RoleSession(
            role: SessionManager.roleChild,
            isLoggedIn: true,
            firebaseUid: "parent-1",
            childId: "child-1",
            childName: "Zebra"
        )

        XCTAssertTrue(ParentAdVisibility.shouldShowParentAds(session: parentSession, isPremium: false))
        XCTAssertFalse(ParentAdVisibility.shouldShowParentAds(session: parentSession, isPremium: true))
        XCTAssertFalse(ParentAdVisibility.shouldShowParentAds(session: childSession, isPremium: false))
    }
}
