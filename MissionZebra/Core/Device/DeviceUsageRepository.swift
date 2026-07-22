import Foundation
#if canImport(FamilyControls)
import FamilyControls
#endif

/// iOS equivalent of Android DeviceUsageRepository.
/// iOS does not let a normal app query whole-device screen time directly.
/// This exposes only real Screen Time data from FamilyControls/DeviceActivity.
class DeviceUsageRepository: ObservableObject {
    enum UsageSource {
        case deviceActivity
        case unavailable

        var rawValue: String {
            switch self {
            case .deviceActivity: return "DEVICE_ACTIVITY"
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

        func replacingMinutes(_ minutes: Int) -> UsageSnapshot {
            UsageSnapshot(minutes: max(minutes, 0), source: source)
        }
    }

    private let deviceActivityCoordinator: DeviceActivityCoordinator

    init(deviceActivityCoordinator: DeviceActivityCoordinator = .shared) {
        self.deviceActivityCoordinator = deviceActivityCoordinator
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
        return .unavailable
        #else
        return .unavailable
        #endif
    }

    func screenTimeAvailability() -> DeviceActivityAvailability {
        deviceActivityCoordinator.availability()
    }

    /// Returns whole-device Screen Time only when DeviceActivity data is available.
    /// Otherwise returns 0; MissionZebra does not use app-open time as fake Screen Time.
    func getTodayScreenTimeMinutes() async -> Int {
        let snapshot = await getTodayUsageSnapshot()
        return snapshot.minutes
    }

    func getTodayUsageSnapshot() async -> UsageSnapshot {
        let today = Date()
        let deviceActivityMinutes = deviceActivityCoordinator.currentDeviceActivityMinutes(date: today)
        if hasUsagePermission(), deviceActivityCoordinator.hasDeviceActivityDataToday(date: today) {
            return UsageSnapshot(minutes: deviceActivityMinutes, source: .deviceActivity)
        }

        return UsageSnapshot(minutes: 0, source: .unavailable)
    }

    func currentDeviceActivityTotalMinutes(date: Date = Date()) -> Int {
        deviceActivityCoordinator.currentDeviceActivityMinutes(date: date)
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

public final class ChildScreenTimeAttribution {
    static let shared = ChildScreenTimeAttribution(
        defaults: MissionZebraAppGroup.defaults,
        deviceIdProvider: { SessionManager.shared.getDeviceId() }
    )

    private let defaults: UserDefaults
    private let deviceIdProvider: () -> String

    public init(
        defaults: UserDefaults,
        deviceIdProvider: @escaping () -> String
    ) {
        self.defaults = defaults
        self.deviceIdProvider = deviceIdProvider
    }

    public func startSession(childId: String, rawDeviceMinutes: Int, date: Date = Date()) {
        let dateKey = MissionZebraDeviceActivityShared.dateKey(for: date)
        if activeChildId == childId, activeDateKey == dateKey {
            return
        }

        activeChildId = childId
        activeDateKey = dateKey
        sessionBaselineMinutes = max(rawDeviceMinutes, 0)
        sessionStartAccruedMinutes = accruedMinutes(childId: childId, dateKey: dateKey)
    }

    public func attributedMinutes(childId: String, rawDeviceMinutes: Int, date: Date = Date()) -> Int {
        let dateKey = MissionZebraDeviceActivityShared.dateKey(for: date)
        if activeChildId != childId || activeDateKey != dateKey {
            startSession(childId: childId, rawDeviceMinutes: rawDeviceMinutes, date: date)
        }

        let sessionDelta = max(rawDeviceMinutes - sessionBaselineMinutes, 0)
        let total = max(sessionStartAccruedMinutes + sessionDelta, accruedMinutes(childId: childId, dateKey: dateKey))
        setAccruedMinutes(total, childId: childId, dateKey: dateKey)
        return total
    }

    public func endSession(childId: String, rawDeviceMinutes: Int, date: Date = Date()) -> Int {
        let total = attributedMinutes(childId: childId, rawDeviceMinutes: rawDeviceMinutes, date: date)
        if activeChildId == childId {
            clearActiveSession()
        }
        return total
    }

    private var deviceId: String {
        deviceIdProvider()
    }

    private var activeChildId: String? {
        get { defaults.string(forKey: key("activeChildId")) }
        set { defaults.setOrRemove(newValue, forKey: key("activeChildId")) }
    }

    private var activeDateKey: String? {
        get { defaults.string(forKey: key("activeDateKey")) }
        set { defaults.setOrRemove(newValue, forKey: key("activeDateKey")) }
    }

    private var sessionBaselineMinutes: Int {
        get { defaults.integer(forKey: key("sessionBaselineMinutes")) }
        set { defaults.set(max(newValue, 0), forKey: key("sessionBaselineMinutes")) }
    }

    private var sessionStartAccruedMinutes: Int {
        get { defaults.integer(forKey: key("sessionStartAccruedMinutes")) }
        set { defaults.set(max(newValue, 0), forKey: key("sessionStartAccruedMinutes")) }
    }

    private func accruedMinutes(childId: String, dateKey: String) -> Int {
        defaults.integer(forKey: accruedKey(childId: childId, dateKey: dateKey))
    }

    private func setAccruedMinutes(_ minutes: Int, childId: String, dateKey: String) {
        defaults.set(max(minutes, 0), forKey: accruedKey(childId: childId, dateKey: dateKey))
    }

    private func clearActiveSession() {
        activeChildId = nil
        activeDateKey = nil
        defaults.removeObject(forKey: key("sessionBaselineMinutes"))
        defaults.removeObject(forKey: key("sessionStartAccruedMinutes"))
    }

    private func key(_ suffix: String) -> String {
        "missionzebra.childScreenTimeAttribution.\(safe(deviceId)).\(suffix)"
    }

    private func accruedKey(childId: String, dateKey: String) -> String {
        "missionzebra.childScreenTimeAttribution.\(safe(deviceId)).\(safe(childId)).\(dateKey).accruedMinutes"
    }

    private func safe(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
    }
}

private extension UserDefaults {
    func setOrRemove(_ value: String?, forKey key: String) {
        if let value {
            set(value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}
