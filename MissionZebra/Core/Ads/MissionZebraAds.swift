import SwiftUI
import GoogleMobileAds

enum MissionZebraAdConfiguration {
    static let bannerAdUnitID = infoPlistValue(
        for: "MZAdMobBannerAdUnitID",
        fallback: "ca-app-pub-3940256099942544/2435281174"
    )
    static let interstitialAdUnitID = infoPlistValue(
        for: "MZAdMobInterstitialAdUnitID",
        fallback: "ca-app-pub-3940256099942544/4411468910"
    )

    private static func infoPlistValue(for key: String, fallback: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return value
    }
}

enum MissionZebraAdPrivacy {
    @MainActor
    static func applyForCurrentDeviceMode() {
        let session = SessionManager.shared.getRoleSession()
        let isEffectiveChildMode = session.isChildLocally || (!session.isParentLocally && SessionManager.shared.isDeviceForChild())

        if isEffectiveChildMode {
            applyForChildMode()
        } else {
            applyForParentMode()
        }
    }

    @MainActor
    static func applyForParentMode() {
        let configuration = MobileAds.shared.requestConfiguration

        configuration.maxAdContentRating = .general
        configuration.ageRestrictedTreatment = .unspecified
        configuration.publisherPrivacyPersonalizationState = .default
    }

    @MainActor
    static func applyForChildMode() {
        let configuration = MobileAds.shared.requestConfiguration

        configuration.maxAdContentRating = .general
        configuration.ageRestrictedTreatment = .child
        configuration.publisherPrivacyPersonalizationState = .disabled
    }
}

enum ParentAdVisibility {
    static func shouldShowParentAds(session: RoleSession, isPremium: Bool) -> Bool {
        session.isParentLocally && !isPremium
    }
}

struct MissionZebraBannerAd: View {
    @Environment(\.mzColors) private var colors
    @State private var loadState: AdLoadState = .loading

    let isVisible: Bool

    var body: some View {
        if isVisible {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("Advertentie")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(colors.onSurfaceVariant)

                    if loadState != .loaded {
                        Text(loadState.label)
                            .font(.caption2)
                            .foregroundColor(loadState == .failed ? .red : colors.onSurfaceVariant)
                    }

                    Spacer()
                }

                GeometryReader { proxy in
                    let width = max(proxy.size.width, 320)
                    let adSize = largeAnchoredAdaptiveBanner(width: width)

                    BannerViewContainer(
                        adSize: adSize,
                        onLoaded: { loadState = .loaded },
                        onFailed: { loadState = .failed }
                    )
                        .frame(width: adSize.size.width, height: adSize.size.height)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 70)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colors.outlineVariant, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct MissionZebraBottomBannerAd: View {
    @Environment(\.mzColors) private var colors
    @State private var loadState: AdLoadState = .loading
    @State private var adHeight: CGFloat = 50

    let isVisible: Bool

    var body: some View {
        if isVisible {
            VStack(spacing: 4) {
                HStack {
                    Text(loadState == .failed ? "Advertentie niet geladen" : "Advertentie")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(loadState == .failed ? .red : colors.onSurfaceVariant)
                    Spacer()
                }
                .padding(.horizontal, 12)

                GeometryReader { proxy in
                    let width = max(proxy.size.width, 320)
                    let adSize = largeAnchoredAdaptiveBanner(width: width)

                    BannerViewContainer(
                        adSize: adSize,
                        onLoaded: { loadState = .loaded },
                        onFailed: { loadState = .failed }
                    )
                    .frame(width: adSize.size.width, height: adSize.size.height)
                    .frame(maxWidth: .infinity)
                    .onAppear { updateAdHeight(adSize.size.height) }
                    .onChange(of: proxy.size.width) { _ in
                        updateAdHeight(adSize.size.height)
                    }
                }
                .frame(height: adHeight)
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
            .background(
                Rectangle()
                    .fill(colors.surface)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: -1)
            )
        }
    }

    private func updateAdHeight(_ height: CGFloat) {
        let clampedHeight = max(50, height)
        guard abs(adHeight - clampedHeight) > 0.5 else { return }
        DispatchQueue.main.async {
            adHeight = clampedHeight
        }
    }
}

private enum AdLoadState: Equatable {
    case loading
    case loaded
    case failed

    var label: String {
        switch self {
        case .loading: return "laden..."
        case .loaded: return ""
        case .failed: return "niet geladen"
        }
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let adSize: AdSize
    let onLoaded: () -> Void
    let onFailed: () -> Void

    func makeUIView(context: Context) -> BannerView {
        MissionZebraAdPrivacy.applyForParentMode()

        let banner = BannerView(adSize: adSize)
        banner.adUnitID = MissionZebraAdConfiguration.bannerAdUnitID
        banner.rootViewController = UIApplication.shared.mzTopViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context _: Context) {
        banner.rootViewController = UIApplication.shared.mzTopViewController()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoaded: onLoaded, onFailed: onFailed)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let onLoaded: () -> Void
        let onFailed: () -> Void

        init(onLoaded: @escaping () -> Void, onFailed: @escaping () -> Void) {
            self.onLoaded = onLoaded
            self.onFailed = onFailed
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onLoaded()
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[Ads] Banner failed to load: \(error.localizedDescription)")
            onFailed()
        }
    }
}

@MainActor
final class MissionZebraInterstitialAd: NSObject, ObservableObject, FullScreenContentDelegate {
    private static let minimumInterval: TimeInterval = 20
    private static let actionRangeBeforeAd = 2...4
    private static var lastShownAt: Date?
    private static var actionsSinceLastAd = 0
    private static var requiredActionsBeforeNextAd = Int.random(in: actionRangeBeforeAd)

    private var interstitial: InterstitialAd?
    private var isLoading = false

    override init() {
        super.init()
        load()
    }

    func reloadForParentMode(isVisible: Bool) {
        guard isVisible else { return }
        interstitial = nil
        isLoading = false
        load(forceParentMode: true)
    }

    func showIfAvailable(isVisible: Bool) {
        guard isVisible else { return }
        Self.actionsSinceLastAd += 1
        guard Self.actionsSinceLastAd >= Self.requiredActionsBeforeNextAd else {
            if interstitial == nil {
                load(forceParentMode: true)
            }
            return
        }
        guard Self.canShowNow else { return }

        guard let interstitial,
              let rootViewController = UIApplication.shared.mzTopViewController() else {
            load(forceParentMode: true)
            return
        }

        self.interstitial = nil
        Self.lastShownAt = Date()
        Self.actionsSinceLastAd = 0
        Self.requiredActionsBeforeNextAd = Int.random(in: Self.actionRangeBeforeAd)
        interstitial.present(from: rootViewController)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        load(forceParentMode: true)
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        load(forceParentMode: true)
    }

    private func load(forceParentMode: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        if forceParentMode {
            MissionZebraAdPrivacy.applyForParentMode()
        } else {
            MissionZebraAdPrivacy.applyForCurrentDeviceMode()
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let ad = try await InterstitialAd.load(
                    with: MissionZebraAdConfiguration.interstitialAdUnitID,
                    request: Request()
                )
                ad.fullScreenContentDelegate = self
                interstitial = ad
            } catch {
                interstitial = nil
                print("[Ads] Interstitial failed to load: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    private static var canShowNow: Bool {
        guard let lastShownAt else { return true }
        return Date().timeIntervalSince(lastShownAt) >= minimumInterval
    }
}

private extension UIApplication {
    func mzTopViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    ) -> UIViewController? {
        if let navigation = base as? UINavigationController {
            return mzTopViewController(base: navigation.visibleViewController)
        }
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return mzTopViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return mzTopViewController(base: presented)
        }
        return base
    }
}
