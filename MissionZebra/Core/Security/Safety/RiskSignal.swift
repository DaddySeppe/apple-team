import Foundation

enum RiskLevel: String, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

enum SafetyCategory: String, Codable, CaseIterable {
    case social = "SOCIAL"
    case video = "VIDEO"
    case game = "GAME"
    case browser = "BROWSER"
    case other = "OTHER"

    var labelLower: String {
        switch self {
        case .social: return "sociale media/chat"
        case .video: return "video"
        case .game: return "game"
        case .browser: return "browser"
        case .other: return "overige"
        }
    }
}

struct SafetyUsageSnapshot: Identifiable, Codable, Equatable {
    var id: String { "\(childId)-\(deviceId)-\(date)" }
    var childId: String = ""
    var deviceId: String = ""
    var date: String = ""
    var totalMinutes: Int = 0
    var nightMinutes: Int = 0
    var categoryMinutes: [SafetyCategory: Int] = [:]
    var categoryOpenCounts: [SafetyCategory: Int] = [:]
    var openCount: Int = 0
    var trackedAt: Int64 = 0
}

struct SafetyOverview: Equatable {
    var children: [Child] = []
    var snapshots: [SafetyUsageSnapshot] = []
    var signals: [RiskSignal] = []
    var latestTrackedAt: Int64? = nil
}

struct RiskSignal: Identifiable, Codable, Equatable {
    let id: String
    let childId: String
    let childName: String
    let title: String
    let description: String
    let level: RiskLevel
    let category: SafetyCategory?
    let sourceDate: String
    let timestamp: Int64

    init(
        id: String,
        childId: String = "",
        childName: String = "",
        title: String,
        description: String,
        level: RiskLevel,
        category: SafetyCategory? = nil,
        sourceDate: String = "",
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.childId = childId
        self.childName = childName
        self.title = title
        self.description = description
        self.level = level
        self.category = category
        self.sourceDate = sourceDate
        self.timestamp = timestamp
    }
}
