import Foundation

struct ChildData: Identifiable, Codable, Equatable {
    var id: String = ""
    var name: String = ""
    var remainingMinutes: Int = 0
}
