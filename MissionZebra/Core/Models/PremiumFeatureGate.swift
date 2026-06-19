import Foundation

enum PremiumNudgeVariant: Equatable {
    case insights
    case alerts
    case rewardsOverview
}

enum PremiumFeatureGate {
    static func canAccessPremiumDashboard(status: PremiumStatus) -> Bool {
        status.isPremium
    }

    static func nudgeVariant(childrenCount: Int, tasksCount: Int, rewardsCount: Int, isPremium: Bool) -> PremiumNudgeVariant? {
        if isPremium { return nil }
        if childrenCount >= 2 { return .insights }
        if tasksCount >= 3 { return .alerts }
        if rewardsCount >= 2 { return .rewardsOverview }
        return nil
    }
}
