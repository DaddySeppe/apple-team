import XCTest
@testable import MissionZebra

final class RouteGuardPolicyTests: XCTestCase {
    func testParentRouteAllowsOnlyParentWithPinAndFirebaseUser() {
        let parent = RoleSession(
            role: SessionManager.roleParent,
            isLoggedIn: true,
            firebaseUid: "uid",
            childId: nil,
            childName: nil
        )

        XCTAssertNil(RouteGuardPolicy.parentRedirect(session: parent, hasParentPin: true))
        XCTAssertEqual(RouteGuardPolicy.parentRedirect(session: parent, hasParentPin: false), .parentLogin)
    }

    func testParentRouteRedirectsMissingFirebaseUserToWelcome() {
        let staleParent = RoleSession(
            role: SessionManager.roleParent,
            isLoggedIn: true,
            firebaseUid: nil,
            childId: nil,
            childName: nil
        )

        XCTAssertEqual(RouteGuardPolicy.parentRedirect(session: staleParent, hasParentPin: true), .welcome)
    }

    func testChildDashboardAllowsOnlyChildRoleWithSelectedChild() {
        let child = RoleSession(
            role: SessionManager.roleChild,
            isLoggedIn: true,
            firebaseUid: "uid",
            childId: "child-1",
            childName: "Zebra"
        )
        let parent = RoleSession(
            role: SessionManager.roleParent,
            isLoggedIn: true,
            firebaseUid: "uid",
            childId: nil,
            childName: nil
        )

        XCTAssertNil(RouteGuardPolicy.childDashboardRedirect(session: child))
        XCTAssertEqual(RouteGuardPolicy.childDashboardRedirect(session: parent), .childLogin)
    }
}
