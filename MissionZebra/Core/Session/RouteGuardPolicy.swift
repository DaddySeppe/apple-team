import Foundation

enum RouteRedirect: Equatable {
    case welcome
    case parentLogin
    case childLogin
}

enum RouteGuardPolicy {
    static func parentRedirect(session: RoleSession, hasParentPin: Bool) -> RouteRedirect? {
        if session.isParent && hasParentPin { return nil }
        return session.firebaseUid == nil ? .welcome : .parentLogin
    }

    static func childDashboardRedirect(session: RoleSession) -> RouteRedirect? {
        if session.isChild { return nil }
        return session.firebaseUid == nil ? .welcome : .childLogin
    }
}
