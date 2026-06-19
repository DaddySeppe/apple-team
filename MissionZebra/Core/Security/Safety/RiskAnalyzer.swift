import Foundation

class RiskAnalyzer {
    func analyze(
        childId: String,
        childName: String,
        today: SafetyUsageSnapshot?,
        recentHistory: [SafetyUsageSnapshot],
        dailyLimitMinutes: Int,
        trackingPermissionGranted: Bool?
    ) -> [RiskSignal] {
        guard let today else {
            return [
                signal(
                    type: "no_data",
                    childId: childId,
                    childName: childName,
                    level: .low,
                    title: "Nog geen veiligheidsdata",
                    description: "Open MissionZebra op het kindtoestel met schermtijdtoegang aan om echte signalen te verzamelen.",
                    sourceDate: currentDateFallback(history: recentHistory)
                )
            ]
        }

        var signals: [RiskSignal] = []

        if trackingPermissionGranted == false {
            signals.append(
                signal(
                    type: "tracking_missing",
                    childId: childId,
                    childName: childName,
                    level: .low,
                    title: "Schermtijdtoegang staat uit",
                    description: "Online Veiligheid kan pas betrouwbare signalen tonen als schermtijdtoegang op het kindtoestel aan staat.",
                    sourceDate: today.date
                )
            )
        }

        if let night = nightUsageSignal(childId: childId, childName: childName, today: today) {
            signals.append(night)
        }
        if let limit = limitSignal(childId: childId, childName: childName, today: today, dailyLimitMinutes: dailyLimitMinutes) {
            signals.append(limit)
        }
        signals.append(contentsOf: categoryDurationSignals(childId: childId, childName: childName, today: today))
        signals.append(contentsOf: categorySpikeSignals(childId: childId, childName: childName, today: today, recentHistory: recentHistory))
        if let opens = openCountSignal(childId: childId, childName: childName, today: today) {
            signals.append(opens)
        }

        if signals.isEmpty && isTrackingStale(today.trackedAt) {
            signals.append(
                signal(
                    type: "tracking_stale",
                    childId: childId,
                    childName: childName,
                    level: .low,
                    title: "Data is niet recent gesynchroniseerd",
                    description: "De laatste veiligheidsmeting is ouder dan 24 uur. Open MissionZebra op het kindtoestel om bij te werken.",
                    sourceDate: today.date
                )
            )
        }

        var unique: [String: RiskSignal] = [:]
        signals.forEach { unique[$0.id] = $0 }
        return unique.values.sorted {
            if levelWeight($0.level) != levelWeight($1.level) {
                return levelWeight($0.level) > levelWeight($1.level)
            }
            return $0.timestamp > $1.timestamp
        }
    }

    private func nightUsageSignal(childId: String, childName: String, today: SafetyUsageSnapshot) -> RiskSignal? {
        if today.nightMinutes > 45 {
            return signal(
                type: "night_usage",
                childId: childId,
                childName: childName,
                level: .high,
                title: "Veel nachtelijk schermgebruik",
                description: "\(today.nightMinutes) minuten gebruik tussen 22:00 en 06:00.",
                sourceDate: today.date
            )
        }
        if today.nightMinutes >= 15 {
            return signal(
                type: "night_usage",
                childId: childId,
                childName: childName,
                level: .medium,
                title: "Nachtelijk schermgebruik",
                description: "\(today.nightMinutes) minuten gebruik tussen 22:00 en 06:00.",
                sourceDate: today.date
            )
        }
        return nil
    }

    private func limitSignal(
        childId: String,
        childName: String,
        today: SafetyUsageSnapshot,
        dailyLimitMinutes: Int
    ) -> RiskSignal? {
        guard dailyLimitMinutes > 0 else { return nil }
        let overBy = today.totalMinutes - dailyLimitMinutes
        if overBy > 60 {
            return signal(
                type: "limit_exceeded",
                childId: childId,
                childName: childName,
                level: .high,
                title: "Schermtijd ruim boven limiet",
                description: "Vandaag zit \(childName) \(overBy) minuten boven de ingestelde limiet.",
                sourceDate: today.date
            )
        }
        if overBy > 0 {
            return signal(
                type: "limit_exceeded",
                childId: childId,
                childName: childName,
                level: .medium,
                title: "Schermtijd boven limiet",
                description: "Vandaag zit \(childName) \(overBy) minuten boven de ingestelde limiet.",
                sourceDate: today.date
            )
        }
        if today.totalMinutes >= Int(Double(dailyLimitMinutes) * 0.9) {
            return signal(
                type: "near_limit",
                childId: childId,
                childName: childName,
                level: .low,
                title: "Bijna aan schermtijdlimiet",
                description: "Vandaag is \(childName) bijna aan de ingestelde limiet.",
                sourceDate: today.date
            )
        }
        return nil
    }

    private func categoryDurationSignals(childId: String, childName: String, today: SafetyUsageSnapshot) -> [RiskSignal] {
        today.categoryMinutes.compactMap { category, minutes in
            guard category != .other, minutes > 120 else { return nil }
            return signal(
                type: "category_duration_\(category.rawValue.lowercased())",
                childId: childId,
                childName: childName,
                level: .medium,
                title: "Veel \(category.labelLower)-gebruik",
                description: "Vandaag werd ongeveer \(minutes) minuten besteed aan \(category.labelLower)-apps.",
                sourceDate: today.date,
                category: category
            )
        }
    }

    private func categorySpikeSignals(
        childId: String,
        childName: String,
        today: SafetyUsageSnapshot,
        recentHistory: [SafetyUsageSnapshot]
    ) -> [RiskSignal] {
        let previous = recentHistory.filter { $0.date != today.date }.suffix(7)
        guard previous.count >= 3 else { return [] }

        return SafetyCategory.allCases.compactMap { category in
            guard category != .other else { return nil }
            let todayMinutes = today.categoryMinutes[category] ?? 0
            let average = Double(previous.map { $0.categoryMinutes[category] ?? 0 }.reduce(0, +)) / Double(previous.count)
            guard average >= 20.0, Double(todayMinutes) > average * 1.5 else { return nil }
            return signal(
                type: "category_spike_\(category.rawValue.lowercased())",
                childId: childId,
                childName: childName,
                level: .high,
                title: "Sterke stijging in \(category.labelLower)",
                description: "Vandaag ligt \(category.labelLower)-gebruik meer dan 50% boven het recente gemiddelde.",
                sourceDate: today.date,
                category: category
            )
        }
    }

    private func openCountSignal(childId: String, childName: String, today: SafetyUsageSnapshot) -> RiskSignal? {
        guard today.openCount > 80 else { return nil }
        return signal(
            type: "frequent_app_switching",
            childId: childId,
            childName: childName,
            level: .medium,
            title: "Opvallend vaak apps geopend",
            description: "Vandaag werden apps ongeveer \(today.openCount) keer geopend. Dat kan wijzen op onrustig gebruik.",
            sourceDate: today.date
        )
    }

    private func signal(
        type: String,
        childId: String,
        childName: String,
        level: RiskLevel,
        title: String,
        description: String,
        sourceDate: String,
        category: SafetyCategory? = nil
    ) -> RiskSignal {
        RiskSignal(
            id: "\(childId)-\(sourceDate)-\(type)",
            childId: childId,
            childName: childName,
            title: title,
            description: description,
            level: level,
            category: category,
            sourceDate: sourceDate
        )
    }

    private func levelWeight(_ level: RiskLevel) -> Int {
        switch level {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    private func isTrackingStale(_ trackedAt: Int64) -> Bool {
        guard trackedAt > 0 else { return true }
        return Int64(Date().timeIntervalSince1970 * 1000) - trackedAt > 24 * 60 * 60 * 1000
    }

    private func currentDateFallback(history: [SafetyUsageSnapshot]) -> String {
        history.last?.date ?? ParentChildrenFirebaseRepository.todayKey()
    }
}
