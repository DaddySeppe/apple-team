import SwiftUI

// MARK: - Theme Preferences

/// Manages dark/light theme preference for MissionZebra.
/// Uses @AppStorage backed by UserDefaults (equivalent to Android DataStore).
final class ThemePreferences: ObservableObject {
    static let shared = ThemePreferences()

    @AppStorage("dark_theme") var isDarkTheme: Bool = false {
        willSet { objectWillChange.send() }
    }

    private init() {}

    func setDarkTheme(_ isDark: Bool) {
        isDarkTheme = isDark
    }

    func toggle() {
        isDarkTheme.toggle()
    }
}
