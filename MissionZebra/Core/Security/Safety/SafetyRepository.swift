import Foundation

class SafetyRepository {

    private let analyzer = RiskAnalyzer()

    func getRiskSignalsForChild() -> [RiskSignal] {
        // 🔥 Dummy data (later echte usage stats)
        return analyzer.analyze(
            dailyScreenTimeMinutes: 340,
            nightUsageMinutes: 45,
            chatAppOpens: 62
        )
    }
}
