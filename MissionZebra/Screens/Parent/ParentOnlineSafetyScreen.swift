import Combine
import SwiftUI

final class ParentOnlineSafetyViewModel: ObservableObject {
    @Published private(set) var overview = SafetyOverview()

    private let repository: SafetyRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: SafetyRepository = SafetyRepository()) {
        self.repository = repository
        repository.safetyOverviewFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] overview in
                self?.overview = overview
            }
            .store(in: &cancellables)
    }
}

struct ParentOnlineSafetyScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = ParentOnlineSafetyViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { router.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                }
                Text("Online Veiligheid")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SafetySummaryCard(overview: viewModel.overview)

                    if viewModel.overview.children.isEmpty {
                        Text("Voeg eerst een kind toe om veiligheidsinzichten te tonen.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    } else if viewModel.overview.signals.isEmpty {
                        Text("Geen risicomeldingen gevonden op basis van de beschikbare veiligheidsdata.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    } else {
                        ForEach(viewModel.overview.signals) { signal in
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

private struct SafetySummaryCard: View {
    let overview: SafetyOverview

    private var latestText: String {
        guard let latest = overview.latestTrackedAt, latest > 0 else {
            return "Nog geen metingen"
        }
        let date = Date(timeIntervalSince1970: Double(latest) / 1000)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(overview.children.count) kinderen", systemImage: "person.2.fill")
                Spacer()
                Label("\(overview.snapshots.count) metingen", systemImage: "chart.bar.doc.horizontal")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text("Laatste sync: \(latestText)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

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
                HStack(spacing: 6) {
                    if !signal.childName.isEmpty {
                        Text(signal.childName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    if !signal.sourceDate.isEmpty {
                        Text(signal.sourceDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

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
