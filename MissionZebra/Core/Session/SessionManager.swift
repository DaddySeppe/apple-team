import Foundation
import FirebaseAuth
import UIKit

class SessionManager {

    static let shared = SessionManager()

    private let prefsName = "missionzebra_session"
    private let keyIsLoggedIn = "is_logged_in"
    private let keyRole = "role"
    private let keyChildId = "child_id"
    private let keyChildName = "child_name"
    private let keyChildSelectedAtMillis = "child_selected_at_millis"
    private let keyDeviceForChild = "device_for_child"
    private let keySharedChildDevice = "shared_child_device"
    private let keyDeviceModeConfigured = "device_mode_configured"
    private let keyDeviceId = "device_id"
    private let keyDeviceName = "device_name"
    private let keyTutorialActive = "tutorial_active"

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
        d.set(false, forKey: keyDeviceForChild)
        d.set(false, forKey: keySharedChildDevice)
        d.set(true, forKey: keyDeviceModeConfigured)
        d.removeObject(forKey: keyChildId)
        d.removeObject(forKey: keyChildName)
        d.removeObject(forKey: keyChildSelectedAtMillis)
    }

    func setChildLoggedIn(childId: String, childName: String) {
        let d = defaults()
        let previousChildId = d.string(forKey: keyChildId)
        let previousSelectedAt = d.double(forKey: keyChildSelectedAtMillis)
        let selectedAt = (previousChildId == childId && previousSelectedAt > 0)
            ? previousSelectedAt
            : Date().timeIntervalSince1970 * 1000

        d.set(true, forKey: keyIsLoggedIn)
        d.set(SessionManager.roleChild, forKey: keyRole)
        d.set(true, forKey: keyDeviceForChild)
        d.set(true, forKey: keyDeviceModeConfigured)
        d.set(childId, forKey: keyChildId)
        d.set(childName, forKey: keyChildName)
        d.set(selectedAt, forKey: keyChildSelectedAtMillis)
    }

    func clearSession() {
        let d = defaults()
        d.set(false, forKey: keyIsLoggedIn)
        d.removeObject(forKey: keyRole)
        d.removeObject(forKey: keyChildId)
        d.removeObject(forKey: keyChildName)
        d.removeObject(forKey: keyChildSelectedAtMillis)
    }

    func clearTutorial() {
        defaults().removeObject(forKey: keyTutorialActive)
    }

    func setDeviceForChild(_ forChild: Bool) {
        let d = defaults()
        d.set(forChild, forKey: keyDeviceForChild)
        d.set(false, forKey: keySharedChildDevice)
        d.set(true, forKey: keyDeviceModeConfigured)
    }

    func openChildModeFromParent() {
        let d = defaults()
        d.set(true, forKey: keyIsLoggedIn)
        d.set(SessionManager.roleParent, forKey: keyRole)
        d.set(true, forKey: keyDeviceForChild)
        d.set(false, forKey: keySharedChildDevice)
        d.set(true, forKey: keyDeviceModeConfigured)
        d.removeObject(forKey: keyChildId)
        d.removeObject(forKey: keyChildName)
        d.removeObject(forKey: keyChildSelectedAtMillis)
    }

    func openSharedChildModeFromParent() {
        let d = defaults()
        d.set(true, forKey: keyIsLoggedIn)
        d.set(SessionManager.roleParent, forKey: keyRole)
        d.set(true, forKey: keyDeviceForChild)
        d.set(true, forKey: keySharedChildDevice)
        d.set(true, forKey: keyDeviceModeConfigured)
        d.removeObject(forKey: keyChildId)
        d.removeObject(forKey: keyChildName)
        d.removeObject(forKey: keyChildSelectedAtMillis)
    }

    func isDeviceForChild() -> Bool {
        return defaults().bool(forKey: keyDeviceForChild)
    }

    func setSharedChildDevice(_ shared: Bool) {
        let d = defaults()
        d.set(shared, forKey: keyDeviceForChild)
        d.set(shared, forKey: keySharedChildDevice)
        d.set(true, forKey: keyDeviceModeConfigured)
        d.removeObject(forKey: keyChildId)
        d.removeObject(forKey: keyChildName)
        d.removeObject(forKey: keyChildSelectedAtMillis)
    }

    func isSharedChildDevice() -> Bool {
        defaults().bool(forKey: keySharedChildDevice)
    }

    func isDeviceModeConfigured() -> Bool {
        defaults().bool(forKey: keyDeviceModeConfigured)
    }

    func clearActiveChild() {
        let d = defaults()
        d.removeObject(forKey: keyChildId)
        d.removeObject(forKey: keyChildName)
        d.removeObject(forKey: keyChildSelectedAtMillis)
    }

    func getActiveChildSelectedAtMillis() -> Int64? {
        let selectedAt = Int64(defaults().double(forKey: keyChildSelectedAtMillis))
        return selectedAt > 0 ? selectedAt : nil
    }

    func getDeviceId() -> String {
        let d = defaults()
        if let existing = d.string(forKey: keyDeviceId), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        d.set(id, forKey: keyDeviceId)
        return id
    }

    func getDeviceName() -> String {
        defaults().string(forKey: keyDeviceName) ?? UIDevice.current.name
    }

    func setDeviceName(_ name: String) {
        defaults().set(name, forKey: keyDeviceName)
    }

    func hasParentSession() -> Bool {
        getRoleSession().isParentLocally
    }

    func hasChildSession() -> Bool {
        getRoleSession().isChildLocally
    }

    func getRoleSession() -> RoleSession {
        let d = defaults()
        return RoleSession(
            role: d.string(forKey: keyRole),
            isLoggedIn: d.bool(forKey: keyIsLoggedIn),
            firebaseUid: Auth.auth().currentUser?.uid,
            childId: d.string(forKey: keyChildId),
            childName: d.string(forKey: keyChildName)
        )
    }

    func getDeviceSession() -> DeviceSession {
        DeviceSession(
            deviceId: getDeviceId(),
            deviceName: getDeviceName(),
            isDeviceForChild: isDeviceForChild(),
            isSharedChildDevice: isSharedChildDevice()
        )
    }

    func getStartDestination() -> String {
        let roleSession = getRoleSession()
        let deviceSession = getDeviceSession()
        let firebaseUser = Auth.auth().currentUser

        if deviceSession.isDeviceForChild && deviceSession.isSharedChildDevice && firebaseUser != nil {
            return "childLogin"
        }

        // 1) Als lokaal een rol actief is: laat die rol winnen. De route guard
        // wacht kort op Firebase Auth, zodat appstart niet voelt als random uitloggen.
        if roleSession.isLoggedIn, let role = roleSession.role {
            switch role {
            case SessionManager.roleParent:
                return "parentDashboard"
            case SessionManager.roleChild:
                let childId = roleSession.childId ?? ""
                let childName = roleSession.childName ?? "Zebra"
                if !childId.isEmpty {
                    return "childDashboard/\(childId)/\(childName)"
                } else {
                    return "childLogin"
                }
            default:
                return deviceSession.isDeviceForChild ? "childLogin" : "welcome"
            }
        }

        // 2) Niemand ingelogd: alleen naar childLogin als er ook echt een Firebase-user is
        if deviceSession.isDeviceForChild && firebaseUser != nil {
            return "childLogin"
        } else {
            return "welcome"
        }
    }
}
