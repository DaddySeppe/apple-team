import SwiftUI

// MARK: - Banner Ad View (Stub – Ads disabled for development)

struct BannerAdView: View {
    let adUnitID: String

    var body: some View {
        // Placeholder – ads disabled during development
        EmptyView()
    }
}

// MARK: - Interstitial Ad Helper (Stub)

final class InterstitialAdManager: ObservableObject {
    @Published var isReady = false
    private let adUnitID: String

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    func loadAd() {
        // No-op – ads disabled during development
    }

    func showAd() {
        // No-op – ads disabled during development
    }
}
