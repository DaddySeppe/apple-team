import SwiftUI

// MARK: - TAB 1: KINDEREN (Modern Dashboard)

struct ChildrenPage: View {
    let children: [Child]
    let isAddingChild: Bool
    let addChildError: String?
    let onDeleteChild: (String) -> Void
    let onAddChild: (String, Int) -> Void
    let onClearAddChildError: () -> Void
    let onSendMessage: (String, String) -> Void
    let headerContent: AnyView

    @State private var showManageDialog = false
    @State private var showMessageDialogForChildId: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 1. Header & Intro
                headerContent

                HStack {
                    Text("Overzicht")
                        .font(.title3)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: { showManageDialog = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape")
                                .font(.caption)
                            Text("Beheren")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // 2. Dashboard Content
                if children.isEmpty {
                    VStack(spacing: 16) {
                        InfoCardView(message: "Je hebt nog geen kinderen toegevoegd.")

                        Button("Nu toevoegen") { showManageDialog = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                } else {
                    ForEach(children) { child in
                        ChildCardView(child: child, onClick: { showMessageDialogForChildId = child.id })
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }

                // 3. Banner Ad placeholder
                Spacer().frame(height: 24)
                BannerAdPlaceholder()
            }
        }
        .sheet(isPresented: $showManageDialog) {
            ManageChildrenDialog(
                children: children,
                onDismiss: { showManageDialog = false },
                onAddChild: onAddChild,
                onDeleteChild: onDeleteChild,
                isAdding: isAddingChild,
                addChildError: addChildError,
                onClearError: onClearAddChildError
            )
        }
        .sheet(isPresented: Binding(
            get: { showMessageDialogForChildId != nil },
            set: { if !$0 { showMessageDialogForChildId = nil } }
        )) {
            if let childId = showMessageDialogForChildId {
                ParentMessageDialog(
                    onDismiss: { showMessageDialogForChildId = nil },
                    onSend: { msg in
                        onSendMessage(childId, msg)
                        showMessageDialogForChildId = nil
                    }
                )
            }
        }
    }
}

// MARK: - Info Card

struct InfoCardView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - Banner Ad Placeholder

struct BannerAdPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 50)
    }
}

// MARK: - Child Card (Parent View)

struct ChildCardView: View {
    let child: Child
    let onClick: () -> Void

    private var screenTimeProgress: Double {
        guard child.dailyScreenTimeLimitMinutes > 0 else { return 0 }
        return min(Double(child.dailyScreenTimeUsedMinutes) / Double(child.dailyScreenTimeLimitMinutes), 1.0)
    }

    private var progressColor: Color {
        if screenTimeProgress >= 1.0 { return .red }
        if screenTimeProgress >= 0.75 { return .yellow }
        return .green
    }

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(child.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(child.points) punten")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.tertiarySystemBackground)))
                }

                HStack {
                    Text("Schermtijd: \(child.dailyScreenTimeUsedMinutes)/\(child.dailyScreenTimeLimitMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if child.streak > 0 {
                        HStack(spacing: 2) {
                            Text("🔥")
                            Text("\(child.streak)")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                    }
                }

                ProgressView(value: screenTimeProgress)
                    .tint(progressColor)

                if child.isBlocked {
                    Text("⛔ Geblokkeerd")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 2))
        }
        .buttonStyle(.plain)
    }
}
