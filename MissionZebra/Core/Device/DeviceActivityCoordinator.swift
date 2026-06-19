import Foundation

#if canImport(DeviceActivity) && canImport(FamilyControls)
import DeviceActivity
import FamilyControls
#endif

enum DeviceActivityAvailability: Equatable {
    case available
    case missingAuthorization
    case missingSelection
    case unavailable(String)

    var userMessage: String {
        switch self {
        case .available:
            return "Screen Time is actief."
        case .missingAuthorization:
            return "Screen Time-toegang ontbreekt. Geef toestemming via de ouderinstellingen op dit toestel."
        case .missingSelection:
            return "Kies eerst apps of categorieën om echte Screen Time te meten."
        case .unavailable(let reason):
            return reason
        }
    }
}

final class DeviceActivityCoordinator {
    static let shared = DeviceActivityCoordinator()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = MissionZebraAppGroup.defaults) {
        self.defaults = defaults
    }

    func availability() -> DeviceActivityAvailability {
        #if canImport(DeviceActivity) && canImport(FamilyControls)
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            defaults.set("missingAuthorization", forKey: MissionZebraDeviceActivityShared.permissionFallbackReasonKey)
            return .missingAuthorization
        }
        guard loadSelection()?.isEmpty == false else {
            defaults.set("missingSelection", forKey: MissionZebraDeviceActivityShared.permissionFallbackReasonKey)
            return .missingSelection
        }
        return .available
        #else
        let reason = "Screen Time APIs zijn niet beschikbaar op dit platform."
        defaults.set(reason, forKey: MissionZebraDeviceActivityShared.permissionFallbackReasonKey)
        return .unavailable(reason)
        #endif
    }

    func startDailyMonitoring() throws {
        #if canImport(DeviceActivity) && canImport(FamilyControls)
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            throw NSError(
                domain: "MissionZebraDeviceActivity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: DeviceActivityAvailability.missingAuthorization.userMessage]
            )
        }
        guard let selection = loadSelection(), !selection.isEmpty else {
            throw NSError(
                domain: "MissionZebraDeviceActivity",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: DeviceActivityAvailability.missingSelection.userMessage]
            )
        }

        let events = Self.thresholdMinutes.reduce(into: [DeviceActivityEvent.Name: DeviceActivityEvent]()) { result, minutes in
            result[DeviceActivityEvent.Name(MissionZebraDeviceActivityShared.eventName(for: minutes))] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes)
            )
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        try DeviceActivityCenter().startMonitoring(
            DeviceActivityName(MissionZebraDeviceActivityShared.activityName),
            during: schedule,
            events: events
        )
        defaults.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: MissionZebraDeviceActivityShared.monitorStartedAtKey)
        defaults.removeObject(forKey: MissionZebraDeviceActivityShared.permissionFallbackReasonKey)
        #else
        throw NSError(
            domain: "MissionZebraDeviceActivity",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: DeviceActivityAvailability.unavailable("Screen Time APIs zijn niet beschikbaar op dit platform.").userMessage]
        )
        #endif
    }

    func stopDailyMonitoring() {
        #if canImport(DeviceActivity)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(MissionZebraDeviceActivityShared.activityName)])
        #endif
    }

    #if canImport(FamilyControls)
    func saveSelection(_ selection: FamilyActivitySelection) throws {
        let data = try JSONEncoder().encode(selection)
        defaults.set(data, forKey: MissionZebraDeviceActivityShared.selectionDataKey)
    }

    func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: MissionZebraDeviceActivityShared.selectionDataKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
    #endif

    func currentDeviceActivityMinutes(date: Date = Date()) -> Int {
        defaults.integer(forKey: MissionZebraDeviceActivityShared.deviceActivityUsageKey(for: date))
    }

    func hasDeviceActivityDataToday(date: Date = Date()) -> Bool {
        currentDeviceActivityMinutes(date: date) > 0 &&
            defaults.string(forKey: MissionZebraDeviceActivityShared.lastEventDateKey) == MissionZebraDeviceActivityShared.dateKey(for: date)
    }

    static let thresholdMinutes = [5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480]
}
