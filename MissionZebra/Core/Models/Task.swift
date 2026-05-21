import Foundation

struct MZTask: Identifiable, Codable, Equatable {
    static let recurrenceWeekly = "WEEKLY"

    var id: String = ""
    var title: String = ""
    var points: Int = 0
    var childId: String? = nil
    var childName: String? = nil
    var parentId: String? = nil
    var pendingApproval: Bool = false
    var completed: Bool = false
    var dueDate: String? = nil
    var recurrence: String? = nil
}
