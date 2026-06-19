import Foundation

struct RoleSession: Equatable {
    let role: String?
    let isLoggedIn: Bool
    let firebaseUid: String?
    let childId: String?
    let childName: String?

    var isParent: Bool {
        isLoggedIn && role == SessionManager.roleParent && firebaseUid != nil
    }

    var isChild: Bool {
        isLoggedIn &&
            role == SessionManager.roleChild &&
            firebaseUid != nil &&
            !(childId ?? "").isEmpty
    }
}

struct DeviceSession: Equatable {
    let deviceId: String
    let deviceName: String
    let isDeviceForChild: Bool
    let isSharedChildDevice: Bool
}
