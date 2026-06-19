import XCTest
@testable import MissionZebra

final class TaskCalendarSyncManagerTests: XCTestCase {
    func testWeeklyTaskExpandsOccurrencesForSixMonths() throws {
        let task = MZTask(
            id: "task-1",
            title: "Lezen",
            points: 10,
            dueDate: "2026-01-05",
            recurrence: MZTask.recurrenceWeekly
        )

        let now = try XCTUnwrap(TaskOrdering.date(from: "2026-01-01"))
        let occurrences = TaskCalendarSyncManager.occurrences(for: [task], now: now)

        XCTAssertEqual(occurrences.first?.key, "task-1-2026-01-05")
        XCTAssertGreaterThan(occurrences.count, 20)
        XCTAssertTrue(occurrences.allSatisfy { $0.task.id == "task-1" })
    }

    func testCompletedTasksAreNotSynced() {
        let task = MZTask(
            id: "task-1",
            title: "Lezen",
            points: 10,
            completed: true,
            dueDate: "2026-01-05"
        )

        XCTAssertTrue(TaskCalendarSyncManager.occurrences(for: [task]).isEmpty)
    }
}
