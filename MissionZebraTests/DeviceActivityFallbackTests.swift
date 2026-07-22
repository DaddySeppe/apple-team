import XCTest
@testable import MissionZebra

final class DeviceActivityFallbackTests: XCTestCase {
    func testDeviceActivityThresholdsTrackEveryMinuteForCommonLimits() {
        XCTAssertEqual(Array(DeviceActivityCoordinator.thresholdMinutes.prefix(10)), Array(1...10))
        XCTAssertTrue(DeviceActivityCoordinator.thresholdMinutes.contains(60))
        XCTAssertTrue(DeviceActivityCoordinator.thresholdMinutes.contains(120))
        XCTAssertTrue(DeviceActivityCoordinator.thresholdMinutes.contains(180))
    }

    func testCoordinatorOnlyReportsDeviceActivityWhenThresholdDataExistsForToday() {
        let suiteName = "DeviceActivityFallbackTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = DeviceActivityCoordinator(defaults: defaults)
        XCTAssertFalse(coordinator.hasDeviceActivityDataToday())
        XCTAssertEqual(coordinator.currentDeviceActivityMinutes(), 0)

        defaults.set(30, forKey: MissionZebraDeviceActivityShared.deviceActivityUsageKey())
        XCTAssertFalse(coordinator.hasDeviceActivityDataToday())

        defaults.set(MissionZebraDeviceActivityShared.dateKey(), forKey: MissionZebraDeviceActivityShared.lastEventDateKey)
        XCTAssertTrue(coordinator.hasDeviceActivityDataToday())
        XCTAssertEqual(coordinator.currentDeviceActivityMinutes(), 30)
    }

    func testShieldReasonPrefersParentBlockThenLimitThenSchedule() {
        let suiteName = "ShieldReasonTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = ScreenTimeShieldController(defaults: defaults)
        var child = Child(
            dailyScreenTimeUsedMinutes: 70,
            dailyScreenTimeLimitMinutes: 60,
            isBlocked: true
        )
        var schedule = ScreenTimeSchedule()
        schedule.appBlockingEnabled = true
        child.screenTimeSchedule = schedule

        XCTAssertEqual(controller.shieldReason(for: child), .parentBlocked)

        child.isBlocked = false
        XCTAssertEqual(controller.shieldReason(for: child), .limitExceeded)

        child.dailyScreenTimeUsedMinutes = 10
        schedule.enabled = true
        schedule.bedtimeBlockEnabled = true
        schedule.bedtimeStartHour = 20
        schedule.bedtimeEndHour = 7
        child.screenTimeSchedule = schedule
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 22))!
        XCTAssertEqual(controller.shieldReason(for: child, now: date), .bedtime)
    }

    func testChildScreenTimeAttributionStartsFromCurrentDeviceTotal() {
        let suiteName = "ChildScreenTimeAttributionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let attribution = ChildScreenTimeAttribution(
            defaults: defaults,
            deviceIdProvider: { "device-1" }
        )
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!

        attribution.startSession(childId: "child-1", rawDeviceMinutes: 190, date: date)

        XCTAssertEqual(attribution.attributedMinutes(childId: "child-1", rawDeviceMinutes: 190, date: date), 0)
        XCTAssertEqual(attribution.attributedMinutes(childId: "child-1", rawDeviceMinutes: 197, date: date), 7)
        XCTAssertEqual(attribution.attributedMinutes(childId: "child-1", rawDeviceMinutes: 205, date: date), 15)
    }

    func testChildScreenTimeAttributionKeepsAccruedMinutesAcrossSessions() {
        let suiteName = "ChildScreenTimeAttributionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let attribution = ChildScreenTimeAttribution(
            defaults: defaults,
            deviceIdProvider: { "device-1" }
        )
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!

        attribution.startSession(childId: "child-1", rawDeviceMinutes: 100, date: date)
        XCTAssertEqual(attribution.endSession(childId: "child-1", rawDeviceMinutes: 112, date: date), 12)

        attribution.startSession(childId: "child-1", rawDeviceMinutes: 180, date: date)
        XCTAssertEqual(attribution.attributedMinutes(childId: "child-1", rawDeviceMinutes: 185, date: date), 17)
    }
}
