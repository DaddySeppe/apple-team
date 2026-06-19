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
    @StateObject private var router: NavigationRouter

    init() {
        _router = StateObject(wrappedValue: NavigationRouter(rootRoute: Self.startRoute()))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            destinationView(for: router.rootRoute)
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
        }
        .environmentObject(router)
    }

    private static func startRoute() -> AppRoute {
        let startDest = SessionManager.shared.getStartDestination()
        switch startDest {
        case "parentDashboard":
            return .parentDashboard
        case "childLogin":
            return .childLogin
        case let dest where dest.starts(with: "childDashboard/"):
            let parts = dest.split(separator: "/")
            if parts.count >= 3 {
                return .childDashboard(childId: String(parts[1]), childName: String(parts[2]))
            }
            return .welcome
        default:
            return .welcome
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
        router.reset(to: redirect == .parentLogin ? .parentLogin : .welcome)
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
        router.reset(to: redirect == .childLogin ? .childLogin : .welcome)
    }
}

class NavigationRouter: ObservableObject {
    @Published var rootRoute: AppRoute
    @Published var path = NavigationPath()

    init(rootRoute: AppRoute = .welcome) {
        self.rootRoute = rootRoute
    }

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

    func reset(to route: AppRoute) {
        path = NavigationPath()
        rootRoute = route
    }
}
