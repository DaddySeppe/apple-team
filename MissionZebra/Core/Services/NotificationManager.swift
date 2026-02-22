import Foundation
import UserNotifications

/// Manages local push notifications for screen time alerts.
/// Sends notifications like Snapchat-style banners when a child
/// is approaching or exceeding their daily screen time limit.
class NotificationManager {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // Keys to prevent spamming the same notification repeatedly
    private let warningShownKey = "notification_warning_shown_date"
    private let exceededShownKey = "notification_exceeded_shown_date"

    private init() {}

    // MARK: - Permission

    /// Request notification permission. Call this early (e.g. in AppDelegate).
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NotificationManager] Permission error: \(error.localizedDescription)")
            }
            print("[NotificationManager] Permission granted: \(granted)")
        }
    }

    // MARK: - Screen Time Notifications

    /// Call this after every screen time sync to check whether a notification should fire.
    /// - Parameters:
    ///   - childName: The name of the child (for the notification text)
    ///   - usedMinutes: Minutes of screen time used today
    ///   - limitMinutes: The configured daily limit in minutes
    func checkAndNotify(childName: String, usedMinutes: Int, limitMinutes: Int) {
        guard limitMinutes > 0 else { return }

        let today = todayString()
        let percentage = Double(usedMinutes) / Double(limitMinutes)
        let remaining = limitMinutes - usedMinutes

        // 1) Warning at 90% of limit (or 5 min remaining, whichever comes first)
        if percentage >= 0.9 && remaining > 0 {
            sendWarningIfNeeded(childName: childName, remaining: remaining, today: today)
        }

        // 2) Exceeded limit
        if usedMinutes >= limitMinutes {
            let overBy = usedMinutes - limitMinutes
            sendExceededIfNeeded(childName: childName, overBy: overBy, today: today)
        }
    }

    // MARK: - Private

    private func sendWarningIfNeeded(childName: String, remaining: Int, today: String) {
        let key = warningShownKey
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "⏰ Schermtijd bijna op!"
        content.body = "\(childName) heeft nog \(remaining) minuten schermtijd over."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "screentime_warning_\(today)",
            content: content,
            trigger: nil // fire immediately
        )

        center.add(request) { error in
            if let error = error {
                print("[NotificationManager] Warning notification error: \(error)")
            }
        }
    }

    private func sendExceededIfNeeded(childName: String, overBy: Int, today: String) {
        let key = exceededShownKey
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "🚨 Schermtijd overschreden!"
        if overBy > 0 {
            content.body = "\(childName) zit \(overBy) minuten over de schermtijdlimiet."
        } else {
            content.body = "\(childName) heeft de schermtijdlimiet bereikt."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "screentime_exceeded_\(today)",
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
}
