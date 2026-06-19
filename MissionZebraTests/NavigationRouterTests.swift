import XCTest
@testable import MissionZebra

final class NavigationRouterTests: XCTestCase {
    func testResetReplacesRootAndClearsBackStack() {
        let router = NavigationRouter(rootRoute: .parentDashboard)
        router.navigate(to: .parentPremiumDashboard)
        XCTAssertEqual(router.path.count, 1)

        router.reset(to: .welcome)

        XCTAssertEqual(router.rootRoute, .welcome)
        XCTAssertEqual(router.path.count, 0)
    }
}
