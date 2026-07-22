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
    private static let scheduleVersion = "daily-thresholds-v3"

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
        let selectionSignature = try Self.selectionSignature(for: selection)
        if defaults.string(forKey: MissionZebraDeviceActivityShared.monitorSelectionSignatureKey) == selectionSignature,
           defaults.string(forKey: MissionZebraDeviceActivityShared.monitorScheduleVersionKey) == Self.scheduleVersion {
            defaults.removeObject(forKey: MissionZebraDeviceActivityShared.permissionFallbackReasonKey)
            return
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

        let activityName = DeviceActivityName(MissionZebraDeviceActivityShared.activityName)
        let center = DeviceActivityCenter()
        center.stopMonitoring([activityName])
        try center.startMonitoring(
            activityName,
            during: schedule,
            events: events
        )
        defaults.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: MissionZebraDeviceActivityShared.monitorStartedAtKey)
        defaults.set(selectionSignature, forKey: MissionZebraDeviceActivityShared.monitorSelectionSignatureKey)
        defaults.set(Self.scheduleVersion, forKey: MissionZebraDeviceActivityShared.monitorScheduleVersionKey)
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

    private static func selectionSignature(for selection: FamilyActivitySelection) throws -> String {
        let encoder = JSONEncoder()

        func encodedTokens<Token: Encodable>(_ tokens: Set<Token>) throws -> String {
            try tokens
                .map { try encoder.encode($0).base64EncodedString() }
                .sorted()
                .joined(separator: ",")
        }

        return [
            "apps:\(try encodedTokens(selection.applicationTokens))",
            "categories:\(try encodedTokens(selection.categoryTokens))",
            "webDomains:\(try encodedTokens(selection.webDomainTokens))"
        ].joined(separator: "|")
    }
    #endif

    func currentDeviceActivityMinutes(date: Date = Date()) -> Int {
        defaults.integer(forKey: MissionZebraDeviceActivityShared.deviceActivityUsageKey(for: date))
    }

    func hasDeviceActivityDataToday(date: Date = Date()) -> Bool {
        currentDeviceActivityMinutes(date: date) > 0 &&
            defaults.string(forKey: MissionZebraDeviceActivityShared.lastEventDateKey) == MissionZebraDeviceActivityShared.dateKey(for: date)
    }

    static let thresholdMinutes: [Int] = {
        let perMinute = Array(1...180)
        let longerSessions = stride(from: 185, through: 480, by: 5)
        return Array(Set(perMinute + Array(longerSessions))).sorted()
    }()
}
