import SwiftUI

// MARK: - TAB 3: BELONINGEN (Modernized)

struct RewardsPage: View {
    let uiState: ParentDashboardUiState
    let onRewardChildSelected: (String) -> Void
    let onRewardFilterChildSelected: (String?) -> Void
    let onNewRewardTitleChange: (String) -> Void
    let onNewRewardPointsChange: (String) -> Void
    let onAddRewardClick: () -> Void
    let onRedeemReward: (String) -> Void
    let onRejectRequestedReward: (String) -> Void
    let onUpdateReward: (Reward) -> Void
    let onDeleteReward: (String) -> Void
    let showsAds: Bool
    let onShowInterstitialAd: () -> Void
    let headerContent: AnyView

    @State private var showAddRewardDialog = false
    @State private var wasSavingReward = false

    private var filteredRewards: [Reward] {
        if let filterId = uiState.selectedRewardFilterChildId {
            return uiState.rewards.filter { $0.childId == filterId }
        }
        return uiState.rewards
    }

    private var requestedRewards: [Reward] { filteredRewards.filter { $0.requested && !$0.redeemed } }
    private var activeRewards: [Reward] { filteredRewards.filter { !$0.redeemed && !$0.requested } }
    private var redeemedRewards: [Reward] { filteredRewards.filter { $0.redeemed } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 1. Header & Intro
                headerContent

                TipCardView(
                    icon: "lightbulb",
                    title: "Tip: Populaire beloningen",
                    text: "Denk aan extra schermtijd, een uitje naar keuze, of samen een spelletje spelen!"
                )

                Spacer().frame(height: 24)

                // 2. Primary Action
                Button(action: {
                    onShowInterstitialAd()
                    showAddRewardDialog = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Nieuwe beloning toevoegen")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(MZPrimaryButtonStyle())
                .padding(.horizontal, 16)

                Spacer().frame(height: 24)

                // 3. Child Filter
                RewardFilterSection(
                    children: uiState.children,
                    selectedChildId: uiState.selectedRewardFilterChildId,
                    onChildSelected: onRewardFilterChildSelected
                )

                Spacer().frame(height: 24)

                // 4. Aangevraagde Beloningen
                SectionHeaderView(title: "Aangevraagd (\(requestedRewards.count))", icon: "bell")

                if requestedRewards.isEmpty {
                    EmptySectionStateView(text: "Geen openstaande aanvragen")
                } else {
                    ForEach(requestedRewards) { reward in
                        ParentRewardCardModern(
                            reward: reward,
                            children: uiState.children,
                            onRedeem: { onRedeemReward(reward.id) },
                            onUpdateReward: onUpdateReward,
                            onDeleteReward: onDeleteReward,
                            onRejectRequest: { onRejectRequestedReward(reward.id) },
                            onShowInterstitialAd: onShowInterstitialAd
                        )
                    }
                }

                // 5. Beschikbare Beloningen
                Spacer().frame(height: 24)

                SectionHeaderView(title: "Beschikbaar (\(activeRewards.count))", icon: "trophy")

                if activeRewards.isEmpty {
                    EmptySectionStateView(text: "Geen beloningen beschikbaar")
                } else {
                    ForEach(activeRewards) { reward in
                        ParentRewardCardModern(
                            reward: reward,
                            children: uiState.children,
                            onRedeem: {},
                            onUpdateReward: onUpdateReward,
                            onDeleteReward: onDeleteReward,
                            onShowInterstitialAd: onShowInterstitialAd
                        )
                    }
                }

                // 6. Ingewisselde Beloningen
                Spacer().frame(height: 24)
                SectionHeaderView(title: "Ingewisseld (\(redeemedRewards.count))", icon: "checkmark.circle")

                if redeemedRewards.isEmpty {
                    EmptySectionStateView(text: "Nog geen beloningen ingewisseld")
                } else {
                    ForEach(redeemedRewards) { reward in
                        ParentRewardCardModern(
                            reward: reward,
                            children: uiState.children,
                            onRedeem: {},
                            onUpdateReward: onUpdateReward,
                            onDeleteReward: onDeleteReward,
                            onShowInterstitialAd: onShowInterstitialAd
                        )
                    }
                }

                Spacer().frame(height: 80)
            }
        }
        .sheet(isPresented: $showAddRewardDialog) {
            AddRewardDialog(
                children: uiState.children,
                selectedChildId: uiState.selectedRewardChildId,
                title: uiState.newRewardTitle,
                points: uiState.newRewardPoints,
                isSaving: uiState.isSavingReward,
                error: uiState.rewardError,
                onChildSelected: onRewardChildSelected,
                onTitleChange: onNewRewardTitleChange,
                onPointsChange: onNewRewardPointsChange,
                onAddClick: {
                    onAddRewardClick()
                },
                onDismiss: { showAddRewardDialog = false }
            )
        }
        .onChange(of: uiState.isSavingReward) { isSaving in
            if wasSavingReward && !isSaving && uiState.rewardError == nil {
                showAddRewardDialog = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onShowInterstitialAd()
                }
            }
            wasSavingReward = isSaving
        }
    }
}

// MARK: - Components

struct TipCardView: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)

                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
        .padding(.horizontal, 16)
    }
}

struct RewardFilterSection: View {
    let children: [Child]
    let selectedChildId: String?
    let onChildSelected: (String?) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Kind:")
                .font(.caption)
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChipView(label: "Alle", isSelected: selectedChildId == nil) {
                        onChildSelected(nil)
                    }

                    ForEach(children) { child in
                        FilterChipView(label: child.name, isSelected: selectedChildId == child.id) {
                            onChildSelected(child.id)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct FilterChipView: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemBackground)))
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeaderView: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(title)
                .font(.body)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptySectionStateView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemBackground).opacity(0.3)))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}

// MARK: - Parent Reward Card Modern

struct ParentRewardCardModern: View {
    let reward: Reward
    let children: [Child]
    let onRedeem: () -> Void
    let onUpdateReward: (Reward) -> Void
    let onDeleteReward: (String) -> Void
    var onRejectRequest: (() -> Void)?
    let onShowInterstitialAd: () -> Void

    @State private var showEditDialog = false
    @State private var showDeleteDialog = false

    private var childName: String? {
        children.first(where: { $0.id == reward.childId })?.name
    }

    private var borderColor: Color {
        (reward.requested && !reward.redeemed) ? .purple : Color(.separator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.title)
                        .font(.body)
                        .fontWeight(.bold)

                    if let name = childName {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Text("\(reward.costPoints)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.tertiarySystemBackground)))
            }

            // Status Actions
            if reward.requested && !reward.redeemed, let reject = onRejectRequest {
                HStack {
                    Button(action: {
                        onShowInterstitialAd()
                        showEditDialog = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Afwijzen") {
                        onShowInterstitialAd()
                        reject()
                    }
                        .font(.caption)
                        .foregroundColor(.red)
                        .buttonStyle(MZSecondaryButtonStyle())

                    Button("Goedkeuren") {
                        onShowInterstitialAd()
                        onRedeem()
                    }
                        .font(.caption)
                        .buttonStyle(MZPrimaryButtonStyle())
                        .tint(.purple)
                }
                .padding(.top, 16)
            } else if !reward.redeemed {
                HStack {
                    Spacer()
                    Button(action: {
                        onShowInterstitialAd()
                        showEditDialog = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text("Ingewisseld")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .alert("Verwijderen", isPresented: $showDeleteDialog) {
            Button("Verwijderen", role: .destructive) {
                onShowInterstitialAd()
                onDeleteReward(reward.id)
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("Zeker weten?")
        }
    }
}
