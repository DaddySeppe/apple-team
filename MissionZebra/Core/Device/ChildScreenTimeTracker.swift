// NOTE: Temporary run-safe guards
// This file uses Screen Time APIs (FamilyControls/DeviceActivity) which require
// real device testing and the Family Controls entitlement. To allow the app to
// run on Simulator or without the entitlement, we wrap sensitive calls with
// compile-time checks and provide safe fallbacks. Remove these guards when you
// configure entitlements and test on a real device.

import Foundation
#if canImport(FamilyControls)
import DeviceActivity
import FamilyControls
#else
// Shims for build/run without FamilyControls/DeviceActivity
enum AuthorizationStatusShim { case approved, denied, notDetermined }
struct AuthorizationCenter {
    static let shared = AuthorizationCenter()
    var authorizationStatus: AuthorizationStatusShim { .notDetermined }
    enum FamilyControlsScope { case individual }
    func requestAuthorization(for: FamilyControlsScope) async throws {}
}
#endif

/// iOS equivalent of Android's ChildScreenTimeTracker.
/// Uses Screen Time API (FamilyControls/DeviceActivity) on iOS.
/// Note: Screen Time API requires Family Controls entitlement.
class ChildScreenTimeTracker: ObservableObject {

    @Published var todayUsageMinutes: Int = 0

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
        } catch {
            print("Failed to request Screen Time authorization: \(error)")
        }
        #else
        // Running without FamilyControls: no-op so the app can run.
        print("[Run-safe] Skipping Screen Time authorization request (FamilyControls not available)")
        #endif
    }

    /// Get today's usage in minutes.
    /// Whole-device totals require a DeviceActivityMonitor extension and entitlement;
    /// this value is maintained by the app-level tracker as a safe fallback.
    func getTodayUsageMinutes() -> Int {
        return todayUsageMinutes
    }

    func updateUsageMinutes(_ minutes: Int) {
        todayUsageMinutes = minutes
    }
}
