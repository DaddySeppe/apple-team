import Foundation

struct MZTask: Identifiable, Codable, Equatable {
    static let recurrenceWeekly = "WEEKLY"
    static let effortEasy = "EASY"
    static let effortNormal = "NORMAL"
    static let effortHard = "HARD"

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
    var purpose: String = ""
    var contributionTarget: String = ""
    var childReflection: String = ""
    var effortLevel: String = ""
    var parentFeedback: String = ""
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0
}

enum TaskDisplayStatus: Equatable {
    case pendingApproval
    case active
    case expired
    case completed
}

enum TaskOrdering {
    static func displayStatus(_ task: MZTask, today: Date = Date()) -> TaskDisplayStatus {
        if task.completed { return .completed }
        if task.pendingApproval { return .pendingApproval }

        guard let dueDate = task.dueDate,
              let due = Self.date(from: dueDate) else {
            return .active
        }

        return due < startOfDay(today) ? .expired : .active
    }

    static func filter(_ tasks: [MZTask], by status: TaskFilterStatus, today: Date = Date()) -> [MZTask] {
        tasks.filter { task in
            switch status {
            case .all:
                return true
            case .pending:
                return displayStatus(task, today: today) == .pendingApproval
            case .completed:
                return displayStatus(task, today: today) == .completed
            case .active:
                let status = displayStatus(task, today: today)
                return status == .active || status == .expired
            }
        }
    }

    static func sort(_ tasks: [MZTask], by option: TaskSortOption) -> [MZTask] {
        switch option {
        case .pointsDesc:
            return tasks.sorted {
                $0.points == $1.points
                    ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    : $0.points > $1.points
            }
        case .pointsAsc:
            return tasks.sorted {
                $0.points == $1.points
                    ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    : $0.points < $1.points
            }
        case .titleAsc:
            return tasks.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .dateDesc:
            return tasks.sorted {
                let lhsCreated = $0.createdAt > 0 ? $0.createdAt : Int64.min
                let rhsCreated = $1.createdAt > 0 ? $1.createdAt : Int64.min
                if lhsCreated != rhsCreated { return lhsCreated > rhsCreated }
                if ($0.dueDate ?? "") != ($1.dueDate ?? "") { return ($0.dueDate ?? "") > ($1.dueDate ?? "") }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .dateAsc:
            return tasks.sorted {
                let lhsCreated = $0.createdAt > 0 ? $0.createdAt : Int64.max
                let rhsCreated = $1.createdAt > 0 ? $1.createdAt : Int64.max
                if lhsCreated != rhsCreated { return lhsCreated < rhsCreated }
                if ($0.dueDate ?? "") != ($1.dueDate ?? "") { return ($0.dueDate ?? "") < ($1.dueDate ?? "") }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    static func nextWeeklyDueDate(from dueDate: String?, today: Date = Date()) -> String {
        let base = dueDate.flatMap(Self.date(from:)) ?? today
        let next = Calendar(identifier: .gregorian).date(byAdding: .day, value: 7, to: base) ?? today
        return dateKey(from: next)
    }

    static func date(from key: String) -> Date? {
        dateFormatter.date(from: key)
    }

    static func dateKey(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static func startOfDay(_ date: Date) -> Date {
        Calendar(identifier: .gregorian).startOfDay(for: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
