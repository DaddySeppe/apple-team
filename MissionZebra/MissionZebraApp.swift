import SwiftUI
import FirebaseCore

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()

        return true
    }
}

// MARK: - Main App

@main
struct MissionZebraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themePrefs = ThemePreferences.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .missionZebraTheme()
        }
    }
}
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreen {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else {
                AppNavigation()
                    .transition(.opacity)
            }
        }
    }
}
