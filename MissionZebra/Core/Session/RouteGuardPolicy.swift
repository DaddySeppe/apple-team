import Foundation

enum RouteRedirect: Equatable {
    case welcome
    case parentLogin
    case childLogin
}

enum RouteGuardPolicy {
    static func parentRedirect(session: RoleSession, hasParentPin: Bool) -> RouteRedirect? {
        if session.isParentLocally && hasParentPin { return nil }
        return .parentLogin
    }

    static func childDashboardRedirect(session: RoleSession) -> RouteRedirect? {
        if session.isChildLocally, let childId = session.childId, !childId.isEmpty { return nil }
        return .childLogin
    }
}
