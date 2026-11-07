import GoogleMobileAds
import SwiftUI
import UIKit

/// An adaptive banner as wide as the screen.
struct BannerAdView: UIViewRepresentable {
    let width: CGFloat

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width))
        banner.adUnitID = AdsConfig.banner
        banner.rootViewController = topViewController()
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}

/// The strip above the tab bar. It appears only when ads are allowed (consent given, not Premium, no ad-free hour running).
struct AdBanner: View {
    @ObservedObject private var ads = AdsManager.shared

    var body: some View {
        if ads.adsEnabled {
            let width = UIScreen.main.bounds.width
            let size = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
            BannerAdView(width: width)
                .frame(width: size.size.width, height: size.size.height)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
        }
    }
}
