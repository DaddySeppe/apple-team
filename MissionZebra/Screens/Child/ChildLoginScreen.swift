import SwiftUI

struct ChildLoginScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.mzColors) private var colors
    @StateObject private var viewModel = ChildLoginViewModel()
    @State private var showParentPinSheet = false
    @State private var parentPinDestination: AppRoute = .parentDashboard

    var body: some View {
        ChildZebraPhotoBackgroundView {
            VStack(spacing: 18) {
                HStack {
                    Button(action: goBackFromChildSelection) {
                        Label("Ouderomgeving", systemImage: "arrow.left")
                    }
                    .buttonStyle(MZSecondaryButtonStyle())

                    Spacer()
                }

                VStack(spacing: 8) {
                    Text("Ik ben kind")
                        .font(.largeTitle.weight(.black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)

                    Text("Kies je naam om verder te gaan.")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 6)

                if viewModel.uiState.isLoading {
                    ProgressView("Laden...")
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(colors.surface))
                } else {
                    if viewModel.uiState.children.isEmpty {
                        VStack(spacing: 10) {
                            Text("Er zijn nog geen kinderen toegevoegd.")
                                .font(.headline)
                            Text("Ga even naar de ouderomgeving om een kind toe te voegen.")
                                .font(.subheadline)
                                .foregroundColor(colors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(colors.surface))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.uiState.children) { child in
                                    ChildSelectCard(child: child) {
                                        SessionManager.shared.setChildLoggedIn(childId: child.id, childName: child.name)
                                        MissionZebraAdPrivacy.applyForChildMode()
                                        router.reset(to: .childDashboard(childId: child.id, childName: child.name))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button(action: {
                        requestParentAccess(destination: .parentScreenTimeControl)
                    }) {
                        Label("Nieuw kind toevoegen", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZPrimaryButtonStyle())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showParentPinSheet) {
            ParentPinGateSheet(
                title: "Ouder-PIN",
                message: "Voer je 4-cijferige PIN in om naar de ouderomgeving te gaan."
            ) {
                continueAsParent(to: parentPinDestination)
            }
        }
    }

    private func goBackFromChildSelection() {
        if SessionManager.shared.hasParentSession() || SessionManager.shared.getRoleSession().firebaseUid != nil {
            SessionManager.shared.setParentLoggedIn()
            MissionZebraAdPrivacy.applyForParentMode()
            router.reset(to: .parentDashboard)
        } else {
            router.reset(to: .parentDashboard)
        }
    }

    private func requestParentAccess(destination: AppRoute) {
        parentPinDestination = destination

        if ParentPinManager.shared.hasParentPin() {
            showParentPinSheet = true
            return
        }

        Task {
            let remotePinConfigured = await ParentPinManager.shared.refreshParentPinConfigured()
            await MainActor.run {
                let session = SessionManager.shared.getRoleSession()
                if session.isLoggedIn {
                    continueAsParent(to: destination)
                } else if remotePinConfigured || session.firebaseUid == nil {
                    router.reset(to: .parentLogin)
                } else {
                    continueAsParent(to: destination)
                }
            }
        }
    }

    private func continueAsParent(to destination: AppRoute) {
        SessionManager.shared.setParentLoggedIn()
        MissionZebraAdPrivacy.applyForParentMode()

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
}

// MARK: - Child Select Card

private struct ChildSelectCard: View {
    let child: Child
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.title3)
                    .foregroundColor(.primary)

                Text("\(child.points) punten")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 4))
        }
        .buttonStyle(.plain)
    }
}
