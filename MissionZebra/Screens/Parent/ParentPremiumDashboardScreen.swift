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
    let deviceUsage: [(name: String, minutes: Int)]
    let scheduleSummary: String
    let insight: String
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
                trend: weekTrend,
                deviceUsage: deviceUsage(for: child),
                scheduleSummary: scheduleSummary(for: child),
                insight: insight(for: child, weekTrend: weekTrend)
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

    private func deviceUsage(for child: Child) -> [(name: String, minutes: Int)] {
        child.deviceScreenTimes
            .map { deviceId, minutes in
                (name: child.deviceNames[deviceId] ?? deviceId, minutes: minutes)
            }
            .sorted { $0.minutes > $1.minutes }
    }

    private func scheduleSummary(for child: Child) -> String {
        let schedule = child.screenTimeSchedule
        guard schedule.enabled else {
            return "Vaste limiet: \(child.dailyScreenTimeLimitMinutes) min/dag"
        }
        let vacation = schedule.vacationModeEnabled ? " · vakantie \(schedule.vacationLimitMinutes)m" : ""
        let bedtime = schedule.bedtimeBlockEnabled ? " · bedtijd \(schedule.bedtimeStartHour):00-\(schedule.bedtimeEndHour):00" : ""
        let focus = schedule.focusBlockEnabled ? " · focus \(schedule.focusStartHour):00-\(schedule.focusEndHour):00" : ""
        return "School \(schedule.schoolDayLimitMinutes)m · weekend \(schedule.weekendLimitMinutes)m\(vacation)\(bedtime)\(focus)"
    }

    private func insight(for child: Child, weekTrend: [Int]) -> String {
        let overLimitDays = weekTrend.filter { child.dailyScreenTimeLimitMinutes > 0 && $0 > child.dailyScreenTimeLimitMinutes }.count
        if overLimitDays >= 3 {
            return "Vaak over limiet deze week. Overweeg een striktere schooldagpreset of bedtime block."
        }
        if child.deviceScreenTimes.count > 1 {
            return "Gebruik komt van meerdere toestellen. Controleer gedeelde toestellen en per-device rapportage."
        }
        if child.screenTimePermissionGranted == false {
            return "Screen Time-toegang ontbreekt op minstens een toestel."
        }
        return "Gebruik is stabiel. Kalender- en safety-checks kunnen helpen om routines te bewaken."
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
                onManageSubscriptions: { Task { await purchaseManager.manageSubscriptions() } },
                onBack: { router.goBack() }
            )
            .task {
                await purchaseManager.loadProductsIfNeeded()
            }
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
                onScreenTime: { router.navigate(to: .parentScreenTimeControl) },
                onCalendar: { router.navigate(to: .taskCalendar) },
                onSafety: { router.navigate(to: .parentOnlineSafety) },
                onManageSubscriptions: { Task { await purchaseManager.manageSubscriptions() } },
                onBack: { router.goBack() }
            )
        }
    }
}

struct PremiumPurchaseContent: View {
    @Environment(\.mzColors) private var colors

    let productPrice: String?
    let isLoading: Bool
    let errorMessage: String?
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onManageSubscriptions: () -> Void
    let onBack: (() -> Void)?

    private var priceText: String {
        productPrice.map { "\($0) / maand" } ?? "€1,99 / maand"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let onBack {
                    Button(action: onBack) {
                        Label("Terug", systemImage: "arrow.left")
                    }
                    .buttonStyle(MZSecondaryButtonStyle())
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.67, blue: 0.12))
                            .frame(width: 46, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 1.0, green: 0.93, blue: 0.72))
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("MissionZebra Premium")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(colors.onSurface)

                            Text("Meer rust voor ouders, meer duidelijke afspraken voor kinderen.")
                                .font(.headline)
                                .foregroundColor(colors.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        PremiumMetricPreview(value: "7d", label: "weektrends", color: Color(red: 0.18, green: 0.49, blue: 0.20))
                        PremiumMetricPreview(value: "24/7", label: "signalen", color: Color(red: 0.12, green: 0.38, blue: 0.68))
                        PremiumMetricPreview(value: "0 ads", label: "voor ouders", color: Color(red: 0.74, green: 0.22, blue: 0.30))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors.surface)
                        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
                )

                VStack(spacing: 10) {
                    PremiumBenefitRow(
                        icon: "chart.bar.xaxis",
                        title: "Zie sneller waar schermtijd oploopt",
                        message: "Weektrends per kind maken meteen duidelijk wie dicht bij de limiet zit.",
                        tint: Color(red: 0.12, green: 0.38, blue: 0.68)
                    )
                    PremiumBenefitRow(
                        icon: "bell.badge.fill",
                        title: "Krijg betere ouder-signalen",
                        message: "Limieten, beloningen en aandachtspunten komen samen in één overzicht.",
                        tint: Color(red: 0.74, green: 0.22, blue: 0.30)
                    )
                    PremiumBenefitRow(
                        icon: "calendar.badge.clock",
                        title: "Plan routines met kalender-sync",
                        message: "Taken en afspraken passen beter in schooldagen, weekends en gezinsmomenten.",
                        tint: Color(red: 0.18, green: 0.49, blue: 0.20)
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Premium maandplan")
                                .font(.headline)
                                .foregroundColor(colors.onSurface)
                            Text("Opzegbaar via je Apple abonnementen.")
                                .font(.caption)
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        Spacer()
                        Text(priceText)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(colors.onSurface)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: onPurchase) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Start Premium", systemImage: "crown.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(MZPrimaryButtonStyle())
                    .disabled(isLoading)

                    Button(action: onRestore) {
                        Label("Aankopen herstellen", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZSecondaryButtonStyle())
                    .disabled(isLoading)

                    Button(action: onManageSubscriptions) {
                        Label("Abonnement beheren/opzeggen", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZSecondaryButtonStyle())
                    .disabled(isLoading)

                    Text("Aankopen worden met StoreKit geverifieerd en gekoppeld aan het ouderaccount.")
                        .font(.caption)
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.outlineVariant, lineWidth: 1)
                        )
                )
            }
            .padding(20)
        }
        .background(colors.background.ignoresSafeArea())
    }
}

private struct PremiumMetricPreview: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
        )
    }
}

private struct PremiumBenefitRow: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
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
                    .buttonStyle(MZPrimaryButtonStyle())
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
    @Environment(\.mzColors) private var colors

    let children: [PremiumChildData]
    let notifications: [String]
    let avgDailyScreenTime: Int
    let avgWeekTrend: [Int]
    let onScreenTime: () -> Void
    let onCalendar: () -> Void
    let onSafety: () -> Void
    let onManageSubscriptions: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Premium overzicht")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colors.onSurface)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(colors.surface)
                            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    )

                PremiumQuickActions(
                    onScreenTime: onScreenTime,
                    onCalendar: onCalendar,
                    onSafety: onSafety
                )

                Button(action: onManageSubscriptions) {
                    Label("Abonnement beheren/opzeggen", systemImage: "person.crop.circle.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MZSecondaryButtonStyle())

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

                if let onBack {
                    Button("⬅ Terug", action: onBack)
                        .buttonStyle(MZPrimaryButtonStyle())
                }
            }
            .padding(20)
        }
        .background(colors.background.ignoresSafeArea())
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

            VStack(alignment: .leading, spacing: 6) {
                Label("Schema", systemImage: "clock.badge.checkmark")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(child.scheduleSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !child.deviceUsage.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Per toestel", systemImage: "iphone.and.arrow.forward")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(child.deviceUsage, id: \.name) { device in
                        HStack {
                            Text(device.name)
                            Spacer()
                            Text("\(device.minutes) min")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }

            Label(child.insight, systemImage: "lightbulb")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

private struct PremiumQuickActions: View {
    let onScreenTime: () -> Void
    let onCalendar: () -> Void
    let onSafety: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onScreenTime) {
                Label("Schermtijd", systemImage: "hourglass")
                    .frame(maxWidth: .infinity)
            }
            Button(action: onCalendar) {
                Label("Kalender", systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            }
            Button(action: onSafety) {
                Label("Safety", systemImage: "shield")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(MZSecondaryButtonStyle())
        .font(.caption)
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
