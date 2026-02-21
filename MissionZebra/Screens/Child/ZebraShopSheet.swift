import SwiftUI

struct ZebraShopSheet: View {
    let points: Int
    let availableAccessories: [Accessory]
    let purchasedIds: [String]
    let equippedId: String?
    let onBuy: (Accessory) -> Void
    let onEquip: (String?) -> Void
    let onDismiss: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zebra Winkel")
                        .font(.title2)
                        .fontWeight(.heavy)

                    Text("Maak je zebra blij! 🦓")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(.systemBackground)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Wallet Card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Text("✨")
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Jouw Punten")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Text("\(points)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.39, green: 0.40, blue: 0.95)))
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            // Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    // "Geen accessoire" optie
                    AccessoryItemView(
                        name: "Puur Natuur",
                        emoji: "🦓",
                        price: 0,
                        isPurchased: true,
                        isEquipped: equippedId == nil,
                        canAfford: true,
                        onAction: { onEquip(nil) }
                    )

                    ForEach(availableAccessories) { item in
                        let isPurchased = purchasedIds.contains(item.id)
                        let isEquipped = equippedId == item.id
                        let canAfford = points >= item.price

                        AccessoryItemView(
                            name: item.name,
                            emoji: item.emoji,
                            price: item.price,
                            isPurchased: isPurchased,
                            isEquipped: isEquipped,
                            canAfford: canAfford,
                            onAction: {
                                if isPurchased {
                                    onEquip(item.id)
                                } else {
                                    onBuy(item)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .padding(.top, 16)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Accessory Item

private struct AccessoryItemView: View {
    let name: String
    let emoji: String
    let price: Int
    let isPurchased: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let onAction: () -> Void

    private var borderColor: Color {
        isEquipped ? Color(red: 0.39, green: 0.40, blue: 0.95) : .clear
    }

    private var isEnabled: Bool {
        isPurchased || canAfford
    }

    var body: some View {
        Button(action: onAction) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Text(emoji)
                        .font(.system(size: 42))
                }

                Spacer().frame(height: 12)

                Text(name)
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Spacer().frame(height: 12)

                if isEquipped {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                        Text("Aan")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(Color(red: 0.39, green: 0.40, blue: 0.95))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.1))
                    )
                } else if isPurchased {
                    Text("Dragen")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                } else {
                    HStack(spacing: 4) {
                        Text("\(price)")
                            .fontWeight(.bold)
                        Text("✨")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canAfford ? Color(red: 0.06, green: 0.73, blue: 0.51) : Color.gray)
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: isEquipped ? 2 : 0)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
