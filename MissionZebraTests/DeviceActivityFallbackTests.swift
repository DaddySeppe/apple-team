import XCTest
@testable import MissionZebra

final class DeviceActivityFallbackTests: XCTestCase {
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

        XCTAssertEqual(controller.shieldReason(for: child), .parentBlocked)

        child.isBlocked = false
        XCTAssertEqual(controller.shieldReason(for: child), .limitExceeded)

        child.dailyScreenTimeUsedMinutes = 10
        child.screenTimeSchedule = ScreenTimeSchedule(enabled: true, bedtimeBlockEnabled: true, bedtimeStartHour: 20, bedtimeEndHour: 7)
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 22))!
        XCTAssertEqual(controller.shieldReason(for: child, now: date), .bedtime)
    }
}
