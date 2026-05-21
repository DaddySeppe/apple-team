import SwiftUI

struct ZebraCustomizerScreen: View {
    let points: Int
    let accessoriesByCategory: [ZebraCategory: [Accessory]]
    let purchasedIds: [String]
    let equippedItems: [String: String]
    let onBuy: (Accessory) -> Void
    let onEquipCategory: (ZebraCategory, String?) -> Void
    let onDismiss: () -> Void

    @State private var selectedCategory: ZebraCategory = .KLEUR
    @State private var previewedItems: [ZebraCategory: String?] = [:]

    private var currentPreviewId: String? {
        previewedItems[selectedCategory] ?? nil
    }

    private func displayItems() -> [String: String] {
        var map = equippedItems
        previewedItems.forEach { cat, id in
            if let id = id {
                map[cat.rawValue] = id
            } else {
                map.removeValue(forKey: cat.rawValue)
            }
        }
        return map
    }

    var body: some View {
        VStack(spacing: 0) {
            // top bar
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(hex: "#4F46E5"), Color(hex: "#7C3AED")]), startPoint: .leading, endPoint: .trailing)
                    .frame(height: 80)
                    .edgesIgnoringSafeArea(.top)

                HStack {
                    Text("🦓 Zebra aanpassen")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 36)
            }

            ZebraPreview(equippedItems: displayItems(), accessoriesByCategory: accessoriesByCategory, isInPreviewMode: currentPreviewId != nil)
                .frame(height: 260)

            // category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ZebraCategory.allCases, id: \.self) { cat in
                        let selected = cat == selectedCategory
                        Button(action: { selectedCategory = cat }) {
                            VStack(spacing: 4) {
                                Text(cat.emoji)
                                    .font(.title2)
                                Text(cat.displayName)
                                    .font(.caption)
                                    .fontWeight(selected ? .bold : .regular)
                                    .foregroundColor(selected ? Color.accentColor : .primary)
                            }
                            .padding(8)
                            .background(selected ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            let categoryItems = accessoriesByCategory[selectedCategory] ?? []
            let equippedInCat = equippedItems[selectedCategory.rawValue]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // "none" option
                CustomizerItemView(
                    name: "Geen",
                    emoji: "🚫",
                    price: 0,
                    isPurchased: true,
                    isEquipped: equippedInCat == nil,
                    isPreviewSelected: false,
                    canAfford: true,
                    accentColor: .gray,
                    onSelect: {
                        previewedItems[selectedCategory] = nil
                        onEquipCategory(selectedCategory, nil)
                    },
                    onAction: {
                        previewedItems[selectedCategory] = nil
                        onEquipCategory(selectedCategory, nil)
                    }
                )

                ForEach(categoryItems) { item in
                    let isPurchased = purchasedIds.contains(item.id)
                    let isEquipped = equippedInCat == item.id
                    let isPreview = currentPreviewId == item.id
                    let canAfford = points >= item.price
                    let accent = Color.blue // temporary accent; could map by category

                    CustomizerItemView(
                        name: item.name,
                        emoji: item.emoji,
                        price: item.price,
                        isPurchased: isPurchased,
                        isEquipped: isEquipped,
                        isPreviewSelected: isPreview,
                        canAfford: canAfford,
                        accentColor: accent,
                        onSelect: {
                            if isPurchased {
                                previewedItems[selectedCategory] = nil
                                onEquipCategory(selectedCategory, item.id)
                            } else {
                                previewedItems[selectedCategory] = (isPreview ? nil : item.id)
                            }
                        },
                        onAction: {
                            if isPurchased {
                                previewedItems[selectedCategory] = nil
                                onEquipCategory(selectedCategory, item.id)
                            } else if canAfford {
                                previewedItems[selectedCategory] = nil
                                onBuy(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)

            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview component

struct ZebraPreview: View {
    let equippedItems: [String: String]
    let accessoriesByCategory: [ZebraCategory: [Accessory]]
    let isInPreviewMode: Bool

    private func emojiFor(category: ZebraCategory) -> String? {
        guard let id = equippedItems[category.rawValue] else { return nil }
        return accessoriesByCategory[category]?.first(where: { $0.id == id })?.emoji
    }

    var body: some View {
        VStack(spacing: 8) {
            if isInPreviewMode {
                Text("👀 Probeer modus")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }

            ZStack {
                // Zebra base with category overlays.
                Text("🦓")
                    .font(.system(size: 120))

                if let head = emojiFor(category: .HOOFD) {
                    Text(head).font(.system(size: 24)).offset(y: -50)
                }
                if let shirt = emojiFor(category: .SHIRT) {
                    Text(shirt).font(.system(size: 24)).offset(y: 0)
                }
                if let shoes = emojiFor(category: .SCHOENEN) {
                    Text(shoes).font(.system(size: 20)).offset(y: 50)
                }
                if let extra = emojiFor(category: .EXTRA) {
                    Text(extra).font(.system(size: 20)).offset(x: 40)
                }
                if let color = emojiFor(category: .KLEUR) {
                    // display as a badge top right
                    Text(color).font(.system(size: 20)).offset(x: 40, y: -40)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Item view

private struct CustomizerItemView: View {
    let name: String
    let emoji: String
    let price: Int
    let isPurchased: Bool
    let isEquipped: Bool
    let isPreviewSelected: Bool
    let canAfford: Bool
    let accentColor: Color
    let onSelect: () -> Void
    let onAction: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.largeTitle)
                    .padding(8)
                    .background(Circle().fill(isEquipped ? accentColor.opacity(0.2) : Color(.tertiarySystemBackground)))

                Text(name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if isEquipped {
                    Text("Aan").font(.caption2).fontWeight(.bold).foregroundColor(accentColor)
                } else if isPurchased {
                    Text("Dragen").font(.caption2).foregroundColor(.accentColor)
                } else if isPreviewSelected {
                    Button(action: onAction) {
                        Text(canAfford ? "Koop" : "Te duur")
                            .font(.caption2)
                            .padding(4)
                            .frame(maxWidth: .infinity)
                            .background(canAfford ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                } else {
                    Text(price == 0 ? "Gratis" : "\(price) ✨")
                        .font(.caption2)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).stroke(isEquipped ? accentColor : (isPreviewSelected ? Color.orange : Color.clear), lineWidth: 2))
        }
        .disabled(!isPurchased && !canAfford && !isPreviewSelected)
    }
}

// simple hex color helper
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
