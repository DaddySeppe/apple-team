import Foundation

struct Reward: Identifiable, Codable, Equatable {
    var id: String = ""
    var title: String = ""
    var costPoints: Int = 0
    var childId: String? = nil
    var redeemed: Bool = false
    var requested: Bool = false
}
