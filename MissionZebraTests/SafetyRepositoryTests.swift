import XCTest
@testable import MissionZebra

final class SafetyRepositoryTests: XCTestCase {
    func testParsesSafetySnapshotNumericValuesFromFirestoreData() {
        let snapshot = SafetyRepository.safetySnapshot(from: [
            "childId": "child-1",
            "deviceId": "device-1",
            "date": "2026-06-19",
            "totalMinutes": NSNumber(value: 145),
            "nightMinutes": NSNumber(value: 20),
            "categoryMinutes": ["SOCIAL": NSNumber(value: 130), "OTHER": NSNumber(value: 5)],
            "categoryOpenCounts": ["SOCIAL": NSNumber(value: 12)],
            "openCount": NSNumber(value: 85),
            "trackedAt": NSNumber(value: Int64(1_797_673_200_000))
        ])

        XCTAssertEqual(snapshot.childId, "child-1")
        XCTAssertEqual(snapshot.totalMinutes, 145)
        XCTAssertEqual(snapshot.nightMinutes, 20)
        XCTAssertEqual(snapshot.categoryMinutes[.social], 130)
        XCTAssertEqual(snapshot.openCount, 85)
    }

    func testRiskAnalyzerProducesAndroidEquivalentSignals() {
        let analyzer = RiskAnalyzer()
        let today = SafetyUsageSnapshot(
            childId: "child-1",
            deviceId: "device-1",
            date: "2026-06-19",
            totalMinutes: 145,
            nightMinutes: 20,
            categoryMinutes: [.social: 130],
            categoryOpenCounts: [.social: 12],
            openCount: 85,
            trackedAt: Int64(Date().timeIntervalSince1970 * 1000)
        )

        let signals = analyzer.analyze(
            childId: "child-1",
            childName: "Lotte",
            today: today,
            recentHistory: [today],
            dailyLimitMinutes: 120,
            trackingPermissionGranted: true
        )

        XCTAssertTrue(signals.contains { $0.id == "child-1-2026-06-19-night_usage" })
        XCTAssertTrue(signals.contains { $0.id == "child-1-2026-06-19-limit_exceeded" })
        XCTAssertTrue(signals.contains { $0.id == "child-1-2026-06-19-category_duration_social" })
        XCTAssertTrue(signals.contains { $0.id == "child-1-2026-06-19-frequent_app_switching" })
    }
}
