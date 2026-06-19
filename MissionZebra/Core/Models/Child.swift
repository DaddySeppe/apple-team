import Foundation

struct Child: Identifiable, Codable, Equatable {
    var id: String = ""
    var name: String = ""
    var birthDate: String? = nil // "yyyy-MM-dd"
    var points: Int = 0
    var dailyScreenTimeUsedMinutes: Int = 0
    var dailyScreenTimeLimitMinutes: Int = 60
    var isBlocked: Bool = false

    var purchasedAccessoryIds: [String] = []
    var equippedAccessoryId: String? = nil
    var equippedItems: [String: String] = [:]

    var streak: Int = 0
    var lastStreakCheckDate: String? = nil // "YYYY-MM-DD"

    var motivationalMessage: String? = nil

    var screenTimeHistory: [String: Int] = [:]
    var deviceScreenTimes: [String: Int] = [:]
    var deviceNames: [String: String] = [:]
    var deviceScreenTimeDates: [String: String] = [:]
    var screenTimeSchedule: ScreenTimeSchedule = ScreenTimeSchedule()
    var screenTimePermissionGranted: Bool? = nil
}

struct ScreenTimeSchedule: Codable, Equatable {
    var enabled: Bool = false
    var schoolDayLimitMinutes: Int = 60
    var weekendLimitMinutes: Int = 90
    var vacationModeEnabled: Bool = false
    var vacationLimitMinutes: Int = 120
    var bedtimeBlockEnabled: Bool = false
    var bedtimeStartHour: Int = 20
    var bedtimeEndHour: Int = 7
    var focusBlockEnabled: Bool = false
    var focusStartHour: Int = 17
    var focusEndHour: Int = 18

    func effectiveLimitMinutes(defaultLimitMinutes: Int, calendar: Calendar = .current, date: Date = Date()) -> Int {
        guard enabled else { return defaultLimitMinutes }
        if vacationModeEnabled {
            return max(vacationLimitMinutes, 1)
        }

        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return max(weekendLimitMinutes, 1)
        }
        return max(schoolDayLimitMinutes, 1)
    }

    func toFirestoreMap() -> [String: Any] {
        [
            "enabled": enabled,
            "schoolDayLimitMinutes": schoolDayLimitMinutes,
            "weekendLimitMinutes": weekendLimitMinutes,
            "vacationModeEnabled": vacationModeEnabled,
            "vacationLimitMinutes": vacationLimitMinutes,
            "bedtimeBlockEnabled": bedtimeBlockEnabled,
            "bedtimeStartHour": bedtimeStartHour,
            "bedtimeEndHour": bedtimeEndHour,
            "focusBlockEnabled": focusBlockEnabled,
            "focusStartHour": focusStartHour,
            "focusEndHour": focusEndHour
        ]
    }

    static func fromFirestore(_ value: Any?) -> ScreenTimeSchedule {
        guard let raw = FirestoreDecoding.rawMap(value) else {
            return ScreenTimeSchedule()
        }

        return ScreenTimeSchedule(
            enabled: FirestoreDecoding.bool(raw["enabled"]),
            schoolDayLimitMinutes: FirestoreDecoding.int(raw["schoolDayLimitMinutes"], default: 60),
            weekendLimitMinutes: FirestoreDecoding.int(raw["weekendLimitMinutes"], default: 90),
            vacationModeEnabled: FirestoreDecoding.bool(raw["vacationModeEnabled"]),
            vacationLimitMinutes: FirestoreDecoding.int(raw["vacationLimitMinutes"], default: 120),
            bedtimeBlockEnabled: FirestoreDecoding.bool(raw["bedtimeBlockEnabled"]),
            bedtimeStartHour: FirestoreDecoding.int(raw["bedtimeStartHour"], default: 20),
            bedtimeEndHour: FirestoreDecoding.int(raw["bedtimeEndHour"], default: 7),
            focusBlockEnabled: FirestoreDecoding.bool(raw["focusBlockEnabled"]),
            focusStartHour: FirestoreDecoding.int(raw["focusStartHour"], default: 17),
            focusEndHour: FirestoreDecoding.int(raw["focusEndHour"], default: 18)
        )
    }
}

enum ChildScreenTimeStatus {
    case ok
    case nearLimit
    case overLimit
    case blocked
    case notTracked
}

extension Child {
    var age: Int {
        guard let birthDate else { return 0 }
        let parts = birthDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return 0
        }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let currentDay = calendar.component(.day, from: now)

        var age = currentYear - year
        let monthDiff = currentMonth - month
        if monthDiff < 0 || (monthDiff == 0 && currentDay < day) {
            age -= 1
        }
        return max(age, 0)
    }

    var screenTimeStatus: ChildScreenTimeStatus {
        if isBlocked { return .blocked }
        if screenTimePermissionGranted == false { return .notTracked }
        if dailyScreenTimeLimitMinutes <= 0 { return .ok }

        let ratio = Float(dailyScreenTimeUsedMinutes) / Float(dailyScreenTimeLimitMinutes)
        if ratio >= 1 { return .overLimit }
        if ratio >= 0.8 { return .nearLimit }
        return .ok
    }

    static func aggregatedDailyScreenTime(
        storedUsedMinutes: Int,
        deviceScreenTimes: [String: Int],
        deviceScreenTimeDates: [String: String],
        todayKey: String
    ) -> Int {
        guard !deviceScreenTimes.isEmpty else { return storedUsedMinutes }
        if deviceScreenTimeDates.isEmpty {
            return deviceScreenTimes.values.reduce(0, +)
        }
        return deviceScreenTimes.reduce(0) { total, entry in
            deviceScreenTimeDates[entry.key] == todayKey ? total + entry.value : total
        }
    }
}
