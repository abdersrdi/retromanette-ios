import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

/// The topmost view controller, which ads and consent forms are presented from.
@MainActor
func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene?.windows.first?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
}

/// Owns everything about advertising: consent, the SDK, and the three formats (banner, interstitial, rewarded).
///
/// Order at launch: Google's consent form (GDPR / UK, only where required), Apple's tracking prompt, then the SDK starts and
/// ads load. Nothing loads if consent is refused. Ads are never shown while a game is being played, and stay off for Premium
/// subscribers and during an ad-free hour (earned by watching a rewarded video).
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    @Published private(set) var canRequestAds = false
    @Published private(set) var adFreeUntil: Date
    @Published private(set) var rewardedReady = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var isPremium = false

    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var started = false
    private var sessions = 0
    private var lastInterstitial = Date.distantPast
    private static let adFreeKey = "adFreeUntil"

    private override init() {
        adFreeUntil = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: AdsManager.adFreeKey))
        super.init()
    }

    /// Screenshot and recording builds never show ads (and never ask for consent).
    private var disabledForCapture: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-store") || ProcessInfo.processInfo.arguments.contains("-noAds")
        #else
        return false
        #endif
    }

    /// True while banners and interstitials may be shown.
    var adsEnabled: Bool { canRequestAds && !isPremium && Date() >= adFreeUntil }
    var adFreeActive: Bool { Date() < adFreeUntil }

    @MainActor
    func setPremium(_ active: Bool) { isPremium = active }

    // MARK: start-up

    @MainActor
    func start() async {
        guard !started, !disabledForCapture else { return }
        started = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)   // let the first screen settle before any prompt appears
        await gatherConsent()
        privacyOptionsRequired = UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
        _ = await ATTrackingManager.requestTrackingAuthorization()
        guard UMPConsentInformation.sharedInstance.canRequestAds else { return }
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        canRequestAds = true
        loadInterstitial()
        loadRewarded()
    }

    @MainActor
    private func gatherConsent() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let params = UMPRequestParameters()
            params.tagForUnderAgeOfConsent = false
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: params) { error in
                if error != nil {
                    cont.resume()
                    return
                }
                UMPConsentForm.loadAndPresentIfRequired(from: topViewController()) { _ in cont.resume() }
            }
        }
    }

    /// Lets the user change their consent choice again (a requirement where the consent form is shown).
    @MainActor
    func presentPrivacyOptions() {
        UMPConsentForm.presentPrivacyOptionsForm(from: topViewController()) { _ in }
    }

    // MARK: loading

    private func loadInterstitial() {
        GADInterstitialAd.load(withAdUnitID: AdsConfig.interstitial, request: GADRequest()) { [weak self] ad, _ in
            self?.interstitial = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    private func loadRewarded() {
        GADRewardedAd.load(withAdUnitID: AdsConfig.rewarded, request: GADRequest()) { [weak self] ad, _ in
            self?.rewarded = ad
            ad?.fullScreenContentDelegate = self
            self?.rewardedReady = ad != nil
        }
    }

    // MARK: showing

    /// Called when a game session ends (after the player screen has closed). Shows an interstitial from the second session on,
    /// at most once per cooldown.
    @MainActor
    func sessionEnded() {
        sessions += 1
        guard adsEnabled, sessions >= AdsConfig.firstInterstitialAfterSessions,
              Date().timeIntervalSince(lastInterstitial) > AdsConfig.interstitialCooldown else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)    // wait for the player screen to finish closing
            guard let ad = self.interstitial, let vc = topViewController() else { return }
            self.lastInterstitial = Date()
            ad.present(fromRootViewController: vc)
        }
    }

    /// Plays a rewarded video; on completion the user gets an ad-free hour. Returns false if no video is ready.
    @MainActor
    func showRewarded(completion: @escaping (Bool) -> Void) {
        guard let ad = rewarded, let vc = topViewController() else {
            completion(false)
            return
        }
        ad.present(fromRootViewController: vc) { [weak self] in
            self?.grantAdFreePass()
            completion(true)
        }
    }

    private func grantAdFreePass() {
        let until = max(adFreeUntil, Date()).addingTimeInterval(AdsConfig.adFreePassSeconds)
        adFreeUntil = until
        UserDefaults.standard.set(until.timeIntervalSince1970, forKey: AdsManager.adFreeKey)
        // ads come back by themselves when the hour is over
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(AdsConfig.adFreePassSeconds * 1_000_000_000) + 1_000_000_000)
            self?.objectWillChange.send()
        }
    }
}

extension AdsManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            interstitial = nil
            loadInterstitial()
        } else if ad is GADRewardedAd {
            rewarded = nil
            rewardedReady = false
            loadRewarded()
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad is GADInterstitialAd { interstitial = nil; loadInterstitial() }
        if ad is GADRewardedAd { rewarded = nil; rewardedReady = false; loadRewarded() }
    }
}
