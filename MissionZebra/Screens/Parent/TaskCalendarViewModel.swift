import Foundation
import Combine

class TaskCalendarViewModel: ObservableObject {
    private let tasksRepository: TaskFirebaseRepository
    private var cancellables = Set<AnyCancellable>()

    /// selected date by user (nil means no date selected)
    @Published var selectedDate: Date? = nil

    @Published private(set) var tasksPerDay: [String: Int] = [:] // ISO date -> count
    @Published private(set) var tasksForSelectedDate: [MZTask] = []

    private var tasks: [MZTask] = [] {
        didSet { computeMaps() }
    }

    init(tasksRepository: TaskFirebaseRepository = TaskFirebaseRepository()) {
        self.tasksRepository = tasksRepository
        subscribe()
    }

    private func subscribe() {
        tasksRepository.tasksFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.tasks = tasks
            }
            .store(in: &cancellables)

        $selectedDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                self?.computeTasksForSelected(date)
            }
            .store(in: &cancellables)
    }

    private func computeMaps() {
        var map: [String: Int] = [:]
        let calendar = Calendar.current
        let now = Date()
        guard let endDate = calendar.date(byAdding: .month, value: 6, to: now) else { return }

        func iso(_ d: Date) -> String {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: d)
        }

        for task in tasks {
            // dueDate stored as ISO string
            guard let due = task.dueDate,
                  let dueDate = isoDate(from: due) else { continue }
            if task.recurrence != nil, task.recurrence == "WEEKLY" {
                var current = dueDate
                while current <= endDate {
                    let key = iso(current)
                    map[key] = (map[key] ?? 0) + 1
                    current = calendar.date(byAdding: .weekOfYear, value: 1, to: current) ?? current
                }
            } else {
                let key = iso(dueDate)
                map[key] = (map[key] ?? 0) + 1
            }
        }
        tasksPerDay = map
        computeTasksForSelected(selectedDate)
    }

    private func computeTasksForSelected(_ date: Date?) {
        guard let date = date else {
            tasksForSelectedDate = []
            return
        }
        let isoKey = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: date)
        }()

        let filtered = tasks.filter { task in
            guard let due = task.dueDate, let dueDate = isoDate(from: due) else { return false }
            if task.recurrence == "WEEKLY" {
                if date < dueDate { return false }
                let days = Calendar.current.dateComponents([.day], from: dueDate, to: date).day ?? 0
                return days % 7 == 0
            } else {
                return due == isoKey
            }
        }
        tasksForSelectedDate = filtered
    }

    private func isoDate(from string: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: string)
    }

    func selectDate(_ date: Date) {
        if let sel = selectedDate, Calendar.current.isDate(sel, inSameDayAs: date) {
            selectedDate = nil
        } else {
            selectedDate = date
        }
    }
}
