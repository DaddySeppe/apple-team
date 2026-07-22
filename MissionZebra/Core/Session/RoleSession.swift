import Foundation

struct RoleSession: Equatable {
    let role: String?
    let isLoggedIn: Bool
    let firebaseUid: String?
    let childId: String?
    let childName: String?

    var isParentLocally: Bool {
        isLoggedIn && role == SessionManager.roleParent
    }

    var isChildLocally: Bool {
        isLoggedIn &&
            role == SessionManager.roleChild &&
            !(childId ?? "").isEmpty
    }

    var isParent: Bool {
        isParentLocally && firebaseUid != nil
    }

    var isChild: Bool {
        isChildLocally && firebaseUid != nil
    }
}

struct DeviceSession: Equatable {
    let deviceId: String
    let deviceName: String
    let isDeviceForChild: Bool
    let isSharedChildDevice: Bool
}
