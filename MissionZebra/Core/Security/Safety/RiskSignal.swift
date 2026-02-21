import Foundation

enum RiskLevel: String, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

struct RiskSignal: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let level: RiskLevel
    let timestamp: Int64

    init(id: String, title: String, description: String, level: RiskLevel, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        self.id = id
        self.title = title
        self.description = description
        self.level = level
        self.timestamp = timestamp
    }
}
