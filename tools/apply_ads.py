"""One-off: wires AdMob into project.yml, the strings and the screens. Safe to read; not needed after it has run."""
import io
import re

def rw(path, pairs):
    s = io.open(path, encoding="utf-8", newline="").read()
    for a, b in pairs:
        assert a in s, (path, a[:70])
        s = s.replace(a, b, 1)
    io.open(path, "w", encoding="utf-8", newline="").write(s)

ids = [l.strip() for l in open("tools/skadnetwork_ids.txt") if l.strip()]
sk = "        SKAdNetworkItems:\n" + "".join("          - SKAdNetworkIdentifier: %s\n" % i for i in ids)

rw("project.yml", [
    ("targets:\n  RetroManette:\n",
     "packages:\n  GoogleMobileAds:\n    url: https://github.com/googleads/swift-package-manager-google-mobile-ads.git\n    from: 11.0.0\n"
     "  GoogleUserMessagingPlatform:\n    url: https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git\n    from: 2.0.0\n\n"
     "targets:\n  RetroManette:\n"),
    ("    settings:\n      base:\n        PRODUCT_BUNDLE_IDENTIFIER: com.retromanette.app\n",
     "    dependencies:\n      - package: GoogleMobileAds\n        product: GoogleMobileAds\n"
     "      - package: GoogleUserMessagingPlatform\n        product: GoogleUserMessagingPlatform\n"
     "    settings:\n      base:\n        PRODUCT_BUNDLE_IDENTIFIER: com.retromanette.app\n"),
    ('OTHER_LDFLAGS: ["-lmgba_libretro", "-lz"]', 'OTHER_LDFLAGS: ["-ObjC", "-lmgba_libretro", "-lz"]'),
    ("        UIViewControllerBasedStatusBarAppearance: true\n",
     "        UIViewControllerBasedStatusBarAppearance: true\n"
     "        # AdMob app ID of Retro Manette. Debug builds request Google's sample ad units, see AdsConfig.swift.\n"
     "        GADApplicationIdentifier: ca-app-pub-2683853184901962~9178048568\n"
     "        NSUserTrackingUsageDescription: Allowing tracking lets Retro Manette show ads that are more relevant to you, which helps keep the app free. Your games and saves never leave your device.\n"
     + sk),
])

tracking = {
    "en": "Allowing tracking lets Retro Manette show ads that are more relevant to you, which helps keep the app free. Your games and saves never leave your device.",
    "ar": "السماح بالتتبع يتيح لـ Retro Manette عرض إعلانات أنسب لك، مما يساعد على إبقاء التطبيق مجانياً. ألعابك وملفات الحفظ لا تغادر جهازك.",
    "fr": "Autoriser le suivi permet à Retro Manette d'afficher des publicités plus pertinentes, ce qui aide à garder l'app gratuite. Vos jeux et sauvegardes ne quittent jamais votre appareil.",
}
for lang, text in tracking.items():
    p = "RetroManette/Resources/%s.lproj/InfoPlist.strings" % lang
    s = io.open(p, encoding="utf-8").read().rstrip("\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s + '\n"NSUserTrackingUsageDescription" = "%s";\n' % text)

add = {
    "en": '"settings.ads" = "Ads";\n"settings.ads.remove" = "Remove ads for 1 hour";\n"settings.ads.watch" = "Watch a short video";\n"settings.ads.until" = "Ad-free until %@";\n"settings.ads.privacy" = "Ad privacy options";\n"settings.ads.note" = "Retro Manette is free with ads. Premium removes them for good.";\n',
    "ar": '"settings.ads" = "الإعلانات";\n"settings.ads.remove" = "إزالة الإعلانات لمدة ساعة";\n"settings.ads.watch" = "شاهد فيديو قصيراً";\n"settings.ads.until" = "بلا إعلانات حتى %@";\n"settings.ads.privacy" = "خيارات خصوصية الإعلانات";\n"settings.ads.note" = "Retro Manette مجاني بالإعلانات. يزيلها Premium نهائياً.";\n',
    "fr": '"settings.ads" = "Publicités";\n"settings.ads.remove" = "Retirer les pubs pendant 1 heure";\n"settings.ads.watch" = "Regarder une courte vidéo";\n"settings.ads.until" = "Sans pub jusqu\'à %@";\n"settings.ads.privacy" = "Options de confidentialité des pubs";\n"settings.ads.note" = "Retro Manette est gratuit avec publicités. Premium les supprime définitivement.";\n',
}
for lang, text in add.items():
    p = "RetroManette/Resources/%s.lproj/Localizable.strings" % lang
    s = io.open(p, encoding="utf-8").read().rstrip("\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s + "\n\n" + text)

# the app starts the ads once, after the first screen
rw("RetroManette/App/RetroManetteApp.swift", [
    ("                .task { await premium.start() }\n",
     "                .task { await premium.start() }\n                .task { await AdsManager.shared.start() }\n"),
])
# Premium subscribers see no ads
rw("RetroManette/Models/PremiumStore.swift", [
    ("        isPremium = active\n", "        isPremium = active\n        AdsManager.shared.setPremium(active)\n"),
])
# banner above the tab bar on the three main screens (never while playing)
rw("RetroManette/Screens/RootView.swift", [
    ("            DiscoverView()\n                .tabItem", "            DiscoverView()\n                .safeAreaInset(edge: .bottom, spacing: 0) { AdBanner() }\n                .tabItem"),
    ("            LibraryView()\n                .tabItem", "            LibraryView()\n                .safeAreaInset(edge: .bottom, spacing: 0) { AdBanner() }\n                .tabItem"),
    ("            SettingsView()\n                .tabItem", "            SettingsView()\n                .safeAreaInset(edge: .bottom, spacing: 0) { AdBanner() }\n                .tabItem"),
])
# interstitial after a game session
rw("RetroManette/Screens/PlayerView.swift", [
    ("            session.stop()\n            UIApplication.shared.isIdleTimerDisabled = false\n",
     "            session.stop()\n            UIApplication.shared.isIdleTimerDisabled = false\n            AdsManager.shared.sessionEnded()\n"),
])
# settings: the ads section (rewarded video, privacy options)
rw("RetroManette/Screens/SettingsView.swift", [
    ("    @EnvironmentObject private var premium: PremiumStore\n",
     "    @EnvironmentObject private var premium: PremiumStore\n    @ObservedObject private var ads = AdsManager.shared\n"),
    ("                Section {\n                    HStack {\n                        Label(\"settings.language\"",
     "                if !premium.isPremium { adsSection }\n                Section {\n                    HStack {\n                        Label(\"settings.language\""),
    ("    private var premiumChip: String {",
     """    /// Ads: one rewarded video buys an ad-free hour; the privacy options appear where the law asks for them.
    private var adsSection: some View {
        Section {
            if ads.adFreeActive {
                Label(String(format: String(localized: "settings.ads.until"), ads.adFreeUntil.formatted(date: .omitted, time: .shortened)), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
            } else if ads.canRequestAds && ads.rewardedReady {
                Button { ads.showRewarded { _ in } } label: {
                    Label { VStack(alignment: .leading) { Text("settings.ads.remove"); Text("settings.ads.watch").font(.system(size: 12)).foregroundStyle(Theme.muted) } } icon: { Image(systemName: "play.rectangle.fill") }
                }
            }
            if ads.privacyOptionsRequired {
                Button { ads.presentPrivacyOptions() } label: { Label("settings.ads.privacy", systemImage: "hand.raised") }
            }
        } header: {
            Text("settings.ads")
        } footer: {
            Text("settings.ads.note")
        }
        .listRowBackground(Theme.surfaceHigh)
    }

    private var premiumChip: String {"""),
])
print("ads wired")
