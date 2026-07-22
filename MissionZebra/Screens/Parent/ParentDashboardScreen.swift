import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import GoogleSignIn

enum ParentDashboardPage: String, CaseIterable {
    case children = "Kinderen"
    case tasks = "Taken"
    case rewards = "Beloningen"
    case premium = "Premium"
    case security = "Instellingen"

    var icon: String {
        switch self {
        case .children: return "person.fill"
        case .tasks: return "list.bullet"
        case .rewards: return "star.fill"
        case .premium: return "chart.bar.xaxis"
        case .security: return "lock.fill"
        }
    }

    static var visiblePages: [ParentDashboardPage] { allCases }
}

struct ParentDashboardScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.mzColors) private var colors
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ParentDashboardViewModel()
    @StateObject private var interstitialAd = MissionZebraInterstitialAd()
    @State private var selectedPage: ParentDashboardPage = .children
    @State private var isDeviceForChild = SessionManager.shared.isDeviceForChild()
    @State private var isSharedChildDevice = SessionManager.shared.isSharedChildDevice()
    @State private var parentAdRefreshID = UUID()
    @State private var parentModeReadyForAds = false

    private var shouldShowParentAds: Bool {
        parentModeReadyForAds && !viewModel.uiState.premiumStatus.isPremium
    }

    var body: some View {
        dashboardSurface(for: selectedPage)
            .id(selectedPage)
            .transition(.opacity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome
            }
            .animation(.easeOut(duration: 0.18), value: selectedPage)
        .onAppear {
            syncParentMode()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            syncParentMode()
        }
        .onChange(of: viewModel.uiState.premiumStatus.isPremium) { _ in
            reloadParentAdsIfNeeded()
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            MissionZebraBottomBannerAd(isVisible: shouldShowParentAds)
                .id(parentAdRefreshID)
            ParentDashboardBottomBar(
                selectedPage: $selectedPage,
                onPageSelected: { page in
                    interstitialAd.showIfAvailable(isVisible: shouldShowParentAds)
                }
            )
        }
        .background(
            Rectangle()
                .fill(colors.surface)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func dashboardSurface(for page: ParentDashboardPage) -> some View {
        if page == .security {
            ZStack {
                colors.background.ignoresSafeArea()
                pageContent(for: page)
            }
        } else {
            ZebraBackgroundView {
                pageContent(for: page)
            }
        }
    }

    @ViewBuilder
    private func pageContent(for page: ParentDashboardPage) -> some View {
        let header = AnyView(headerContent(for: page))

        switch page {
        case .children:
            ChildrenPage(
                children: viewModel.uiState.children,
                isAddingChild: viewModel.uiState.isAddingChild,
                addChildError: viewModel.uiState.addChildError,
                onDeleteChild: { viewModel.deleteChild(childId: $0) },
                onAddChild: { name, limit, birthDate in viewModel.addChild(name: name, limitMinutes: limit, birthDate: birthDate) },
                onClearAddChildError: { viewModel.clearAddChildError() },
                onSendMessage: { childId, msg in viewModel.sendMotivationalMessage(childId: childId, message: msg) },
                showsAds: shouldShowParentAds,
                onShowInterstitialAd: { interstitialAd.showIfAvailable(isVisible: shouldShowParentAds) },
                headerContent: header
            )
        case .tasks:
            TasksPage(
                uiState: viewModel.uiState,
                onTaskChildSelected: { viewModel.onTaskChildSelected($0) },
                onNewTaskTitleChange: { viewModel.onNewTaskTitleChange($0) },
                onNewTaskPointsChange: { viewModel.onNewTaskPointsChange($0) },
                onNewTaskDueDateChange: { viewModel.onNewTaskDueDateChange($0) },
                onNewTaskRepeatsWeeklyChange: { viewModel.onNewTaskRepeatsWeeklyChange($0) },
                onNewTaskPurposeChange: { viewModel.onNewTaskPurposeChange($0) },
                onNewTaskContributionTargetChange: { viewModel.onNewTaskContributionTargetChange($0) },
                onAddTaskClick: { viewModel.addTask() },
                onApproveTask: { taskId, feedback in viewModel.approveTask(taskId: taskId, parentFeedback: feedback) },
                onRejectTask: { viewModel.rejectTask(taskId: $0) },
                onUpdateTask: { viewModel.updateTask(task: $0) },
                onDeleteTask: { viewModel.deleteTask(taskId: $0) },
                showsAds: shouldShowParentAds,
                onShowInterstitialAd: { interstitialAd.showIfAvailable(isVisible: shouldShowParentAds) },
                headerContent: header
            )
        case .rewards:
            RewardsPage(
                uiState: viewModel.uiState,
                onRewardChildSelected: { viewModel.onRewardChildSelected($0) },
                onRewardFilterChildSelected: { viewModel.onRewardFilterChildSelected($0) },
                onNewRewardTitleChange: { viewModel.onNewRewardTitleChange($0) },
                onNewRewardPointsChange: { viewModel.onNewRewardPointsChange($0) },
                onAddRewardClick: { viewModel.addReward() },
                onRedeemReward: { viewModel.redeemReward(rewardId: $0) },
                onRejectRequestedReward: { viewModel.rejectRewardRequest(rewardId: $0) },
                onUpdateReward: { viewModel.updateReward(reward: $0) },
                onDeleteReward: { viewModel.deleteReward(rewardId: $0) },
                showsAds: shouldShowParentAds,
                onShowInterstitialAd: { interstitialAd.showIfAvailable(isVisible: shouldShowParentAds) },
                headerContent: header
            )
        case .premium:
            ParentPremiumDashboardTab()
        case .security:
            SecurityPage(
                familyTimeActive: viewModel.uiState.familyTimeActive,
                onToggleFamilyTime: { viewModel.toggleFamilyTime() },
                appBlockingEnabled: viewModel.uiState.appBlockingEnabled,
                isUpdatingAppBlocking: viewModel.uiState.isUpdatingAppBlocking,
                onSetAppBlockingEnabled: { viewModel.setAppBlockingEnabled($0) },
                onShowInterstitialAd: { interstitialAd.showIfAvailable(isVisible: shouldShowParentAds) },
                onLogout: {
                    SessionManager.shared.clearSession()
                    ParentPinManager.shared.clearParentPin()
                    try? Auth.auth().signOut()
                    GIDSignIn.sharedInstance.signOut()
                    router.reset(to: .welcome)
                },
                onDeleteAccount: {
                    try await deleteCurrentParentAccount(password: $0)
                },
                isDeviceForChild: isDeviceForChild,
                isSharedChildDevice: isSharedChildDevice,
                onSetDeviceForChild: {
                    SessionManager.shared.openChildModeFromParent()
                    MissionZebraAdPrivacy.applyForChildMode()
                    isDeviceForChild = true
                    isSharedChildDevice = false
                    router.navigate(to: .childLogin)
                },
                onSetSharedChildDevice: {
                    SessionManager.shared.openSharedChildModeFromParent()
                    MissionZebraAdPrivacy.applyForChildMode()
                    isDeviceForChild = true
                    isSharedChildDevice = true
                    router.navigate(to: .childLogin)
                },
                onSetDeviceForParent: {
                    syncParentMode()
                },
                onOpenPrivacyPolicy: { router.navigate(to: .privacyPolicy) },
                onOpenOnlineSafety: { router.navigate(to: .parentOnlineSafety) },
                headerContent: header
            )
        }
    }

    @ViewBuilder
    private func headerContent(for page: ParentDashboardPage) -> some View {
        switch page {
        case .children:
            VStack(spacing: 16) {
                ParentHeaderCard()

                if !viewModel.uiState.familyInsight.isEmpty {
                    FamilyInsightCard(insight: viewModel.uiState.familyInsight)
                }

                if !viewModel.uiState.parentTip.isEmpty {
                    ParentTipCard(tip: viewModel.uiState.parentTip)
                }

                if let variant = viewModel.uiState.premiumNudgeVariant {
                    PremiumNudgeCard(variant: variant) {
                        router.navigate(to: .parentPremiumDashboard)
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        case .tasks:
            ParentPageHeader(title: "Taken", subtitle: "Plan taken, keur inzendingen goed en hou voortgang helder.")
        case .rewards:
            ParentPageHeader(title: "Beloningen", subtitle: "Beheer motivatie, aanvragen en ingewisselde beloningen.")
        case .security:
            ParentPageHeader(title: "Instellingen", subtitle: "Account, beveiliging, meldingen en toestelmodus.")
        case .premium:
            EmptyView()
        }
    }

    private func syncParentMode() {
        SessionManager.shared.setParentLoggedIn()
        MissionZebraAdPrivacy.applyForParentMode()
        isDeviceForChild = false
        isSharedChildDevice = false
        parentModeReadyForAds = true
        reloadParentAdsIfNeeded()
    }

    private func reloadParentAdsIfNeeded() {
        parentAdRefreshID = UUID()
        let session = SessionManager.shared.getRoleSession()
        print(
            "[Ads] parent reload",
            "ready=\(parentModeReadyForAds)",
            "parentLocal=\(session.isParentLocally)",
            "premium=\(viewModel.uiState.premiumStatus.isPremium)",
            "visible=\(shouldShowParentAds)"
        )
        DispatchQueue.main.async {
            interstitialAd.reloadForParentMode(isVisible: shouldShowParentAds)
        }
    }

    private func deleteCurrentParentAccount(password: String?) async throws {
        guard Auth.auth().currentUser != nil else {
            throw NSError(
                domain: "MissionZebraAccountDeletion",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Je sessie is verlopen. Log opnieuw in en probeer het nog eens."]
            )
        }

        _ = password
        _ = try await Functions.functions(region: "europe-west1")
            .httpsCallable("deleteParentAccount")
            .call([:])

        ParentPinManager.shared.clearParentPin()
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()

        await MainActor.run {
            SessionManager.shared.clearSession()
            router.reset(to: .welcome)
        }
    }
}

private struct ParentPageHeader: View {
    @Environment(\.mzColors) private var colors
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundStyle(colors.onSurface)

            Text(subtitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(colors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}

private struct ParentDashboardBottomBar: View {
    @Environment(\.mzColors) private var colors
    @Binding var selectedPage: ParentDashboardPage
    let onPageSelected: (ParentDashboardPage) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ParentDashboardPage.visiblePages, id: \.self) { page in
                Button {
                    guard selectedPage != page else { return }
                    selectedPage = page
                    onPageSelected(page)
                } label: {
                    ParentDashboardTabItem(
                        page: page,
                        isSelected: selectedPage == page
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(page.rawValue)
                .accessibilityAddTraits(selectedPage == page ? .isSelected : .isButton)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(colors.surface)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(colors.outlineVariant.opacity(0.65))
                        .frame(height: 1)
                }
        )
    }
}

private struct ParentDashboardTabItem: View {
    @Environment(\.mzColors) private var colors

    let page: ParentDashboardPage
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: page.icon)
                .font(.system(size: 21, weight: isSelected ? .bold : .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(page.rawValue)
                .font(.caption2.weight(isSelected ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundColor(isSelected ? colors.primary : colors.onSurface.opacity(0.82))
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                Capsule()
                    .fill(colors.primary.opacity(0.13))
            }
        }
    }
}

private struct ParentPremiumDashboardTab: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = ParentPremiumDashboardViewModel()
    @StateObject private var purchaseManager = PremiumPurchaseManager()

    var body: some View {
        if PremiumFeatureGate.canAccessPremiumDashboard(status: viewModel.uiState.premiumStatus) {
            PremiumDashboardContent(
                children: viewModel.uiState.children,
                notifications: viewModel.uiState.notifications,
                avgDailyScreenTime: viewModel.uiState.avgDailyScreenTime,
                avgWeekTrend: viewModel.uiState.avgWeekTrend,
                onScreenTime: { router.navigate(to: .parentScreenTimeControl) },
                onCalendar: { router.navigate(to: .taskCalendar) },
                onSafety: { router.navigate(to: .parentOnlineSafety) },
                onManageSubscriptions: { Task { await purchaseManager.manageSubscriptions() } },
                onBack: nil
            )
        } else {
            PremiumPurchaseContent(
                productPrice: purchaseManager.product?.displayPrice,
                isLoading: purchaseManager.isLoading,
                errorMessage: purchaseManager.errorMessage,
                onPurchase: { Task { await purchaseManager.purchase() } },
                onRestore: { Task { await purchaseManager.restorePurchases() } },
                onManageSubscriptions: { Task { await purchaseManager.manageSubscriptions() } },
                onBack: nil
            )
            .task {
                await purchaseManager.loadProductsIfNeeded()
            }
        }
    }
}

private struct PremiumNudgeCard: View {
    let variant: PremiumNudgeVariant
    let onOpenPremium: () -> Void

    private var title: String {
        switch variant {
        case .insights: return "Meer overzicht nodig?"
        case .alerts: return "Slimme waarschuwingen"
        case .rewardsOverview: return "Beloningen beter opvolgen"
        }
    }

    private var message: String {
        switch variant {
        case .insights:
            return "Premium toont weektrends en gezinsinzichten zodra je meerdere kinderen opvolgt."
        case .alerts:
            return "Ontvang betere signalen wanneer taken en schermtijd aandacht vragen."
        case .rewardsOverview:
            return "Houd beloningen en voortgang overzichtelijk met het premium dashboard."
        }
    }

    var body: some View {
        Button(action: onOpenPremium) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header Card

struct ParentHeaderCard: View {
    @Environment(\.mzColors) private var colors
    @State private var offsetY: CGFloat = -30
    @State private var opacity: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ouder Dashboard")
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundStyle(colors.onSurface)

            Text("Alles onder controle, op een leuke manier.")
                .font(.subheadline)
                .foregroundColor(colors.onSurfaceVariant)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colors.surface.opacity(0.92))
                .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 2)
        )
        .offset(y: offsetY)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                offsetY = 0
                opacity = 1
            }
        }
    }
}

// MARK: - Tip Card

struct ParentTipCard: View {
    @Environment(\.mzColors) private var colors
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(colors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tip voor vandaag")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(colors.primary)

                Text(tip)
                    .font(.subheadline)
                    .foregroundColor(colors.onSurface)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Family Insight Card

struct FamilyInsightCard: View {
    @Environment(\.mzColors) private var colors
    let insight: String

    var body: some View {
        HStack(spacing: 12) {
            Text(insight.contains("minder") ? "🎉" : "📊")
                .font(.title)

            Text(insight)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(colors.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(insight.contains("minder") ? colors.insightPositiveCard : colors.insightNeutralCard)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }
}
