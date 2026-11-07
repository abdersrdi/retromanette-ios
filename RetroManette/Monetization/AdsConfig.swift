import Foundation

/// AdMob IDs of Retro Manette. Debug builds (simulator, Xcode runs) use Google's official sample ad units, so nobody ever taps a
/// live ad while developing. Release builds (TestFlight and the App Store) use the real units below. The AdMob app ID itself is in
/// Info.plist (GADApplicationIdentifier, set in project.yml). These IDs are public by design: every app that shows ads contains them.
///
/// App ID:        ca-app-pub-2683853184901962~9178048568
enum AdsConfig {
    #if DEBUG
    static let banner = "ca-app-pub-3940256099942544/2435281174"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    #else
    static let banner = "ca-app-pub-2683853184901962/7273939950"
    static let interstitial = "ca-app-pub-2683853184901962/2397017797"
    static let rewarded = "ca-app-pub-2683853184901962/5486215563"
    #endif

    // How the ads are paced. Change these to tune the balance between revenue and annoyance.
    static let firstInterstitialAfterSessions = 2         // the first game session is always ad-free
    static let interstitialCooldown: TimeInterval = 180   // never twice within three minutes
    static let adFreePassSeconds: TimeInterval = 3600     // a rewarded video buys one ad-free hour
}
