import SwiftUI

struct ChildLoginScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = ChildLoginViewModel()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                Button(action: {
                    router.navigate(to: .welcome)
                }) {
                    Text("⬅ Terug")
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Ik ben kind")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Text("Kies je naam om verder te gaan.")
                .font(.body)

            Spacer().frame(height: 16)

            if viewModel.uiState.isLoading {
                Text("Laden...")
                    .font(.subheadline)
            } else {
                if viewModel.uiState.children.isEmpty {
                    Text("Er zijn nog geen kinderen toegevoegd.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.uiState.children) { child in
                                ChildSelectCard(child: child) {
                                    SessionManager.shared.setChildLoggedIn(childId: child.id, childName: child.name)
                                    router.navigate(to: .childDashboard(childId: child.id, childName: child.name))
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 16)
                }

                Button(action: {
                    router.navigate(to: .parentScreenTimeControl)
                }) {
                    Text("Nieuw kind toevoegen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)).shadow(radius: 2))
        }
        .buttonStyle(.plain)
    }
}
