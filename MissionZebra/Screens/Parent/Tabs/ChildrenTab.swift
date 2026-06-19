import SwiftUI

// MARK: - TAB 1: KINDEREN (Modern Dashboard)

struct ChildrenPage: View {
    let children: [Child]
    let isAddingChild: Bool
    let addChildError: String?
    let onDeleteChild: (String) -> Void
    let onAddChild: (String, Int, String?) -> Void
    let onClearAddChildError: () -> Void
    let onSendMessage: (String, String) -> Void
    let headerContent: AnyView

    @State private var showManageDialog = false
    @State private var showMessageDialogForChildId: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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

                Spacer().frame(height: 24)
            }
        }
        .scrollContentBackground(.hidden)
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
    @Environment(\.mzColors) private var colors
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(colors.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(colors.surfaceVariant))
    }
}

// MARK: - Child Card (Parent View)

struct ChildCardView: View {
    @Environment(\.mzColors) private var colors
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
                        .foregroundColor(colors.onSurface)

                    Spacer()

                    Text("\(child.points) punten")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(colors.onSurfaceVariant)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(colors.surfaceVariant))
                }

                HStack {
                    Text("Schermtijd: \(child.dailyScreenTimeUsedMinutes)/\(child.dailyScreenTimeLimitMinutes) min")
                        .font(.caption)
                        .foregroundColor(colors.onSurfaceVariant)

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

                if let birthDate = child.birthDate {
                    Text("\(child.age) jaar · geboren \(birthDate)")
                        .font(.caption2)
                        .foregroundColor(colors.onSurfaceVariant)
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colors.surface)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
