import Foundation
import UserNotifications
import UIKit

/// Manages local push notifications for screen time alerts.
/// Sends notifications like Snapchat-style banners when a child
/// is approaching or exceeding their daily screen time limit.
class NotificationManager {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // Base keys to prevent spamming the same notification repeatedly.
    private let warningShownKey = "notification_warning_shown_date"
    private let exceededShownKey = "notification_exceeded_shown_date"
    private let screenTimeAlertsEnabledKey = "notifyOnScreenTimeLimit"

    private init() {}

    // MARK: - Permission

    /// Request notification permission from a contextual user action, then register APNS/FCM.
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NotificationManager] Permission error: \(error.localizedDescription)")
            }
            print("[NotificationManager] Permission granted: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    FirebaseMessagingManager.shared.refreshAndStoreToken()
                }
            }
            completion?(granted)
        }
    }

    func requestPermissionIfNeeded(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    FirebaseMessagingManager.shared.refreshAndStoreToken()
                }
                completion?(true)
            case .notDetermined:
                self?.requestPermission(completion: completion)
            case .denied:
                completion?(false)
            @unknown default:
                completion?(false)
            }
        }
    }

    // MARK: - Screen Time Notifications

    /// Call this after every screen time sync to check whether a notification should fire.
    /// - Parameters:
    ///   - childName: The name of the child (for the notification text)
    ///   - usedMinutes: Minutes of screen time used today
    ///   - limitMinutes: The configured daily limit in minutes
    func checkAndNotify(childName: String, childId: String? = nil, usedMinutes: Int, limitMinutes: Int) {
        guard limitMinutes > 0 else { return }
        guard screenTimeAlertsEnabled else { return }

        requestPermissionIfNeeded { [weak self] granted in
            guard granted else { return }
            self?.sendScreenTimeNotificationIfNeeded(
                childName: childName,
                childId: childId,
                usedMinutes: max(usedMinutes, 0),
                limitMinutes: limitMinutes
            )
        }
    }

    private func sendScreenTimeNotificationIfNeeded(
        childName: String,
        childId: String?,
        usedMinutes: Int,
        limitMinutes: Int
    ) {
        let today = todayString()
        let notificationKey = notificationChildKey(childName: childName, childId: childId)
        let percentage = Double(usedMinutes) / Double(limitMinutes)
        let remaining = max(limitMinutes - usedMinutes, 0)

        if (percentage >= 0.8 || remaining <= 5) && remaining > 0 {
            sendWarningIfNeeded(childName: childName, remaining: remaining, today: today, notificationKey: notificationKey)
        }

        if usedMinutes >= limitMinutes {
            let overBy = usedMinutes - limitMinutes
            sendExceededIfNeeded(childName: childName, overBy: overBy, today: today, notificationKey: notificationKey)
        }
    }

    // MARK: - Private

    private func sendWarningIfNeeded(childName: String, remaining: Int, today: String, notificationKey: String) {
        let key = "\(warningShownKey)_\(notificationKey)"
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "Schermtijd bijna op"
        content.body = "\(childName) heeft nog \(remaining) minuten schermtijd over."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "screentime_warning_\(notificationKey)_\(today)",
            content: content,
            trigger: nil // fire immediately
        )

        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] Warning notification error: \(error)")
            }
        }
    }

    private func sendExceededIfNeeded(childName: String, overBy: Int, today: String, notificationKey: String) {
        let key = "\(exceededShownKey)_\(notificationKey)"
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "Schermtijd overschreden"
        if overBy > 0 {
            content.body = "\(childName) zit \(overBy) minuten over de schermtijdlimiet."
        } else {
            content.body = "\(childName) heeft de schermtijdlimiet bereikt."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "screentime_exceeded_\(notificationKey)_\(today)",
            content: content,
            trigger: nil // fire immediately
        )

        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] Exceeded notification error: \(error)")
            }
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var screenTimeAlertsEnabled: Bool {
        guard UserDefaults.standard.object(forKey: screenTimeAlertsEnabledKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: screenTimeAlertsEnabledKey)
    }

    private func notificationChildKey(childName: String, childId: String?) -> String {
        let rawKey = childId?.isEmpty == false ? childId! : childName
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return rawKey.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
    }
}
