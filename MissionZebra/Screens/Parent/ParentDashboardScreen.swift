import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import Security

enum ParentDashboardPage: String, CaseIterable {
    case children = "Kinderen"
    case tasks = "Taken"
    case rewards = "Beloningen"
    case security = "Instellingen"

    var icon: String {
        switch self {
        case .children: return "person.fill"
        case .tasks: return "list.bullet"
        case .rewards: return "star.fill"
        case .security: return "lock.fill"
        }
    }
}

struct ParentDashboardScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.mzColors) private var colors
    @StateObject private var viewModel = ParentDashboardViewModel()
    @State private var selectedPage: ParentDashboardPage = .children
    @State private var isDeviceForChild = SessionManager.shared.isDeviceForChild()

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(ParentDashboardPage.allCases, id: \.self) { page in
                dashboardSurface(for: page)
                .tabItem {
                    Image(systemName: page.icon)
                    Text(page.rawValue)
                }
                .tag(page)
            }
        }
        .tint(colors.primary)
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
        let header = AnyView(headerContent)

        switch page {
        case .children:
            ChildrenPage(
                children: viewModel.uiState.children,
                isAddingChild: viewModel.uiState.isAddingChild,
                addChildError: viewModel.uiState.addChildError,
                onDeleteChild: { viewModel.deleteChild(childId: $0) },
                onAddChild: { name, limit in viewModel.addChild(name: name, limitMinutes: limit) },
                onClearAddChildError: { viewModel.clearAddChildError() },
                onSendMessage: { childId, msg in viewModel.sendMotivationalMessage(childId: childId, message: msg) },
                headerContent: header
            )
        case .tasks:
            TasksPage(
                uiState: viewModel.uiState,
                onTaskChildSelected: { viewModel.onTaskChildSelected($0) },
                onNewTaskTitleChange: { viewModel.onNewTaskTitleChange($0) },
                onNewTaskPointsChange: { viewModel.onNewTaskPointsChange($0) },
                onAddTaskClick: { viewModel.addTask() },
                onApproveTask: { viewModel.approveTask(taskId: $0) },
                onRejectTask: { viewModel.rejectTask(taskId: $0) },
                onUpdateTask: { viewModel.updateTask(task: $0) },
                onDeleteTask: { viewModel.deleteTask(taskId: $0) },
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
                headerContent: header
            )
        case .security:
            SecurityPage(
                familyTimeActive: viewModel.uiState.familyTimeActive,
                onToggleFamilyTime: { viewModel.toggleFamilyTime() },
                onGoToPremiumDashboard: { router.navigate(to: .parentPremiumDashboard) },
                onLogout: {
                    SessionManager.shared.clearSession()
                    ParentPinManager.shared.clearParentPin()
                    try? Auth.auth().signOut()
                    GIDSignIn.sharedInstance.signOut()
                    router.goToRoot()
                },
                onDeleteAccount: {
                    try await deleteCurrentParentAccount()
                },
                isDeviceForChild: isDeviceForChild,
                onSetDeviceForChild: {
                    SessionManager.shared.setDeviceForChild(true)
                    isDeviceForChild = true
                    router.navigate(to: .childLogin)
                },
                onSetDeviceForParent: {
                    SessionManager.shared.setDeviceForChild(false)
                    isDeviceForChild = false
                },
                onOpenPrivacyPolicy: { router.navigate(to: .privacyPolicy) },
                onOpenOnlineSafety: { router.navigate(to: .parentOnlineSafety) }
            )
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        VStack(spacing: 16) {
            ParentHeaderCard()

            if !viewModel.uiState.familyInsight.isEmpty {
                FamilyInsightCard(insight: viewModel.uiState.familyInsight)
            }

            if !viewModel.uiState.parentTip.isEmpty {
                ParentTipCard(tip: viewModel.uiState.parentTip)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private func deleteCurrentParentAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "MissionZebraAccountDeletion",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Je sessie is verlopen. Log opnieuw in en probeer het nog eens."]
            )
        }

        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            let appleCredential = try await AppleAccountDeletionAuthorizer.shared.requestCredential()
            try await user.reauthenticate(with: appleCredential.credential)
            try await Auth.auth().revokeToken(withAuthorizationCode: appleCredential.authorizationCode)
        } else {
            let token = try await user.getIDTokenResult(forcingRefresh: true)
            guard Date().timeIntervalSince(token.authDate) < 5 * 60 else {
                throw NSError(
                    domain: "MissionZebraAccountDeletion",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Log opnieuw in en probeer daarna je account te verwijderen."]
                )
            }
        }

        try await deleteParentFirestoreData(parentUid: user.uid)
        ParentPinManager.shared.clearParentPin()
        try await user.delete()
        GIDSignIn.sharedInstance.signOut()

        await MainActor.run {
            SessionManager.shared.clearSession()
            router.goToRoot()
        }
    }

    private func deleteParentFirestoreData(parentUid: String) async throws {
        let firestore = Firestore.firestore()
        let parentRef = firestore.collection("parents").document(parentUid)

        let childrenSnapshot = try await parentRef.collection("children").getDocuments()
        for childDocument in childrenSnapshot.documents {
            try await deleteCollection(childDocument.reference.collection("screenSessions"))
        }

        try await deleteCollection(parentRef.collection("tasks"))
        try await deleteCollection(parentRef.collection("rewards"))
        try await deleteCollection(parentRef.collection("children"))
        try await parentRef.delete()
    }

    private func deleteCollection(_ collection: CollectionReference, batchSize: Int = 400) async throws {
        while true {
            let snapshot = try await collection.limit(to: batchSize).getDocuments()
            guard !snapshot.documents.isEmpty else { return }

            let batch = Firestore.firestore().batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
    }
}

private struct AppleDeletionCredential {
    let credential: AuthCredential
    let authorizationCode: String
}

private final class AppleAccountDeletionAuthorizer: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleAccountDeletionAuthorizer()

    private var continuation: CheckedContinuation<AppleDeletionCredential, Error>?
    private var currentNonce: String?

    func requestCredential() async throws -> AppleDeletionCredential {
        guard continuation == nil else {
            throw NSError(
                domain: "MissionZebraAccountDeletion",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Er loopt al een verwijderactie."]
            )
        }

        let nonce = try AccountDeletionNonce.randomNonceString()
        currentNonce = nonce

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AccountDeletionNonce.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let continuation else { return }
        defer { reset() }

        guard let nonce = currentNonce,
              let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleCredential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8),
              let authorizationCode = appleCredential.authorizationCode,
              let authorizationCodeString = String(data: authorizationCode, encoding: .utf8) else {
            continuation.resume(throwing: NSError(
                domain: "MissionZebraAccountDeletion",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Apple bevestiging is niet gelukt. Probeer opnieuw."]
            ))
            return
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: idToken,
            rawNonce: nonce
        )

        continuation.resume(returning: AppleDeletionCredential(
            credential: credential,
            authorizationCode: authorizationCodeString
        ))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let continuation else { return }
        defer { reset() }

        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            continuation.resume(throwing: NSError(
                domain: "MissionZebraAccountDeletion",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Account verwijderen is geannuleerd."]
            ))
            return
        }

        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    private func reset() {
        continuation = nil
        currentNonce = nil
    }
}

private enum AccountDeletionNonce {
    enum NonceError: Error {
        case generationFailed(OSStatus)
    }

    static func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)

        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        guard status == errSecSuccess else {
            throw NonceError.generationFailed(status)
        }

        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { charset[Int($0) % charset.count] }

        return String(nonce)
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)

        return hashedData.map { String(format: "%02x", $0) }.joined()
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
