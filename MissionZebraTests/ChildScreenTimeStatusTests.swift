import XCTest
@testable import MissionZebra

final class ChildScreenTimeStatusTests: XCTestCase {
    func testScreenTimeStatusThresholds() {
        XCTAssertEqual(
            Child(dailyScreenTimeUsedMinutes: 30, dailyScreenTimeLimitMinutes: 60, screenTimePermissionGranted: true).screenTimeStatus,
            .ok
        )
        XCTAssertEqual(
            Child(dailyScreenTimeUsedMinutes: 48, dailyScreenTimeLimitMinutes: 60, screenTimePermissionGranted: true).screenTimeStatus,
            .nearLimit
        )
        XCTAssertEqual(
            Child(dailyScreenTimeUsedMinutes: 60, dailyScreenTimeLimitMinutes: 60, screenTimePermissionGranted: true).screenTimeStatus,
            .overLimit
        )
    }

    func testScreenTimeStatusBlockedAndNotTracked() {
        XCTAssertEqual(
            Child(isBlocked: true, screenTimePermissionGranted: false).screenTimeStatus,
            .blocked
        )
        XCTAssertEqual(
            Child(screenTimePermissionGranted: false).screenTimeStatus,
            .notTracked
        )
    }
}
