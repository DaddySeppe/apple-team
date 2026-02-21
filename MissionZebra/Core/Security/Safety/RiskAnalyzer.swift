import Foundation

class RiskAnalyzer {

    func analyze(
        dailyScreenTimeMinutes: Int,
        nightUsageMinutes: Int,
        chatAppOpens: Int
    ) -> [RiskSignal] {

        var signals: [RiskSignal] = []

        if nightUsageMinutes > 30 {
            signals.append(
                RiskSignal(
                    id: "night_usage",
                    title: "Nachtelijk schermgebruik",
                    description: "Er werd veel schermgebruik gedetecteerd na 22u.",
                    level: .medium
                )
            )
        }

        if chatAppOpens > 50 {
            signals.append(
                RiskSignal(
                    id: "chat_spike",
                    title: "Intens chatgebruik",
                    description: "Chatapps werden vandaag opvallend vaak geopend.",
                    level: .high
                )
            )
        }

        if dailyScreenTimeMinutes > 300 {
            signals.append(
                RiskSignal(
                    id: "high_screen_time",
                    title: "Zeer hoge schermtijd",
                    description: "Totale schermtijd ligt ver boven normaal.",
                    level: .low
                )
            )
        }

        return signals
    }
}
