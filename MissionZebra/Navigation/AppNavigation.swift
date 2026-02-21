import SwiftUI

enum AppRoute: Hashable {
    case welcome
    case parentLogin
    case deviceMode
    case parentDashboard
    case childLogin
    case parentPremiumDashboard
    case parentScreenTimeControl
    case privacyPolicy
    case parentOnlineSafety
    case taskCalendar
    case childDashboard(childId: String, childName: String)
}

struct AppNavigation: View {
    @StateObject private var router = NavigationRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
        }
        .environmentObject(router)
    }

    @ViewBuilder
    private var rootView: some View {
        let startDest = SessionManager.shared.getStartDestination()
        switch startDest {
        case "parentDashboard":
            ParentDashboardScreen()
        case "childLogin":
            ChildLoginScreen()
        case let dest where dest.starts(with: "childDashboard/"):
            let parts = dest.split(separator: "/")
            if parts.count >= 3 {
                ChildDashboardScreen(
                    childId: String(parts[1]),
                    childName: String(parts[2])
                )
            } else {
                WelcomeScreen()
            }
        default:
            WelcomeScreen()
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .welcome:
            WelcomeScreen()
        case .parentLogin:
            ParentLoginScreen()
        case .deviceMode:
            DeviceModeScreen()
        case .parentDashboard:
            ParentDashboardScreen()
        case .childLogin:
            ChildLoginScreen()
        case .parentPremiumDashboard:
            ParentPremiumDashboardScreen()
        case .parentScreenTimeControl:
            ParentScreenTimeControlScreen()
        case .privacyPolicy:
            PrivacyPolicyScreen()
        case .parentOnlineSafety:
            ParentOnlineSafetyScreen()
        case .taskCalendar:
            TaskCalendarScreen()
        case .childDashboard(let childId, let childName):
            ChildDashboardScreen(childId: childId, childName: childName)
        }
    }
}

class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func goBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func goToRoot() {
        path = NavigationPath()
    }
}
