import Foundation

enum MissionZebraAppGroup {
    static let suiteName = "group.be.missionzebra.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

enum MissionZebraDeviceActivityShared {
    static let activityName = "missionzebra.daily"
    static let usageEventPrefix = "usage."
    static let selectionDataKey = "missionzebra.familyActivitySelection"
    static let lastThresholdMinutesKey = "missionzebra.deviceActivity.lastThresholdMinutes"
    static let lastEventDateKey = "missionzebra.deviceActivity.lastEventDate"
    static let lastEventAtKey = "missionzebra.deviceActivity.lastEventAt"
    static let permissionFallbackReasonKey = "missionzebra.deviceActivity.fallbackReason"
    static let monitorStartedAtKey = "missionzebra.deviceActivity.monitorStartedAt"
    static let shieldReasonKey = "missionzebra.managedSettings.shieldReason"

    static func dateKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func deviceActivityUsageKey(for date: Date = Date()) -> String {
        "device_activity_minutes_\(dateKey(for: date))"
    }

    static func safetySnapshotKey(for date: Date = Date()) -> String {
        "safety_snapshot_\(dateKey(for: date))"
    }

    static func eventName(for minutes: Int) -> String {
        "\(usageEventPrefix)\(minutes)"
    }

    static func minutes(fromEventName name: String) -> Int? {
        guard name.hasPrefix(usageEventPrefix) else { return nil }
        return Int(name.dropFirst(usageEventPrefix.count))
    }
}
