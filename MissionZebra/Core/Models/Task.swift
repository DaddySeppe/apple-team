import Foundation

struct MZTask: Identifiable, Codable, Equatable {
    var id: String = ""
    var title: String = ""
    var points: Int = 0
    var childId: String? = nil
    var childName: String? = nil
    var parentId: String? = nil
    var pendingApproval: Bool = false
    var completed: Bool = false
}
