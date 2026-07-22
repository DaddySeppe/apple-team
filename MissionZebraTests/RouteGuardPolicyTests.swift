import XCTest
@testable import MissionZebra

final class RouteGuardPolicyTests: XCTestCase {
    func testParentRouteAllowsLocalParentWithPin() {
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

    func testParentRouteDoesNotLogoutWhenFirebaseUserTemporarilyMissing() {
        let staleParent = RoleSession(
            role: SessionManager.roleParent,
            isLoggedIn: true,
            firebaseUid: nil,
            childId: nil,
            childName: nil
        )

        XCTAssertNil(RouteGuardPolicy.parentRedirect(session: staleParent, hasParentPin: true))
    }

    func testParentAdsStayVisibleWhenFirebaseUserTemporarilyMissing() {
        let staleParent = RoleSession(
            role: SessionManager.roleParent,
            isLoggedIn: true,
            firebaseUid: nil,
            childId: nil,
            childName: nil
        )

        XCTAssertTrue(ParentAdVisibility.shouldShowParentAds(session: staleParent, isPremium: false))
        XCTAssertFalse(ParentAdVisibility.shouldShowParentAds(session: staleParent, isPremium: true))
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

    func testChildDashboardRedirectsChildRoleWithoutSelectedChild() {
        let missingChild = RoleSession(
            role: SessionManager.roleChild,
            isLoggedIn: true,
            firebaseUid: "uid",
            childId: nil,
            childName: nil
        )

        XCTAssertEqual(RouteGuardPolicy.childDashboardRedirect(session: missingChild), .childLogin)
    }

    func testChildDashboardDoesNotLogoutWhenFirebaseUserTemporarilyMissing() {
        let child = RoleSession(
            role: SessionManager.roleChild,
            isLoggedIn: true,
            firebaseUid: nil,
            childId: "child-1",
            childName: "Zebra"
        )

        XCTAssertNil(RouteGuardPolicy.childDashboardRedirect(session: child))
    }
}
