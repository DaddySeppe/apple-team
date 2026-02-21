import Foundation
import FirebaseAuth

class ParentPinManager {

    static let shared = ParentPinManager()

    private let suiteName = "missionzebra_device_prefs"

    private init() {}

    private func oldKeyForUser(_ uid: String) -> String {
        return "parent_pin_\(uid)"
    }

    private func hashKeyForUser(_ uid: String) -> String {
        return "parent_pin_hash_\(uid)"
    }

    private func saltKeyForUser(_ uid: String) -> String {
        return "parent_pin_salt_\(uid)"
    }

    private func currentUid() -> String? {
        return Auth.auth().currentUser?.uid
    }

    private func getDefaults() -> UserDefaults {
        return UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }

    private func getStoredHashAndSalt() -> (hash: String, salt: String)? {
        guard let uid = currentUid() else { return nil }
        let defaults = getDefaults()
        guard let hash = defaults.string(forKey: hashKeyForUser(uid)),
              let salt = defaults.string(forKey: saltKeyForUser(uid)),
              !hash.isEmpty, !salt.isEmpty else {
            return nil
        }
        return (hash, salt)
    }

    private func getOldPlainPin() -> String? {
        guard let uid = currentUid() else { return nil }
        let defaults = getDefaults()
        return defaults.string(forKey: oldKeyForUser(uid))
    }

    func setParentPin(_ pin: String) {
        guard let uid = currentUid() else { return }
        let defaults = getDefaults()
        let salt = PinSecurity.generateSalt()
        let hash = PinSecurity.hashPin(pin, salt: salt)
        defaults.set(hash, forKey: hashKeyForUser(uid))
        defaults.set(salt, forKey: saltKeyForUser(uid))
        defaults.removeObject(forKey: oldKeyForUser(uid))
    }

    func setParentPinHashed(hash: String, salt: String) {
        guard let uid = currentUid() else { return }
        let defaults = getDefaults()
        defaults.set(hash, forKey: hashKeyForUser(uid))
        defaults.set(salt, forKey: saltKeyForUser(uid))
        defaults.removeObject(forKey: oldKeyForUser(uid))
    }

    func hasParentPin() -> Bool {
        if getStoredHashAndSalt() != nil { return true }
        if getOldPlainPin() != nil { return true }
        return false
    }

    func checkPin(_ pin: String) -> Bool {
        guard let uid = currentUid() else { return false }
        let defaults = getDefaults()

        if let stored = getStoredHashAndSalt() {
            return PinSecurity.verifyPin(pin, salt: stored.salt, expectedHash: stored.hash)
        }

        if let oldPin = getOldPlainPin() {
            let isValid = oldPin == pin
            if isValid {
                let salt = PinSecurity.generateSalt()
                let hash = PinSecurity.hashPin(pin, salt: salt)
                defaults.set(hash, forKey: hashKeyForUser(uid))
                defaults.set(salt, forKey: saltKeyForUser(uid))
                defaults.removeObject(forKey: oldKeyForUser(uid))
            }
            return isValid
        }

        return false
    }

    func clearParentPin() {
        guard let uid = currentUid() else { return }
        let defaults = getDefaults()
        defaults.removeObject(forKey: hashKeyForUser(uid))
        defaults.removeObject(forKey: saltKeyForUser(uid))
        defaults.removeObject(forKey: oldKeyForUser(uid))
    }
}
