import Foundation
import Combine

class TaskCalendarViewModel: ObservableObject {
    private let tasksRepository: TaskFirebaseRepository
    private let premiumRepository: PremiumRepository
    private let calendarSyncManager: TaskCalendarSyncManager
    private var cancellables = Set<AnyCancellable>()
    private var autoSyncWorkItem: DispatchWorkItem?

    /// selected date by user (nil means no date selected)
    @Published var selectedDate: Date? = nil

    @Published private(set) var tasksPerDay: [String: Int] = [:] // ISO date -> count
    @Published private(set) var tasksForSelectedDate: [MZTask] = []
    @Published private(set) var premiumStatus = PremiumStatus()
    @Published private(set) var availableCalendars: [TaskCalendarDestination] = []
    @Published private(set) var connectedCalendarId: String?
    @Published private(set) var isCalendarConnected = false
    @Published private(set) var isSyncingCalendar = false
    @Published private(set) var calendarMessage: String?
    @Published private(set) var calendarError: String?

    private var tasks: [MZTask] = [] {
        didSet { computeMaps() }
    }

    init(
        tasksRepository: TaskFirebaseRepository = TaskFirebaseRepository(),
        premiumRepository: PremiumRepository = PremiumRepository(),
        calendarSyncManager: TaskCalendarSyncManager = TaskCalendarSyncManager()
    ) {
        self.tasksRepository = tasksRepository
        self.premiumRepository = premiumRepository
        self.calendarSyncManager = calendarSyncManager
        self.connectedCalendarId = calendarSyncManager.connectedCalendarId
        self.isCalendarConnected = calendarSyncManager.isConnected
        subscribe()
    }

    private func subscribe() {
        tasksRepository.tasksFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.tasks = tasks
                self?.scheduleAutoSync(reason: "tasksChanged")
            }
            .store(in: &cancellables)

        premiumRepository.premiumStatusFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.premiumStatus = status
                if status.isPremium {
                    self?.refreshCalendars()
                    self?.scheduleAutoSync(reason: "premiumEnabled")
                }
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

    func refreshCalendars() {
        guard premiumStatus.isPremium else { return }
        Task {
            let calendars = await calendarSyncManager.availableCalendars()
            await MainActor.run {
                availableCalendars = calendars
                connectedCalendarId = calendarSyncManager.connectedCalendarId
                isCalendarConnected = calendarSyncManager.isConnected
            }
        }
    }

    func connectCalendar(calendarId: String) {
        guard premiumStatus.isPremium else {
            calendarError = "Kalender-sync is een premium functie."
            return
        }
        calendarSyncManager.connect(calendarId: calendarId)
        connectedCalendarId = calendarId
        isCalendarConnected = true
        calendarMessage = "Agenda gekoppeld."
        calendarError = nil
        scheduleAutoSync(reason: "calendarConnected", delay: 0.1)
    }

    func disconnectCalendar() {
        calendarSyncManager.disconnect()
        connectedCalendarId = nil
        isCalendarConnected = false
        calendarMessage = "Agenda losgekoppeld."
        calendarError = nil
    }

    func syncNow() {
        guard premiumStatus.isPremium else {
            calendarError = "Kalender-sync is een premium functie."
            return
        }
        isSyncingCalendar = true
        calendarError = nil
        calendarMessage = nil
        Task {
            do {
                let count = try await calendarSyncManager.sync(tasks: tasks)
                await MainActor.run {
                    isSyncingCalendar = false
                    calendarMessage = "\(count) taakmomenten gesynchroniseerd."
                    connectedCalendarId = calendarSyncManager.connectedCalendarId
                    isCalendarConnected = calendarSyncManager.isConnected
                }
            } catch {
                await MainActor.run {
                    isSyncingCalendar = false
                    calendarError = error.localizedDescription
                    connectedCalendarId = calendarSyncManager.connectedCalendarId
                    isCalendarConnected = calendarSyncManager.isConnected
                }
            }
        }
    }

    private func scheduleAutoSync(reason: String, delay: TimeInterval = 1.0) {
        guard premiumStatus.isPremium, calendarSyncManager.isConnected, !tasks.isEmpty else { return }

        autoSyncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.runAutoSync(reason: reason)
        }
        autoSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func runAutoSync(reason: String) {
        guard premiumStatus.isPremium, calendarSyncManager.isConnected else { return }
        Task {
            do {
                let count = try await calendarSyncManager.sync(tasks: tasks)
                await MainActor.run {
                    calendarMessage = "Kalender automatisch bijgewerkt (\(count) taakmomenten)."
                    calendarError = nil
                    connectedCalendarId = calendarSyncManager.connectedCalendarId
                    isCalendarConnected = calendarSyncManager.isConnected
                }
            } catch {
                await MainActor.run {
                    calendarError = error.localizedDescription
                    connectedCalendarId = calendarSyncManager.connectedCalendarId
                    isCalendarConnected = calendarSyncManager.isConnected
                }
            }
        }
    }
}
