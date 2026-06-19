import XCTest
@testable import MissionZebra

final class RewardRedemptionPolicyTests: XCTestCase {
    func testRedeemSubtractsCostWhenChildHasEnoughPoints() throws {
        let reward = Reward(title: "IJsje", costPoints: 25, childId: "child-1")

        XCTAssertEqual(
            try RewardRedemptionPolicy.remainingPoints(afterRedeeming: reward, childPoints: 40).get(),
            15
        )
    }

    func testRedeemRejectsInsufficientPointsAndAlreadyRedeemedReward() {
        let reward = Reward(title: "IJsje", costPoints: 25, childId: "child-1")
        let redeemed = Reward(title: "IJsje", costPoints: 25, childId: "child-1", redeemed: true)

        XCTAssertEqual(
            RewardRedemptionPolicy.remainingPoints(afterRedeeming: reward, childPoints: 10),
            .failure(.insufficientPoints)
        )
        XCTAssertEqual(
            RewardRedemptionPolicy.remainingPoints(afterRedeeming: redeemed, childPoints: 40),
            .failure(.alreadyRedeemed)
        )
    }
}
