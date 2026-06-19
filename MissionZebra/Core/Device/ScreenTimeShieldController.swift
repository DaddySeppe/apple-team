import Foundation

#if canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif

enum ScreenTimeShieldReason: String, Equatable {
    case none
    case parentBlocked
    case limitExceeded
    case bedtime
    case focus

    var message: String {
        switch self {
        case .none:
            return ""
        case .parentBlocked:
            return "Dit kind is door de ouder geblokkeerd."
        case .limitExceeded:
            return "De schermtijdlimiet is bereikt."
        case .bedtime:
            return "Bedtijdblok is actief."
        case .focus:
            return "Focustijd is actief."
        }
    }
}

final class ScreenTimeShieldController {
    static let shared = ScreenTimeShieldController()

    private let defaults: UserDefaults

    #if canImport(ManagedSettings)
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("MissionZebra"))
    #endif

    init(defaults: UserDefaults = MissionZebraAppGroup.defaults) {
        self.defaults = defaults
    }

    func updateShield(for child: Child?, now: Date = Date()) {
        guard let child else {
            clearShield()
            return
        }

        let reason = shieldReason(for: child, now: now)
        guard reason != .none else {
            clearShield()
            return
        }

        applyShield(reason: reason)
    }

    func clearShield() {
        defaults.removeObject(forKey: MissionZebraDeviceActivityShared.shieldReasonKey)
        #if canImport(ManagedSettings)
        store.clearAllSettings()
        #endif
    }

    func shieldReason(for child: Child, now: Date = Date()) -> ScreenTimeShieldReason {
        if child.isBlocked { return .parentBlocked }
        if child.dailyScreenTimeLimitMinutes > 0 && child.dailyScreenTimeUsedMinutes >= child.dailyScreenTimeLimitMinutes {
            return .limitExceeded
        }
        if child.screenTimeSchedule.bedtimeBlockEnabled && isHour(now, insideStart: child.screenTimeSchedule.bedtimeStartHour, end: child.screenTimeSchedule.bedtimeEndHour) {
            return .bedtime
        }
        if child.screenTimeSchedule.focusBlockEnabled && isHour(now, insideStart: child.screenTimeSchedule.focusStartHour, end: child.screenTimeSchedule.focusEndHour) {
            return .focus
        }
        return .none
    }

    private func applyShield(reason: ScreenTimeShieldReason) {
        defaults.set(reason.rawValue, forKey: MissionZebraDeviceActivityShared.shieldReasonKey)
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        guard let selection = DeviceActivityCoordinator.shared.loadSelection(), !selection.isEmpty else {
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        #endif
    }

    private func isHour(_ date: Date, insideStart startHour: Int, end endHour: Int) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if startHour == endHour { return true }
        if startHour < endHour {
            return hour >= startHour && hour < endHour
        }
        return hour >= startHour || hour < endHour
    }
}

#if canImport(FamilyControls)
extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }
}
#endif
