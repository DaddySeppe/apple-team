import XCTest
@testable import MissionZebra

final class TaskOrderingTests: XCTestCase {
    private let today = TaskOrdering.date(from: "2026-06-19")!

    func testDisplayStatusMarksExpiredActivePendingAndCompleted() {
        XCTAssertEqual(
            TaskOrdering.displayStatus(MZTask(title: "Old", dueDate: "2026-06-18"), today: today),
            .expired
        )
        XCTAssertEqual(
            TaskOrdering.displayStatus(MZTask(title: "Today", dueDate: "2026-06-19"), today: today),
            .active
        )
        XCTAssertEqual(
            TaskOrdering.displayStatus(MZTask(title: "Pending", pendingApproval: true), today: today),
            .pendingApproval
        )
        XCTAssertEqual(
            TaskOrdering.displayStatus(MZTask(title: "Done", completed: true), today: today),
            .completed
        )
    }

    func testSortByDateDescUsesCreatedAtThenDueDateThenTitle() {
        let tasks = [
            MZTask(title: "B", createdAt: 10),
            MZTask(title: "A", createdAt: 20),
            MZTask(title: "C", createdAt: 20)
        ]

        XCTAssertEqual(TaskOrdering.sort(tasks, by: .dateDesc).map(\.title), ["A", "C", "B"])
    }

    func testWeeklyRecurrenceAddsSevenDays() {
        XCTAssertEqual(TaskOrdering.nextWeeklyDueDate(from: "2026-06-19", today: today), "2026-06-26")
    }
}
