import XCTest
@testable import MissionZebra

final class ChildFirestoreParityTests: XCTestCase {
    func testAggregatesOnlyDevicesReportedToday() {
        let total = Child.aggregatedDailyScreenTime(
            storedUsedMinutes: 200,
            deviceScreenTimes: ["phone": 45, "tablet": 80, "old": 999],
            deviceScreenTimeDates: ["phone": "2026-06-19", "tablet": "2026-06-19", "old": "2026-06-18"],
            todayKey: "2026-06-19"
        )

        XCTAssertEqual(total, 125)
    }

    func testAggregatesAllDevicesWhenLegacyDatesMissing() {
        let total = Child.aggregatedDailyScreenTime(
            storedUsedMinutes: 10,
            deviceScreenTimes: ["phone": 45, "tablet": 80],
            deviceScreenTimeDates: [:],
            todayKey: "2026-06-19"
        )

        XCTAssertEqual(total, 125)
    }

    func testScreenTimeScheduleUsesWeekendAndVacationLimits() {
        var schedule = ScreenTimeSchedule(enabled: true)
        schedule.schoolDayLimitMinutes = 60
        schedule.weekendLimitMinutes = 90

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 20 // Saturday
        let saturday = Calendar(identifier: .gregorian).date(from: components)!

        XCTAssertEqual(
            schedule.effectiveLimitMinutes(defaultLimitMinutes: 30, calendar: Calendar(identifier: .gregorian), date: saturday),
            90
        )

        schedule.vacationModeEnabled = true
        schedule.vacationLimitMinutes = 120

        XCTAssertEqual(
            schedule.effectiveLimitMinutes(defaultLimitMinutes: 30, calendar: Calendar(identifier: .gregorian), date: saturday),
            120
        )
    }

    func testAgeMatchesAndroidBirthdayLogic() {
        var child = Child()
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now) - 8
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        child.birthDate = String(format: "%04d-%02d-%02d", year, month, day)

        XCTAssertEqual(child.age, 8)
    }
}
