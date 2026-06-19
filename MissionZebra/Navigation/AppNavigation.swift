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
            ParentRoute {
                ParentDashboardScreen()
            }
        case "childLogin":
            ChildLoginScreen()
        case let dest where dest.starts(with: "childDashboard/"):
            let parts = dest.split(separator: "/")
            if parts.count >= 3 {
                ChildDashboardRoute {
                    ChildDashboardScreen(
                        childId: String(parts[1]),
                        childName: String(parts[2])
                    )
                }
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
            ParentRoute {
                DeviceModeScreen()
            }
        case .parentDashboard:
            ParentRoute {
                ParentDashboardScreen()
            }
        case .childLogin:
            ChildLoginScreen()
        case .parentPremiumDashboard:
            ParentRoute {
                ParentPremiumDashboardScreen()
            }
        case .parentScreenTimeControl:
            ParentRoute {
                ParentScreenTimeControlScreen()
            }
        case .privacyPolicy:
            PrivacyPolicyScreen()
        case .parentOnlineSafety:
            ParentRoute {
                ParentOnlineSafetyScreen()
            }
        case .taskCalendar:
            ParentRoute {
                TaskCalendarScreen()
            }
        case .childDashboard(let childId, let childName):
            ChildDashboardRoute {
                ChildDashboardScreen(childId: childId, childName: childName)
            }
        }
    }
}

struct ParentRoute<Content: View>: View {
    @EnvironmentObject private var router: NavigationRouter
    @State private var isRefreshingPinState = false
    @State private var attemptedRemotePinRefresh = false
    @State private var remotePinConfigured = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var hasFirebaseUser: Bool {
        SessionManager.shared.getRoleSession().firebaseUid != nil
    }

    private var allowed: Bool {
        SessionManager.shared.getRoleSession().isParent &&
            (ParentPinManager.shared.hasParentPin() || remotePinConfigured)
    }

    private var redirect: RouteRedirect? {
        RouteGuardPolicy.parentRedirect(
            session: SessionManager.shared.getRoleSession(),
            hasParentPin: ParentPinManager.shared.hasParentPin() || remotePinConfigured
        )
    }

    var body: some View {
        Group {
            if allowed {
                content
            } else if isRefreshingPinState {
                ProgressView()
                    .task { await refreshPinState() }
            } else {
                Color.clear
                    .task { await redirectIfNeeded() }
            }
        }
    }

    @MainActor
    private func refreshPinState() async {
        remotePinConfigured = await ParentPinManager.shared.refreshParentPinConfigured()
        attemptedRemotePinRefresh = true
        isRefreshingPinState = false
        if !allowed {
            await redirectIfNeeded()
        }
    }

    @MainActor
    private func redirectIfNeeded() async {
        if redirect == nil { return }
        if hasFirebaseUser && !attemptedRemotePinRefresh && !isRefreshingPinState {
            isRefreshingPinState = true
            await refreshPinState()
            return
        }
        router.goToRoot()
        router.navigate(to: redirect == .parentLogin ? .parentLogin : .welcome)
    }
}

struct ChildDashboardRoute<Content: View>: View {
    @EnvironmentObject private var router: NavigationRouter
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var hasFirebaseUser: Bool {
        SessionManager.shared.getRoleSession().firebaseUid != nil
    }

    private var allowed: Bool {
        SessionManager.shared.getRoleSession().isChild
    }

    private var redirect: RouteRedirect? {
        RouteGuardPolicy.childDashboardRedirect(session: SessionManager.shared.getRoleSession())
    }

    var body: some View {
        Group {
            if allowed {
                content
            } else {
                Color.clear
                    .task { redirectIfNeeded() }
            }
        }
    }

    @MainActor
    private func redirectIfNeeded() {
        guard let redirect else { return }
        router.goToRoot()
        router.navigate(to: redirect == .childLogin ? .childLogin : .welcome)
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
