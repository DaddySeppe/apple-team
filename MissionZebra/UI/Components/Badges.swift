import SwiftUI

// MARK: - Badge Model

struct Badge: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let description: String
    let isUnlocked: Bool
}

// MARK: - Badge Item

struct BadgeItem: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(badge.isUnlocked ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                    )

                Text(badge.emoji)
                    .font(.system(size: 32))
            }

            Text(badge.title)
                .font(.caption)
                .fontWeight(badge.isUnlocked ? .bold : .regular)
                .foregroundColor(badge.isUnlocked ? .primary : .secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 100)
    }
}

// MARK: - Badges Card

struct BadgesCard: View {
    let badges: [Badge]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🏆 Badges")
                    .font(.body)
                    .fontWeight(.bold)

                Spacer()

                let unlockedCount = badges.filter(\.isUnlocked).count
                Text("\(unlockedCount)/\(badges.count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }

            if badges.isEmpty {
                Text("Verzamel badges door taken te voltooien!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                FlowLayout(spacing: 12) {
                    ForEach(badges) { badge in
                        BadgeItem(badge: badge)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 2))
    }
}

// MARK: - Default Badges

func getDefaultBadges(tasksCompleted: Int, streak: Int, totalPoints: Int) -> [Badge] {
    [
        Badge(id: "first_task", emoji: "🌟", title: "Eerste Stap", description: "Voltooi je eerste taak", isUnlocked: tasksCompleted >= 1),
        Badge(id: "task_master", emoji: "💪", title: "Takenmeester", description: "Voltooi 10 taken", isUnlocked: tasksCompleted >= 10),
        Badge(id: "week_streak", emoji: "🔥", title: "Week Streak", description: "7 dagen op rij actief", isUnlocked: streak >= 7),
        Badge(id: "point_collector", emoji: "💎", title: "Puntenverzamelaar", description: "Verzamel 100 punten", isUnlocked: totalPoints >= 100),
        Badge(id: "super_star", emoji: "⭐", title: "Superster", description: "Voltooi 25 taken", isUnlocked: tasksCompleted >= 25),
        Badge(id: "month_streak", emoji: "🏆", title: "Maand Kampioen", description: "30 dagen op rij actief", isUnlocked: streak >= 30),
    ]
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + rowHeight), origins)
    }
}
