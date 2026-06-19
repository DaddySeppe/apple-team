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
    var deviceScreenTimes: [String: Int] = [:]
    var deviceNames: [String: String] = [:]
    var deviceScreenTimeDates: [String: String] = [:]
    var screenTimePermissionGranted: Bool? = nil
}

enum ChildScreenTimeStatus {
    case ok
    case nearLimit
    case overLimit
    case blocked
    case notTracked
}

extension Child {
    var screenTimeStatus: ChildScreenTimeStatus {
        if isBlocked { return .blocked }
        if screenTimePermissionGranted == false { return .notTracked }
        if dailyScreenTimeLimitMinutes <= 0 { return .ok }

        let ratio = Float(dailyScreenTimeUsedMinutes) / Float(dailyScreenTimeLimitMinutes)
        if ratio >= 1 { return .overLimit }
        if ratio >= 0.8 { return .nearLimit }
        return .ok
    }
}
