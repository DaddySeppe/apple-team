import Foundation

struct Child: Identifiable, Codable, Equatable {
    var id: String = ""
    var name: String = ""
    var points: Int = 0
    var dailyScreenTimeUsedMinutes: Int = 0
    var dailyScreenTimeLimitMinutes: Int = 60
    var isBlocked: Bool = false

    var purchasedAccessoryIds: [String] = []
    var equippedAccessoryId: String? = nil

    var streak: Int = 0
    var lastStreakCheckDate: String? = nil // "YYYY-MM-DD"

    var motivationalMessage: String? = nil

    var screenTimeHistory: [String: Int] = [:]
}
