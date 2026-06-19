import EventKit
import FirebaseAuth
import Foundation

struct TaskCalendarDestination: Identifiable, Equatable {
    let id: String
    let title: String
}

final class TaskCalendarSyncManager {
    private let eventStore = EKEventStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isConnected: Bool {
        connectedCalendarId != nil
    }

    var connectedCalendarId: String? {
        defaults.string(forKey: connectedCalendarKey)
    }

    func requestAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .authorized {
            return true
        }
        if #available(iOS 17.0, *), status == .fullAccess {
            return true
        }
        if #available(iOS 17.0, *), status == .writeOnly {
            return false
        }

        switch status {
        case .notDetermined:
            do {
                if #available(iOS 17.0, *) {
                    return try await eventStore.requestFullAccessToEvents()
                } else {
                    return try await withCheckedThrowingContinuation { continuation in
                        eventStore.requestAccess(to: .event) { granted, error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: granted)
                            }
                        }
                    }
                }
            } catch {
                return false
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func availableCalendars() async -> [TaskCalendarDestination] {
        guard await requestAccessIfNeeded() else { return [] }
        return eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map { TaskCalendarDestination(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func connect(calendarId: String) {
        defaults.set(calendarId, forKey: connectedCalendarKey)
    }

    func disconnect() {
        removeSyncedEvents()
        defaults.removeObject(forKey: connectedCalendarKey)
        defaults.removeObject(forKey: eventIdsKey)
    }

    func sync(tasks: [MZTask]) async throws -> Int {
        guard await requestAccessIfNeeded() else {
            throw NSError(domain: "MissionZebraCalendar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geen toegang tot agenda."])
        }
        guard let calendarId = connectedCalendarId,
              let calendar = eventStore.calendar(withIdentifier: calendarId) else {
            defaults.removeObject(forKey: connectedCalendarKey)
            throw NSError(domain: "MissionZebraCalendar", code: -2, userInfo: [NSLocalizedDescriptionKey: "Kies eerst een agenda."])
        }

        var storedEventIds = loadStoredEventIds()
        let occurrences = Self.occurrences(for: tasks)
        var activeKeys = Set<String>()

        for occurrence in occurrences {
            activeKeys.insert(occurrence.key)
            let event: EKEvent
            if let eventId = storedEventIds[occurrence.key],
               let existing = eventStore.event(withIdentifier: eventId) {
                event = existing
            } else {
                event = EKEvent(eventStore: eventStore)
            }

            event.calendar = calendar
            event.title = occurrence.task.title
            event.notes = Self.notes(for: occurrence.task)
            event.isAllDay = true
            event.startDate = occurrence.date
            event.endDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: occurrence.date) ?? occurrence.date
            try eventStore.save(event, span: .thisEvent, commit: false)
            storedEventIds[occurrence.key] = event.eventIdentifier
        }

        for (key, eventId) in storedEventIds where !activeKeys.contains(key) {
            if let event = eventStore.event(withIdentifier: eventId) {
                try eventStore.remove(event, span: .thisEvent, commit: false)
            }
            storedEventIds.removeValue(forKey: key)
        }

        try eventStore.commit()
        saveStoredEventIds(storedEventIds)
        return occurrences.count
    }

    private func removeSyncedEvents() {
        guard let _ = connectedCalendarId else { return }
        let storedEventIds = loadStoredEventIds()
        guard !storedEventIds.isEmpty else { return }

        for eventId in storedEventIds.values {
            if let event = eventStore.event(withIdentifier: eventId) {
                try? eventStore.remove(event, span: .thisEvent, commit: false)
            }
        }
        try? eventStore.commit()
    }

    static func occurrences(for tasks: [MZTask], now: Date = Date()) -> [(key: String, task: MZTask, date: Date)] {
        let calendar = Calendar(identifier: .gregorian)
        let endDate = calendar.date(byAdding: .month, value: 6, to: now) ?? now

        return tasks.flatMap { task -> [(String, MZTask, Date)] in
            guard !task.completed,
                  let dueDateKey = task.dueDate,
                  let dueDate = TaskOrdering.date(from: dueDateKey) else {
                return []
            }

            if task.recurrence == MZTask.recurrenceWeekly {
                var dates: [(String, MZTask, Date)] = []
                var current = dueDate
                while current <= endDate {
                    let keyDate = TaskOrdering.dateKey(from: current)
                    dates.append(("\(task.id)-\(keyDate)", task, current))
                    guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
                    current = next
                }
                return dates
            }

            return [("\(task.id)-\(dueDateKey)", task, dueDate)]
        }
    }

    private static func notes(for task: MZTask) -> String {
        [
            task.purpose.isEmpty ? nil : "Doel: \(task.purpose)",
            task.contributionTarget.isEmpty ? nil : "Bijdrage: \(task.contributionTarget)",
            "Punten: \(task.points)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private var connectedCalendarKey: String {
        "missionzebra.calendar.connected.\(Auth.auth().currentUser?.uid ?? "anonymous")"
    }

    private var eventIdsKey: String {
        "missionzebra.calendar.eventIds.\(Auth.auth().currentUser?.uid ?? "anonymous")"
    }

    private func loadStoredEventIds() -> [String: String] {
        guard let data = defaults.data(forKey: eventIdsKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveStoredEventIds(_ ids: [String: String]) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        defaults.set(data, forKey: eventIdsKey)
    }
}
