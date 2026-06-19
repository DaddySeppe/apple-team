import Foundation
import FirebaseAuth
import FirebaseFirestore

class ParentPinManager {

    static let shared = ParentPinManager()

    private let suiteName = "missionzebra_device_prefs"
    private let keyFailedAttempts = "parent_pin_failed_attempts"
    private let keyLockedUntil = "parent_pin_locked_until"
    private let keyParentPinConfigured = "parent_pin_configured"
    private let firestore = Firestore.firestore()

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

    private func configuredKeyForUser(_ uid: String) -> String {
        return "\(keyParentPinConfigured)_\(uid)"
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
        defaults.set(true, forKey: configuredKeyForUser(uid))
        defaults.removeObject(forKey: oldKeyForUser(uid))
        clearFailures()
        markParentPinConfiguredRemotely(uid: uid)
    }

    func setParentPinHashed(hash: String, salt: String) {
        guard let uid = currentUid() else { return }
        let defaults = getDefaults()
        defaults.set(hash, forKey: hashKeyForUser(uid))
        defaults.set(salt, forKey: saltKeyForUser(uid))
        defaults.set(true, forKey: configuredKeyForUser(uid))
        defaults.removeObject(forKey: oldKeyForUser(uid))
        clearFailures()
        markParentPinConfiguredRemotely(uid: uid)
    }

    func hasParentPin() -> Bool {
        guard let uid = currentUid() else { return false }
        if getStoredHashAndSalt() != nil { return true }
        if getOldPlainPin() != nil { return true }
        if getDefaults().bool(forKey: configuredKeyForUser(uid)) { return true }
        return false
    }

    func refreshParentPinConfigured() async -> Bool {
        guard let uid = currentUid() else { return false }
        if hasParentPin() { return true }

        do {
            let snapshot = try await firestore.collection("parents").document(uid).getDocument()
            let configured = snapshot.data()?["parentPinConfigured"] as? Bool == true ||
                !((snapshot.data()?["pinHash"] as? String) ?? "").isEmpty
            if configured {
                getDefaults().set(true, forKey: configuredKeyForUser(uid))
            }
            return configured
        } catch {
            return false
        }
    }

    func isLockedOut() -> Bool {
        lockoutRemainingMillis() > 0
    }

    func lockoutRemainingMillis(nowMillis: Int64 = ParentPinManager.nowMillis()) -> Int64 {
        let lockedUntil = Int64(getDefaults().double(forKey: keyLockedUntil))
        return PinLockoutPolicy.remainingMillis(
            state: PinLockoutState(lockedUntilMillis: lockedUntil),
            nowMillis: nowMillis
        )
    }

    func checkPin(_ pin: String) -> Bool {
        guard currentUid() != nil else { return false }
        if isLockedOut() { return false }

        if let stored = getStoredHashAndSalt() {
            let isValid = PinSecurity.verifyPin(pin, salt: stored.salt, expectedHash: stored.hash)
            if isValid {
                if !PinSecurity.isVersionedHash(stored.hash) {
                    setParentPin(pin)
                } else {
                    clearFailures()
                }
            } else {
                recordFailure()
            }
            return isValid
        }

        if let oldPin = getOldPlainPin() {
            let isValid = oldPin == pin
            if isValid {
                setParentPin(pin)
            } else {
                recordFailure()
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
        defaults.removeObject(forKey: configuredKeyForUser(uid))
        clearFailures()
    }

    private func markParentPinConfiguredRemotely(uid: String) {
        firestore.collection("parents").document(uid).setData([
            "parentPinConfigured": true
        ], merge: true)
    }

    private func clearFailures() {
        let defaults = getDefaults()
        defaults.removeObject(forKey: keyFailedAttempts)
        defaults.removeObject(forKey: keyLockedUntil)
    }

    private func recordFailure(nowMillis: Int64 = ParentPinManager.nowMillis()) {
        let defaults = getDefaults()
        let next = PinLockoutPolicy.recordFailure(
            state: PinLockoutState(
                failedAttempts: defaults.integer(forKey: keyFailedAttempts),
                lockedUntilMillis: Int64(defaults.double(forKey: keyLockedUntil))
            ),
            nowMillis: nowMillis
        )
        defaults.set(next.failedAttempts, forKey: keyFailedAttempts)
        defaults.set(Double(next.lockedUntilMillis), forKey: keyLockedUntil)
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
