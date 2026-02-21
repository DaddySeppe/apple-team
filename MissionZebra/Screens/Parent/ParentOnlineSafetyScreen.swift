import SwiftUI

struct ParentOnlineSafetyScreen: View {
    @EnvironmentObject var router: NavigationRouter

    private let signals: [RiskSignal] = SafetyRepository().getRiskSignalsForChild()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: { router.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                }
                Text("🛡 Online Veiligheid")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    if signals.isEmpty {
                        Text("Geen risicomeldingen gevonden.")
                            .foregroundColor(.secondary)
                            .padding(24)
                    } else {
                        ForEach(signals, id: \.title) { signal in
                            RiskSignalCard(signal: signal)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Risk Signal Card

struct RiskSignalCard: View {
    let signal: RiskSignal

    private var riskColor: Color {
        switch signal.level {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private var riskIcon: String {
        switch signal.level {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: riskIcon)
                .font(.title2)
                .foregroundColor(riskColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(signal.title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(signal.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(signal.level.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(riskColor))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
