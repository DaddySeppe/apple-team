import Foundation
import FirebaseAuth

class SessionManager {

    static let shared = SessionManager()

    private let prefsName = "missionzebra_session"
    private let keyIsLoggedIn = "is_logged_in"
    private let keyRole = "role"
    private let keyChildId = "child_id"
    private let keyChildName = "child_name"
    private let keyDeviceForChild = "device_for_child"

    static let roleParent = "parent"
    static let roleChild = "child"

    private init() {}

    private func defaults() -> UserDefaults {
        return UserDefaults(suiteName: prefsName) ?? UserDefaults.standard
    }

    func setParentLoggedIn() {
        let d = defaults()
        d.set(true, forKey: keyIsLoggedIn)
        d.set(SessionManager.roleParent, forKey: keyRole)
    }

    func setChildLoggedIn(childId: String, childName: String) {
        let d = defaults()
        d.set(true, forKey: keyIsLoggedIn)
        d.set(SessionManager.roleChild, forKey: keyRole)
        d.set(childId, forKey: keyChildId)
        d.set(childName, forKey: keyChildName)
    }

    func clearSession() {
        let d = defaults()
        d.set(false, forKey: keyIsLoggedIn)
        d.removeObject(forKey: keyRole)
        d.removeObject(forKey: keyChildId)
        d.removeObject(forKey: keyChildName)
    }

    func setDeviceForChild(_ forChild: Bool) {
        let d = defaults()
        d.set(forChild, forKey: keyDeviceForChild)
    }

    func isDeviceForChild() -> Bool {
        return defaults().bool(forKey: keyDeviceForChild)
    }

    func getStartDestination() -> String {
        let d = defaults()
        let deviceForChild = d.bool(forKey: keyDeviceForChild)
        let loggedIn = d.bool(forKey: keyIsLoggedIn)
        let role = d.string(forKey: keyRole)
        let firebaseUser = Auth.auth().currentUser

        // 1) Als iemand ingelogd is EN Firebase ook nog een user heeft: laat die rol winnen
        if loggedIn, let role = role, firebaseUser != nil {
            switch role {
            case SessionManager.roleParent:
                return "parentDashboard"
            case SessionManager.roleChild:
                let childId = d.string(forKey: keyChildId) ?? ""
                let childName = d.string(forKey: keyChildName) ?? "Zebra"
                if !childId.isEmpty {
                    return "childDashboard/\(childId)/\(childName)"
                } else {
                    return "childLogin"
                }
            default:
                return deviceForChild ? "childLogin" : "welcome"
            }
        }

        // 2) Als SharedPreferences zegt ingelogd maar Firebase-user is weg: verouderde sessie opruimen
        if loggedIn && firebaseUser == nil {
            clearSession()
        }

        // 3) Niemand ingelogd: alleen naar childLogin als er ook echt een Firebase-user is
        if deviceForChild && firebaseUser != nil {
            return "childLogin"
        } else {
            return "welcome"
        }
    }
}
