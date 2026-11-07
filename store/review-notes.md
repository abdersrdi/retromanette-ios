# App Review information: Retro Manette

**Sign-in required:** Tick **"Sign-in required"** and fill the user name and password fields with the review account. The account is optional for users (the app works fully without it), but giving Apple a way to sign in avoids questions.

- **User name:** `appreview@retromanette.com`
- **Password:** the code printed by `deploy/set-review-account.sh` on the server. Keep it only in App Store Connect and rotate it (run the script again) after approval.

Never write the code in this repository (it is public).

**Contact:** your name, phone and email.

**Notes** (paste):

```
Retro Manette works fully without an account. Signing in is optional and only links the app to the user's account on our website, retromanette.com.

How to test:
1. Open the app. The Discover tab lists open-source and homebrew retro games in the GB, GBC and GBA formats. Every game is distributed by its authors with their permission or under an open license; the license and a link to the source are shown on each game's page. No game files are inside the app: a game is downloaded from retromanette.com when it is first played (as allowed for retro game emulator apps, guideline 4.7).
2. Tap a game, then Play. The game runs on the device with an on-screen controller (wireless controllers also work). The ... menu has save states, fast forward and reset. Free users have 3 save slots.
3. Library tab: the user can add their own game files from the Files app (.gb, .gbc, .gba). They stay on the device and are never uploaded; the app says to add only games the user owns or has the right to use.
4. Settings > Account: optional sign-in with an email and a 6-digit code sent to that email. For App Review we created an account whose code is fixed: sign in with the email and password given in the App Review Information fields (type the email, tap Send code, then type the password in the Code field). The account screen also has Sign out and Delete account.
5. Settings > Premium: one auto-renewing monthly subscription ($9.99) that removes all ads and unlocks save slots 4 to 9. It can be tested with a sandbox account, and "Restore purchases" is on the same page. The same subscription also unlocks extra features on our website, retromanette.com, when the user signs in there with the same email; those website features are not part of this review.

Ads: Google AdMob. On first launch Google's consent form (where required) and Apple's tracking prompt appear before any ad. A banner shows above the tab bar, an interstitial may show after a game session ends, and Settings has an optional rewarded video for one ad-free hour. No ads are shown while a game is being played. Premium removes all ads.

Emulator: mGBA (Mozilla Public License 2.0), unmodified; its source is linked in Settings > Licenses.
Privacy Policy: https://retromanette.com/legal/privacy
Terms of Use: https://retromanette.com/legal/terms
```

## If Apple asks (prepared replies)

**"Is this an emulator? How do you make sure users do not pirate games?"**
> Yes, Retro Manette is a retro game emulator app, as allowed by guideline 4.7. The catalog contains only games that their authors share for free with their permission or under open licenses; each game's license and source link are shown in the app. The app contains and downloads no commercial game, and it has no way to browse or download games from anywhere else. Users can open their own files from the Files app; the app tells them to add only games they own or have the right to use, and the files stay on the device. We respond to rights holders through https://retromanette.com/legal/contact and remove games on request.

**"Your listing or app mentions third-party trademarks."**
> The app name, subtitle, keywords, description and screenshots contain no console or company names. The formats are written GB, GBC and GBA. A few catalog games show their own title screens, which are made by their authors.

**"What does Premium give inside the app? / Why $9.99?"**
> Premium removes all ads (banner, interstitial and rewarded) and increases save slots from 3 to 9 per game. It also unlocks extra features on our website for the same account. It is one monthly auto-renewing subscription; there is no other plan. The page shows the price, the renewal terms, Restore purchases, and links to the Terms of Use and Privacy Policy.

**"Why is there an account?"**
> The account is optional and only links the app to the user's account on retromanette.com. Users can sign out and delete their account inside the app (Settings > Account).

**"Ads and children."**
> The app is not directed to children. Ads use Google AdMob with Google's consent form (where required) and Apple's App Tracking Transparency prompt before any ad loads.
