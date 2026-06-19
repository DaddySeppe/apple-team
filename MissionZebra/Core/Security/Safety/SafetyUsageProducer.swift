import Foundation

struct SafetyUsageProducer {
    private let safetyRepository: SafetyRepository

    init(safetyRepository: SafetyRepository = SafetyRepository()) {
        self.safetyRepository = safetyRepository
    }

    func uploadDeviceActivitySnapshot(
        childId: String,
        usageSnapshot: DeviceUsageRepository.UsageSnapshot,
        date: Date = Date()
    ) async -> Result<Void, Error> {
        guard usageSnapshot.isWholeDeviceScreenTime else {
            return .success(())
        }

        let deviceSession = SessionManager.shared.getDeviceSession()
        let snapshot = SafetyUsageSnapshot(
            childId: childId,
            deviceId: deviceSession.deviceId,
            date: MissionZebraDeviceActivityShared.dateKey(for: date),
            totalMinutes: usageSnapshot.minutes,
            nightMinutes: Self.isNight(date) ? usageSnapshot.minutes : 0,
            categoryMinutes: [.other: usageSnapshot.minutes],
            categoryOpenCounts: [:],
            openCount: 0,
            trackedAt: Int64(Date().timeIntervalSince1970 * 1000)
        )

        return await safetyRepository.saveSnapshot(snapshot)
    }

    static func limitationsText() -> String {
        "iOS geeft via DeviceActivityMonitor threshold-events, maar geen Android-achtige per-app open-counts of vrij uitleesbare categoriehistoriek. MissionZebra toont daarom totale Screen Time als echte data en markeert onbekende categorieën als Overig."
    }

    private static func isNight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 22 || hour < 6
    }
}
