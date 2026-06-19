import Foundation
#if canImport(FamilyControls)
import FamilyControls
#endif
import UIKit

/// iOS equivalent of Android DeviceUsageRepository.
/// iOS does not let a normal app query whole-device screen time directly.
/// This tracks MissionZebra foreground usage and exposes FamilyControls
/// authorization when the entitlement is present.
class DeviceUsageRepository: ObservableObject {
    enum UsageSource {
        case deviceActivity
        case appForegroundFallback
        case unavailable

        var rawValue: String {
            switch self {
            case .deviceActivity: return "DEVICE_ACTIVITY"
            case .appForegroundFallback: return "APP_FOREGROUND_FALLBACK"
            case .unavailable: return "UNAVAILABLE"
            }
        }
    }

    struct UsageSnapshot {
        let minutes: Int
        let source: UsageSource

        var isWholeDeviceScreenTime: Bool {
            source == .deviceActivity
        }
    }

    private let defaults: UserDefaults
    private let deviceActivityCoordinator: DeviceActivityCoordinator
    private let activeStartKey = "active_start_millis"
    private let dailyUsagePrefix = "daily_usage_minutes_"

    init(
        defaults: UserDefaults = MissionZebraAppGroup.defaults,
        deviceActivityCoordinator: DeviceActivityCoordinator = .shared
    ) {
        self.defaults = defaults
        self.deviceActivityCoordinator = deviceActivityCoordinator

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.markActive() }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.flushActiveSession() }
    }

    /// Check if the app has usage stats permission
    /// On iOS, this checks FamilyControls authorization
    func hasUsagePermission() -> Bool {
        #if canImport(FamilyControls)
        return AuthorizationCenter.shared.authorizationStatus == .approved
        #else
        return false
        #endif
    }

    var usageSource: UsageSource {
        #if canImport(FamilyControls)
        if deviceActivityCoordinator.hasDeviceActivityDataToday() {
            return .deviceActivity
        }
        return hasUsagePermission() ? .appForegroundFallback : .appForegroundFallback
        #else
        return .unavailable
        #endif
    }

    /// Returns whole-device Screen Time only when DeviceActivity data is available.
    /// Otherwise this is a labeled MissionZebra foreground fallback, not full device usage.
    func getTodayScreenTimeMinutes() async -> Int {
        let snapshot = await getTodayUsageSnapshot()
        return snapshot.minutes
    }

    func getTodayUsageSnapshot() async -> UsageSnapshot {
        flushActiveSession()
        let today = Date()
        let deviceActivityMinutes = deviceActivityCoordinator.currentDeviceActivityMinutes(date: today)
        if hasUsagePermission(), deviceActivityCoordinator.hasDeviceActivityDataToday(date: today) {
            return UsageSnapshot(minutes: deviceActivityMinutes, source: .deviceActivity)
        }

        let fallbackMinutes = defaults.integer(forKey: dailyUsageKey(for: today))
        return UsageSnapshot(minutes: fallbackMinutes, source: fallbackMinutes > 0 ? .appForegroundFallback : usageSource)
    }

    private func markActive() {
        defaults.set(Date().timeIntervalSince1970 * 1000, forKey: activeStartKey)
    }

    private func flushActiveSession() {
        let startedAt = defaults.double(forKey: activeStartKey)
        guard startedAt > 0 else { return }

        let start = Date(timeIntervalSince1970: startedAt / 1000)
        let now = Date()
        guard now > start else { return }

        let minutes = max(0, Int(now.timeIntervalSince(start) / 60))
        if minutes > 0 {
            let key = dailyUsageKey(for: now)
            defaults.set(defaults.integer(forKey: key) + minutes, forKey: key)
            defaults.set(now.timeIntervalSince1970 * 1000, forKey: activeStartKey)
        }
    }

    private func dailyUsageKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return dailyUsagePrefix + formatter.string(from: date)
    }

    func startDeviceActivityMonitoringIfPossible() async -> DeviceActivityAvailability {
        let availability = deviceActivityCoordinator.availability()
        guard availability == .available else { return availability }
        do {
            try deviceActivityCoordinator.startDailyMonitoring()
            return .available
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }
}
