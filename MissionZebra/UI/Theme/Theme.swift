import SwiftUI

// MARK: - MissionZebra Theme Configuration

/// MissionZebra color scheme that provides light and dark mode colors.
struct MZColorScheme {
    // Primary
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color

    // Secondary
    let secondary: Color
    let onSecondary: Color
    let secondaryContainer: Color
    let onSecondaryContainer: Color

    // Tertiary
    let tertiary: Color
    let onTertiary: Color
    let tertiaryContainer: Color
    let onTertiaryContainer: Color

    // Background / Surface
    let background: Color
    let onBackground: Color
    let surface: Color
    let onSurface: Color
    let surfaceVariant: Color
    let onSurfaceVariant: Color

    // Outline
    let outline: Color
    let outlineVariant: Color

    // Inverse
    let inverseSurface: Color
    let inverseOnSurface: Color

    // Error
    let error: Color
    let onError: Color
    let errorContainer: Color
    let onErrorContainer: Color
}

// MARK: - Light Color Scheme

let zebraLightColorScheme = MZColorScheme(
    primary: mzSky,
    onPrimary: Color(hex: 0xFF003547),
    primaryContainer: mzSkyLight,
    onPrimaryContainer: Color(hex: 0xFF001F2A),

    secondary: mzLime,
    onSecondary: Color(hex: 0xFF002204),
    secondaryContainer: mzLightCardGreen,
    onSecondaryContainer: mzZebraBlack,

    tertiary: mzPink,
    onTertiary: Color(hex: 0xFF4A0024),
    tertiaryContainer: mzLightCardYellow,
    onTertiaryContainer: mzZebraBlack,

    background: mzBackground,
    onBackground: mzZebraBlack,
    surface: mzSurface,
    onSurface: mzZebraBlack,
    surfaceVariant: mzSurfaceSoft,
    onSurfaceVariant: Color(hex: 0xFF374151),

    outline: Color(hex: 0xFF6B7280),
    outlineVariant: mzSurfaceStripe,

    inverseSurface: mzSky,
    inverseOnSurface: mzZebraBlack,

    error: Color(hex: 0xFFDC2626),
    onError: .white,
    errorContainer: mzLightCardRed,
    onErrorContainer: mzZebraBlack
)

// MARK: - Dark Color Scheme

let zebraDarkColorScheme = MZColorScheme(
    primary: mzSky,
    onPrimary: Color(hex: 0xFF003547),
    primaryContainer: mzSkyDark,
    onPrimaryContainer: Color(hex: 0xFFE5F8FF),

    secondary: mzLime,
    onSecondary: Color(hex: 0xFF002204),
    secondaryContainer: mzDarkCardGreen,
    onSecondaryContainer: mzDarkOnSurface,

    tertiary: mzPink,
    onTertiary: Color(hex: 0xFF4A0024),
    tertiaryContainer: mzDarkCardYellow,
    onTertiaryContainer: mzDarkOnSurface,

    background: mzDarkBackground,
    onBackground: mzDarkOnSurface,
    surface: mzDarkSurface,
    onSurface: mzDarkOnSurface,
    surfaceVariant: mzDarkSurfaceSoft,
    onSurfaceVariant: mzDarkOnSurfaceVar,

    outline: Color(hex: 0xFF4B5563),
    outlineVariant: mzDarkSurfaceStripe,

    inverseSurface: mzDarkSurface,
    inverseOnSurface: mzDarkOnSurface,

    error: Color(hex: 0xFFEF4444),
    onError: .white,
    errorContainer: mzDarkCardRed,
    onErrorContainer: mzDarkOnSurface
)

// MARK: - Environment Key

private struct MZColorSchemeKey: EnvironmentKey {
    static let defaultValue: MZColorScheme = zebraLightColorScheme
}

extension EnvironmentValues {
    var mzColors: MZColorScheme {
        get { self[MZColorSchemeKey.self] }
        set { self[MZColorSchemeKey.self] = newValue }
    }
}

// MARK: - Theme View Modifier

struct MissionZebraTheme: ViewModifier {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("dark_theme") private var isDarkTheme = false

    var effectiveDark: Bool {
        isDarkTheme
    }

    func body(content: Content) -> some View {
        let colors = effectiveDark ? zebraDarkColorScheme : zebraLightColorScheme
        content
            .environment(\.mzColors, colors)
            .preferredColorScheme(effectiveDark ? .dark : .light)
    }
}

extension View {
    /// Apply MissionZebra theme to the view hierarchy.
    func missionZebraTheme() -> some View {
        modifier(MissionZebraTheme())
    }
}
