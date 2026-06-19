import Foundation
#if canImport(FamilyControls)
import DeviceActivity
import FamilyControls
#endif

/// iOS equivalent of Android's ChildScreenTimeTracker.
/// Uses Screen Time API (FamilyControls/DeviceActivity) on iOS.
/// Note: Screen Time API requires Family Controls entitlement.
class ChildScreenTimeTracker: ObservableObject {

    @Published var todayUsageMinutes: Int = 0
    @Published var fallbackMessage: String?

    private let coordinator = DeviceActivityCoordinator.shared

    /// Check if the app has Screen Time permission
    func hasPermission() -> Bool {
        // On iOS, use AuthorizationCenter to check when available.
        // Guarded to allow running on Simulator or without entitlements.
        #if canImport(FamilyControls)
        return AuthorizationCenter.shared.authorizationStatus == .approved
        #else
        // Running without FamilyControls: pretend not approved, but don't crash.
        return false
        #endif
    }

    /// Request Screen Time authorization
    func requestPermission() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            try coordinator.startDailyMonitoring()
            await MainActor.run { fallbackMessage = nil }
        } catch {
            await MainActor.run {
                fallbackMessage = error.localizedDescription
            }
        }
        #else
        await MainActor.run {
            fallbackMessage = "Screen Time APIs zijn niet beschikbaar op dit platform."
        }
        #endif
    }

    /// Get today's usage in minutes.
    /// Whole-device totals require a DeviceActivityMonitor extension and entitlement;
    /// this value is maintained by the app-level tracker as a safe fallback.
    func getTodayUsageMinutes() -> Int {
        coordinator.currentDeviceActivityMinutes()
    }

    func updateUsageMinutes(_ minutes: Int) {
        todayUsageMinutes = minutes
    }
}
