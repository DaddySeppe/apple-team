import SwiftUI
import Combine

// MARK: - ViewModel

struct PremiumChildData: Identifiable {
    let id: String
    let name: String
    let used: Int
    let limit: Int
    let points: Int
    let trend: [Int] // 7 values: Ma..Zo
}

struct ParentPremiumDashboardUiState {
    var children: [PremiumChildData] = []
    var avgDailyScreenTime: Int = 0
    var avgWeekTrend: [Int] = Array(repeating: 0, count: 7)
    var notifications: [String] = []
    var premiumStatus: PremiumStatus = PremiumStatus()
}

class ParentPremiumDashboardViewModel: ObservableObject {
    @Published var uiState = ParentPremiumDashboardUiState()

    private let childrenRepository: ParentChildrenFirebaseRepository
    private let premiumRepository: PremiumRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        childrenRepository: ParentChildrenFirebaseRepository = ParentChildrenFirebaseRepository(),
        premiumRepository: PremiumRepository = PremiumRepository()
    ) {
        self.childrenRepository = childrenRepository
        self.premiumRepository = premiumRepository
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        childrenRepository.childrenFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] children in
                self?.handleNewChildren(children)
            }
            .store(in: &cancellables)

        premiumRepository.premiumStatusFlow()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.uiState.premiumStatus = status
            }
            .store(in: &cancellables)
    }

    private func handleNewChildren(_ children: [Child]) {
        if children.isEmpty {
            let premiumStatus = uiState.premiumStatus
            uiState = ParentPremiumDashboardUiState(premiumStatus: premiumStatus)
            return
        }

        let premiumChildren = children.map { child -> PremiumChildData in
            let weekTrend = computeThisWeekTrend(
                history: child.screenTimeHistory,
                todayMinutes: child.dailyScreenTimeUsedMinutes
            )
            return PremiumChildData(
                id: child.id,
                name: child.name,
                used: child.dailyScreenTimeUsedMinutes,
                limit: child.dailyScreenTimeLimitMinutes,
                points: child.points,
                trend: weekTrend
            )
        }

        let avgDaily = premiumChildren.isEmpty ? 0 : premiumChildren.reduce(0) { $0 + $1.used } / premiumChildren.count
        let avgTrend = (0..<7).map { dayIndex in
            let avg = premiumChildren.map { $0.trend.indices.contains(dayIndex) ? $0.trend[dayIndex] : 0 }
            return avg.isEmpty ? 0 : avg.reduce(0, +) / avg.count
        }

        let notifs = premiumChildren
            .filter { $0.used > $0.limit && $0.limit > 0 }
            .map { "⚠️ \($0.name) heeft de limiet overschreden met \($0.used - $0.limit) minuten!" }

        uiState = ParentPremiumDashboardUiState(
            children: premiumChildren,
            avgDailyScreenTime: avgDaily,
            avgWeekTrend: avgTrend,
            notifications: notifs,
            premiumStatus: uiState.premiumStatus
        )
    }

    private func computeThisWeekTrend(history: [String: Int], todayMinutes: Int) -> [Int] {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let todayKey = formatter.string(from: today)

        // Monday of this week
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return Array(repeating: 0, count: 7) }

        var result: [Int] = []
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: monday) else {
                result.append(0)
                continue
            }
            let key = formatter.string(from: day)
            let base = history[key] ?? 0
            let value = (key == todayKey) ? max(base, todayMinutes) : base
            result.append(value)
        }
        return result
    }
}

// MARK: - Screen

struct ParentPremiumDashboardScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = ParentPremiumDashboardViewModel()
    @StateObject private var purchaseManager = PremiumPurchaseManager()
    @State private var showIntro = true

    var body: some View {
        if !PremiumFeatureGate.canAccessPremiumDashboard(status: viewModel.uiState.premiumStatus) {
            PremiumPurchaseContent(
                productPrice: purchaseManager.product?.displayPrice,
                isLoading: purchaseManager.isLoading,
                errorMessage: purchaseManager.errorMessage,
                onPurchase: { Task { await purchaseManager.purchase() } },
                onRestore: { Task { await purchaseManager.restorePurchases() } },
                onBack: { router.goBack() }
            )
        } else if showIntro {
            PremiumIntroOverlay(
                avgDailyScreenTime: viewModel.uiState.avgDailyScreenTime,
                avgWeekTrend: viewModel.uiState.avgWeekTrend,
                notifications: viewModel.uiState.notifications,
                children: viewModel.uiState.children,
                onContinue: { showIntro = false }
            )
        } else {
            PremiumDashboardContent(
                children: viewModel.uiState.children,
                notifications: viewModel.uiState.notifications,
                avgDailyScreenTime: viewModel.uiState.avgDailyScreenTime,
                avgWeekTrend: viewModel.uiState.avgWeekTrend,
                onBack: { router.goBack() }
            )
        }
    }
}

private struct PremiumPurchaseContent: View {
    let productPrice: String?
    let isLoading: Bool
    let errorMessage: String?
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: onBack) {
                    Label("Terug", systemImage: "arrow.left")
                }
                .buttonStyle(.bordered)

                Text("Premium")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Ontgrendel gezinsinzichten, slimme waarschuwingen en kalender-sync.")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Weekoverzicht per kind", systemImage: "chart.bar.fill")
                    Label("Limiet-waarschuwingen voor ouders", systemImage: "bell.badge.fill")
                    Label("Kalender-sync voor geplande taken", systemImage: "calendar.badge.clock")
                }
                .font(.body)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }

                Button(action: onPurchase) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(productPrice.map { "Start premium - \($0)" } ?? "Start premium")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                Button("Aankopen herstellen", action: onRestore)
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                Text("Aankopen worden met StoreKit geverifieerd en gekoppeld aan het ouderaccount.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Intro Overlay

struct PremiumIntroOverlay: View {
    let avgDailyScreenTime: Int
    let avgWeekTrend: [Int]
    let notifications: [String]
    let children: [PremiumChildData]
    let onContinue: () -> Void

    private var statusInfo: (text: String, color: Color) {
        let hasOverLimit = !notifications.isEmpty
        let maxOverBy = children.map { max($0.used - $0.limit, 0) }.max() ?? 0

        if avgDailyScreenTime == 0 {
            return ("Nog geen schermtijd geregistreerd.", .secondary)
        } else if hasOverLimit && maxOverBy > 0 {
            return ("🚨 Iemand zit tot \(maxOverBy) minuten over de limiet deze week. Tijd om in te grijpen.", Color(red: 0.83, green: 0.18, blue: 0.18))
        } else if avgDailyScreenTime >= 150 {
            return ("🚨 Te veel schermtijd deze week. Tijd om in te grijpen.", Color(red: 0.83, green: 0.18, blue: 0.18))
        } else if avgDailyScreenTime >= 110 {
            return ("⚠️ Let op: de schermtijd loopt op.", .orange)
        } else if avgDailyScreenTime >= 60 {
            return ("🙂 Schermtijd is oké, blijf het wel opvolgen.", .green)
        } else {
            return ("✅ Alles onder controle. Mooie balans!", Color(red: 0.18, green: 0.49, blue: 0.20))
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.98).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("📊 Weekoverzicht & inzichten")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)

                Text(statusInfo.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(statusInfo.color)
                    .multilineTextAlignment(.center)

                Text("Gemiddelde schermtijd:")
                    .font(.headline)

                Text("\(avgDailyScreenTime) minuten per dag")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(avgDailyScreenTime < 90 ? .green : (avgDailyScreenTime < 120 ? .yellow : .red))

                Text("Trend deze week (in minuten):")
                    .font(.subheadline)

                WeekBarChart(values: avgWeekTrend)
                    .frame(height: 200)

                Button("Doorgaan", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 8))
            .padding(24)
        }
    }
}

// MARK: - Dashboard Content

struct PremiumDashboardContent: View {
    let children: [PremiumChildData]
    let notifications: [String]
    let avgDailyScreenTime: Int
    let avgWeekTrend: [Int]
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("💎 Premium Ouder Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)

                if !notifications.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🔔 Meldingen")
                            .fontWeight(.bold)
                        ForEach(notifications, id: \.self) { msg in
                            Text(msg)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(12)
                    .background(Color.yellow.opacity(0.3))
                    .cornerRadius(12)
                }

                ForEach(children) { child in
                    PremiumChildCard(child: child)
                }

                Divider()

                PremiumOverviewSection(avgDailyScreenTime: avgDailyScreenTime, avgWeekTrend: avgWeekTrend)

                Button("⬅ Terug", action: onBack)
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
    }
}

// MARK: - Child Card

struct PremiumChildCard: View {
    let child: PremiumChildData

    private var percentage: Float {
        child.limit > 0 ? Float(child.used) / Float(child.limit) : 0
    }

    private var color: Color {
        if percentage <= 0.75 { return .green }
        else if percentage <= 1 { return .yellow }
        else { return .red }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(child.name)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Gebruik vandaag: \(child.used) min / \(child.limit) min")
                .font(.subheadline)

            ProgressView(value: Double(min(percentage, 1.0)))
                .tint(color)

            Text("🎯 Punten: \(child.points)")
                .foregroundColor(.secondary)

            WeekBarChart(values: child.trend)
                .frame(height: 150)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - Overview Section

struct PremiumOverviewSection: View {
    let avgDailyScreenTime: Int
    let avgWeekTrend: [Int]

    private let insights = [
        "Hou de schermtijd vooral in de avond in de gaten.",
        "Kinderen die hun limiet vaak overschrijden, kan je extra taken geven voor extra minuten.",
        "Experimenteer met kortere limieten op schooldagen en langere in het weekend."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Overzicht & inzichten")
                .font(.title2)
                .fontWeight(.bold)

            Text("Gemiddelde schermtijd deze week")
                .font(.headline)

            Text("\(avgDailyScreenTime) minuten per dag")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(avgDailyScreenTime < 90 ? .green : (avgDailyScreenTime < 120 ? .yellow : .red))

            Text("Trend over de week (in minuten):")
                .font(.subheadline)

            WeekBarChart(values: avgWeekTrend)
                .frame(height: 200)

            Text("🧠 Slimme inzichten")
                .fontWeight(.bold)
                .font(.title3)

            ForEach(insights, id: \.self) { insight in
                Text("• \(insight)")
                    .font(.subheadline)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - Week Bar Chart

struct WeekBarChart: View {
    let values: [Int]
    private let dayLabels = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

    var body: some View {
        let safeValues = values.isEmpty ? Array(repeating: 0, count: 7) : values
        let maxValue = max(safeValues.max() ?? 1, 1)

        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<safeValues.count, id: \.self) { index in
                    let value = safeValues[index]
                    let ratio = CGFloat(value) / CGFloat(maxValue)
                    let barHeight = max(geo.size.height * 0.7 * ratio, 6)

                    VStack(spacing: 4) {
                        if value > 0 {
                            Text("\(value)")
                                .font(.system(size: 9))
                                .fontWeight(.medium)
                        }

                        Spacer()

                        Rectangle()
                            .fill(value < 90 ? Color.green : (value < 120 ? Color.yellow : Color.red))
                            .frame(width: 20, height: barHeight)
                            .cornerRadius(4)

                        Text(dayLabels.indices.contains(index) ? dayLabels[index] : "")
                            .font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
