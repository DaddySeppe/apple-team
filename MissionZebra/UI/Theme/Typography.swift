import SwiftUI

// MARK: - MissionZebra Typography

/// Typography definitions matching the Android MissionZebra theme.
/// SwiftUI uses the system font (SF Pro) by default which is the iOS equivalent.
struct MZTypography {
    // Grote titels
    static let headlineLarge = Font.system(size: 32, weight: .bold)
    static let headlineMedium = Font.system(size: 24, weight: .bold)
    static let headlineSmall = Font.system(size: 20, weight: .semibold)

    // Titels
    static let titleLarge = Font.system(size: 22, weight: .semibold)
    static let titleMedium = Font.system(size: 18, weight: .semibold)
    static let titleSmall = Font.system(size: 16, weight: .medium)

    // Normale tekst
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)

    // Knoppen / labeltjes
    static let labelLarge = Font.system(size: 15, weight: .semibold)
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)
}

// MARK: - MissionZebra Shapes

/// Corner radius matching the Android MissionZebra shapes.
struct MZShapes {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 28
}
