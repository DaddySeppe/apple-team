import Foundation

enum RewardRedemptionError: Error, Equatable {
    case missingChild
    case alreadyRedeemed
    case insufficientPoints
}

enum RewardRedemptionPolicy {
    static func validate(reward: Reward, childPoints: Int) -> Result<Void, RewardRedemptionError> {
        guard reward.childId != nil else { return .failure(.missingChild) }
        guard !reward.redeemed else { return .failure(.alreadyRedeemed) }
        guard childPoints >= reward.costPoints else { return .failure(.insufficientPoints) }
        return .success(())
    }

    static func remainingPoints(afterRedeeming reward: Reward, childPoints: Int) -> Result<Int, RewardRedemptionError> {
        switch validate(reward: reward, childPoints: childPoints) {
        case .success:
            return .success(childPoints - reward.costPoints)
        case .failure(let error):
            return .failure(error)
        }
    }
}
