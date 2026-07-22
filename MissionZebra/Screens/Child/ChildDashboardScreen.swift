import SwiftUI
import Combine

// MARK: - MissionZebraCard

struct MissionZebraCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(radius: 6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

struct ParentPinGateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPinFocused: Bool

    let title: String
    let message: String
    let onSuccess: () -> Void

    @State private var pin = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("4-cijferige PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isPinFocused)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: pin) { newValue in
                        let filtered = String(newValue.filter { $0.isNumber }.prefix(4))
                        if filtered != newValue {
                            pin = filtered
                        }
                        if error != nil {
                            error = nil
                        }
                    }

                if let error {
                    Text(error)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }

                Button(action: validatePin) {
                    Text("Verder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pin.count != 4)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(260)])
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isPinFocused = true
            }
        }
    }

    private func validatePin() {
        guard ParentPinManager.shared.checkPin(pin) else {
            pin = ""
            error = "Foute code. Probeer opnieuw."
            isPinFocused = true
            return
        }

        isPinFocused = false
        pin = ""
        error = nil
        dismiss()
        DispatchQueue.main.async {
            onSuccess()
        }
    }
}

// MARK: - Child Dashboard Screen

struct ChildDashboardScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.scenePhase) private var scenePhase
    let childId: String
    let childName: String

    @StateObject private var viewModel: ChildDashboardViewModel

    @State private var showExitPinSheet = false
    @State private var parentPinDestination: AppRoute = .parentDashboard
    @State private var showConfetti = false

    init(childId: String, childName: String) {
        self.childId = childId
        self.childName = childName
        _viewModel = StateObject(wrappedValue: ChildDashboardViewModel(childId: childId, childName: childName))
    }

    var body: some View {
        let state = viewModel.uiState

        ZStack {
            ChildZebraPhotoBackgroundView {
                ZStack {
                    mainContent(state: state)

                    if showConfetti {
                        ConfettiRainView(
                            confettiCount: 140,
                            waveDurationSeconds: 2.5,
                            waves: 3,
                            onFinished: { showConfetti = false }
                        )
                    }

                    if state.isFocusModeActive {
                        FocusModeOverlay(
                            onStopClick: { viewModel.stopFocusMode() },
                            equippedAccessoryEmoji: viewModel.accessoryEmoji(for: state.child)
                        )
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.uiState.isShopOpen },
            set: { viewModel.toggleShop(isOpen: $0) }
        )) {
            shopSheet(state: state)
        }
        .alert("Goed gedaan!", isPresented: Binding(
            get: { viewModel.uiState.focusSessionEarnedPoints != nil },
            set: { if !$0 { viewModel.clearFocusSessionResult() } }
        )) {
            Button("Geweldig! 🎉") { viewModel.clearFocusSessionResult() }
        } message: {
            if let earned = viewModel.uiState.focusSessionEarnedPoints {
                Text("Je hebt \(earned) punten verdiend door je telefoon met rust te laten! Ga zo door. 🦓")
            }
        }
        .alert("Schermtijd wordt gemeten", isPresented: Binding(
            get: { viewModel.uiState.showScreenTimeDialog },
            set: { if !$0 { viewModel.dismissScreenTimeDialog() } }
        )) {
            Button("Ok") { viewModel.dismissScreenTimeDialog() }
        } message: {
            Text("MissionZebra meet echte schermtijd via Apple Screen Time zodra je ouder dit heeft geactiveerd.")
        }
        .sheet(isPresented: $showExitPinSheet) {
            ParentPinGateSheet(
                title: "Ouder-PIN",
                message: "Voer je 4-cijferige PIN in om naar de ouderomgeving te gaan."
            ) {
                continueAsParent(to: parentPinDestination)
            }
        }
        .onAppear {
            SessionManager.shared.setChildLoggedIn(childId: childId, childName: childName)
            MissionZebraAdPrivacy.applyForChildMode()
            viewModel.checkAndSyncDeviceScreenTime()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            viewModel.checkAndSyncDeviceScreenTime()
        }
    }

    // MARK: - Extracted Sub-views

    private func continueAsParent(to destination: AppRoute) {
        SessionManager.shared.setParentLoggedIn()
        MissionZebraAdPrivacy.applyForParentMode()
        viewModel.endSession()

        switch destination {
        case .parentScreenTimeControl:
            router.reset(to: .parentDashboard)
            DispatchQueue.main.async {
                router.navigate(to: .parentScreenTimeControl)
            }
        default:
            router.reset(to: .parentDashboard)
        }
    }

    @ViewBuilder
    private func mainContent(state: ChildDashboardUiState) -> some View {
        let points = state.child?.points ?? 0
        let usedMinutes = state.child?.dailyScreenTimeUsedMinutes ?? 0
        let limitMinutes = state.child?.dailyScreenTimeLimitMinutes ?? 60

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ChildHeader(
                        name: state.child?.name ?? childName,
                        points: points,
                        streak: state.child?.streak ?? 0,
                        equippedAccessoryEmoji: viewModel.accessoryEmoji(for: state.child),
                        usedMinutes: usedMinutes,
                        limitMinutes: limitMinutes,
                        onParentAccessClick: {
                            parentPinDestination = .parentDashboard
                            showExitPinSheet = true
                        },
                        onZebraClick: { viewModel.toggleShop(isOpen: true) }
                    )

                    if let message = state.screenTimeStatusMessage {
                        ScreenTimeStatusNotice(
                            message: message,
                            onParentAccessClick: {
                                parentPinDestination = .parentScreenTimeControl
                                showExitPinSheet = true
                            }
                        )
                        .padding(.top, 16)
                    }

                    if let msg = state.child?.motivationalMessage, !msg.isEmpty {
                        ParentMessageCard(message: msg, onDismiss: { viewModel.dismissMessage() })
                            .padding(.top, 16)
                    }

                    if state.child?.isBlocked == true {
                        BlockedMessage()
                            .padding(.top, 16)
                    } else {
                        taskRewardSection(state: state, points: points)
                    }

                    if let error = state.error {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private func taskRewardSection(state: ChildDashboardUiState, points: Int) -> some View {
        PlayfulTaskRewardSection(
            isLoading: state.isLoading,
            tasks: state.tasks,
            rewards: state.rewards,
            points: points,
            onTaskDone: { taskId, reflection, effort in
                viewModel.markTaskDone(
                    taskId: taskId,
                    childReflection: reflection,
                    effortLevel: effort
                )
            },
            onRewardRedeem: { viewModel.redeemReward(rewardId: $0) }
        )
        .padding(.top, 16)

        Button(action: { viewModel.startFocusMode() }) {
            Text("💤 Laat de Zebra rusten")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.39, green: 0.40, blue: 0.95))
        .cornerRadius(16)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func shopSheet(state: ChildDashboardUiState) -> some View {
        ZebraCustomizerScreen(
            points: state.child?.points ?? 0,
            accessoriesByCategory: viewModel.accessoriesByCategory,
            purchasedIds: state.child?.purchasedAccessoryIds ?? [],
            equippedItems: state.child?.equippedItems ?? [:],
            onBuy: { viewModel.buyAccessory(accessory: $0) },
            onEquipCategory: { category, accessoryId in
                viewModel.equipCategoryItem(category: category, accessoryId: accessoryId)
            },
            onDismiss: { viewModel.toggleShop(isOpen: false) }
        )
    }

}

private struct ScreenTimeStatusNotice: View {
    let message: String
    let onParentAccessClick: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hourglass.badge.exclamationmark")
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 8) {
                Text("Echte schermtijd nog niet binnen")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("Vraag je ouder om Apple Screen Time te controleren. MissionZebra telt alleen echte schermtijd wanneer Apple meetdata doorstuurt.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onParentAccessClick) {
                    Label("Ouder-PIN en schermtijd openen", systemImage: "lock.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Child Header

private struct ChildHeader: View {
    let name: String
    let points: Int
    let streak: Int
    let equippedAccessoryEmoji: String?
    let usedMinutes: Int
    let limitMinutes: Int
    let onParentAccessClick: () -> Void
    let onZebraClick: () -> Void

    private var remainingMinutes: Int {
        max(limitMinutes - usedMinutes, 0)
    }

    private var progress: Double {
        min(Double(usedMinutes) / Double(max(limitMinutes, 1)), 1)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Text("🦓")
                        .font(.system(size: 40))

                    if let emoji = equippedAccessoryEmoji {
                        Text(emoji)
                            .font(.system(size: 18))
                            .offset(y: -20)
                    }
                }
                .onTapGesture { onZebraClick() }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hoi \(name)!")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)

                    Text("⭐ \(points) punten  •  Level \((points / 50) + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                HStack(spacing: 8) {
                    if streak > 0 {
                        Text("🔥 \(streak)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                    }

                    Button(action: onZebraClick) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)

                    Button(action: onParentAccessClick) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                HeaderMetricCard(
                    label: "Schermtijd vandaag",
                    value: "Nog \(remainingMinutes) min",
                    progress: progress
                )

                HeaderMetricCard(
                    label: "Jouw punten",
                    value: "\(points)",
                    progress: nil
                )
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xFF111827), mzSkyDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private struct HeaderMetricCard: View {
    let label: String
    let value: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.72))

            Text(value)
                .font(.headline)
                .fontWeight(.heavy)
                .foregroundColor(.white)

            if let progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 5)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
    }
}

// MARK: - Screen Time Card

private struct ScreenTimeCard: View {
    let usedMinutes: Int
    let limitMinutes: Int

    private var progress: Float {
        Float(usedMinutes) / Float(max(limitMinutes, 1))
    }

    private var color: Color {
        progress >= 1.0 ? Color(red: 0.94, green: 0.27, blue: 0.27) : Color(red: 0.06, green: 0.73, blue: 0.51)
    }

    var body: some View {
        MissionZebraCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schermtijd vandaag")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(usedMinutes)")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("/ \(limitMinutes) min")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(max(limitMinutes - usedMinutes, 0))")
                        .font(.callout)
                        .fontWeight(.bold)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Blocked Message

private struct BlockedMessage: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("⛔ Tijd om pauze te nemen")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Je telefoon is nu geblokkeerd. Vraag aan je ouder om hem weer vrij te geven.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.red.opacity(0.15)))
    }
}

// MARK: - Playful Task Reward Section

private struct PlayfulTaskRewardSection: View {
    let isLoading: Bool
    let tasks: [MZTask]
    let rewards: [Reward]
    let points: Int
    let onTaskDone: (String, String, String) -> Void
    let onRewardRedeem: (String) -> Void

    @State private var showCompleted = false

    private var activeTasks: [MZTask] { tasks.filter { !$0.completed } }
    private var completedTasks: [MZTask] { tasks.filter { $0.completed } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tasks header
            Text("🧹 Taken")
                .font(.title3)
                .fontWeight(.bold)

            if isLoading {
                Text("Laden...")
                    .font(.subheadline)
            } else if tasks.isEmpty {
                Text("Er zijn momenteel geen taken.")
                    .font(.subheadline)
            } else {
                ForEach(activeTasks) { task in
                    ChildTaskCard(task: task, onDoneClick: { reflection, effort in
                        onTaskDone(task.id, reflection, effort)
                    })
                }

                if !completedTasks.isEmpty {
                    Button(action: { showCompleted.toggle() }) {
                        Text(showCompleted ? "Verberg voltooide taken" : "Toon \(completedTasks.count) voltooide taken ✅")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    if showCompleted {
                        ForEach(completedTasks) { task in
                            ChildTaskCard(task: task, onDoneClick: { reflection, effort in
                                onTaskDone(task.id, reflection, effort)
                            })
                        }
                    }
                }
            }

            // Rewards header
            Text("🎁 Beloningen")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.top, 4)

            if rewards.isEmpty {
                Text("Nog geen beloningen beschikbaar.")
                    .font(.subheadline)
            } else {
                ForEach(rewards) { reward in
                    let canRedeem = !reward.redeemed && points >= reward.costPoints
                    ChildRewardCard(
                        reward: reward,
                        canRedeem: canRedeem,
                        onRedeemClick: { onRewardRedeem(reward.id) }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 28).fill(Color(.secondarySystemBackground)).shadow(radius: 6))
    }
}

// MARK: - Child Task Card

private struct ChildTaskCard: View {
    let task: MZTask
    let onDoneClick: (String, String) -> Void

    @State private var showCompletionDialog = false
    @State private var reflection = ""

    private var isPending: Bool { task.pendingApproval && !task.completed }
    private var canReportDone: Bool { !task.pendingApproval && !task.completed }
    private var isCompleted: Bool { task.completed }

    private var backgroundColor: Color {
        if isCompleted { return Color.green.opacity(0.12) }
        if isPending { return Color.yellow.opacity(0.12) }
        return Color(.tertiarySystemBackground)
    }

    private var emoji: String {
        if isCompleted { return "✅" }
        if isPending { return "⏳" }
        return "🧹"
    }

    private var statusText: String {
        if isPending { return "Wachten op ouder" }
        if isCompleted { return "Afgerond" }
        return "Nog te doen"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.05, green: 0.65, blue: 0.91))
                    .frame(width: 40, height: 40)

                Text(emoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(.semibold)

                Text("\(task.points) punten")
                    .font(.subheadline)

                if !task.purpose.isEmpty {
                    Text(task.purpose)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !task.contributionTarget.isEmpty {
                    Text(task.contributionTarget)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(statusText)
                    .font(.caption)
            }

            Spacer()

            if canReportDone {
                Button("Klaar") {
                    showCompletionDialog = true
                }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20).fill(backgroundColor))
        .alert("Taak klaar?", isPresented: $showCompletionDialog) {
            TextField("Wat ging goed?", text: $reflection)
            Button("Makkelijk") {
                submitCompletion(effort: MZTask.effortEasy)
            }
            Button("Normaal") {
                submitCompletion(effort: MZTask.effortNormal)
            }
            Button("Moeilijk") {
                submitCompletion(effort: MZTask.effortHard)
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("Je ouder kijkt de taak na voordat je punten krijgt.")
        }
    }

    private func submitCompletion(effort: String) {
        onDoneClick(reflection.trimmingCharacters(in: .whitespacesAndNewlines), effort)
        reflection = ""
    }
}

// MARK: - Child Reward Card

private struct ChildRewardCard: View {
    let reward: Reward
    let canRedeem: Bool
    let onRedeemClick: () -> Void

    private var statusText: String {
        if reward.redeemed { return "Al ingewisseld" }
        if canRedeem { return "Je kan deze beloning nu inwisselen" }
        return "Nog niet genoeg punten"
    }

    private var backgroundColor: Color {
        if reward.redeemed { return Color.secondary.opacity(0.1) }
        if canRedeem { return Color.green.opacity(0.12) }
        return Color(.tertiarySystemBackground)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.98, green: 0.45, blue: 0.09), Color(red: 0.93, green: 0.29, blue: 0.60)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)

                Text("🎁")
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(reward.title)
                    .font(.body)
                    .fontWeight(.semibold)

                Text("\(reward.costPoints) punten")
                    .font(.subheadline)

                Text(statusText)
                    .font(.caption)
            }

            Spacer()

            if !reward.redeemed {
                Button("Inwisselen", action: onRedeemClick)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRedeem)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20).fill(backgroundColor))
    }
}

// MARK: - Confetti Rain

struct ConfettiRainView: View {
    let confettiCount: Int
    let waveDurationSeconds: Double
    let waves: Int
    let onFinished: () -> Void

    @State private var progress: CGFloat = 0
    @State private var specs: [ConfettiSpec] = []
    @State private var currentWave = 0

    private static let colors: [Color] = [
        Color(red: 1.0, green: 0.79, blue: 0.29),
        Color(red: 0.98, green: 0.44, blue: 0.52),
        Color(red: 0.65, green: 0.71, blue: 0.99),
        Color(red: 0.29, green: 0.87, blue: 0.50),
        Color(red: 0.47, green: 0.85, blue: 0.98)
    ]

    var body: some View {
        Canvas { context, size in
            let minDim = min(size.width, size.height)
            let p = progress

            for spec in specs {
                let baseX = spec.startXFraction * size.width
                let waveOffset = sin(spec.phase + p * 6) * (size.width * 0.05)
                let x = baseX + waveOffset
                let y = -minDim + (size.height + 2 * minDim) * p * spec.speedMultiplier
                let confettiSize = spec.sizeFraction * minDim

                let rect = CGRect(
                    x: x - confettiSize / 2,
                    y: y - confettiSize / 2,
                    width: confettiSize,
                    height: confettiSize * 1.8
                )
                let path = Path(roundedRect: rect, cornerRadius: confettiSize / 3)
                context.fill(path, with: .color(spec.color))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startNextWave()
        }
    }

    private func startNextWave() {
        specs = generateSpecs()
        progress = 0

        withAnimation(.linear(duration: waveDurationSeconds)) {
            progress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + waveDurationSeconds) {
            if currentWave + 1 < waves {
                currentWave += 1
                startNextWave()
            } else {
                onFinished()
            }
        }
    }

    private func generateSpecs() -> [ConfettiSpec] {
        (0..<confettiCount).map { _ in
            ConfettiSpec(
                startXFraction: CGFloat.random(in: 0...1),
                sizeFraction: CGFloat.random(in: 0.01...0.03),
                speedMultiplier: CGFloat.random(in: 0.7...1.3),
                phase: CGFloat.random(in: 0...(2 * .pi)),
                color: Self.colors.randomElement()!
            )
        }
    }
}

private struct ConfettiSpec {
    let startXFraction: CGFloat
    let sizeFraction: CGFloat
    let speedMultiplier: CGFloat
    let phase: CGFloat
    let color: Color
}

// MARK: - Focus Mode Overlay

struct FocusModeOverlay: View {
    let onStopClick: () -> Void
    let equippedAccessoryEmoji: String?

    @State private var elapsedSeconds: Int = 0
    @State private var zzzAlpha: Double = 0.4

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.16, blue: 0.22)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Zzz...")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white.opacity(zzzAlpha))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: true)) {
                            zzzAlpha = 1.0
                        }
                    }

                Spacer().frame(height: 32)

                ZStack {
                    Text("🦓")
                        .font(.system(size: 120))

                    if let emoji = equippedAccessoryEmoji {
                        Text(emoji)
                            .font(.system(size: 60))
                            .offset(y: -50)
                    }
                }

                Spacer().frame(height: 32)

                Text("Sst... de zebra slaapt.")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Spacer().frame(height: 8)

                Text(String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.51, green: 0.55, blue: 0.97))

                Spacer().frame(height: 16)

                Text("Leg de telefoon weg (scherm uit)\nom punten te verdienen! ✨")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)

                Spacer().frame(height: 48)

                Button(action: onStopClick) {
                    Text("Wakker maken (Stoppen)")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.1)))
            }
            .padding(24)
        }
        .onReceive(timer) { _ in
            elapsedSeconds += 1
        }
    }
}

// MARK: - Parent Message Card (Child View)

private struct ParentMessageCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("💌")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Berichtje van je ouder")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(message)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.08)))
    }
}
