# App Review information: Retro Manette

**Sign-in required:** Tick **"Sign-in required"** and fill the user name and password fields with the review account. The account is optional for users (the app works fully without it), but giving Apple a way to sign in avoids questions.

- **User name:** the email printed by `deploy/set-review-account.sh` on the server (default `appreview@retromanette.com`).
- **Password:** the code printed by the same script. It is shown once, on your screen only.

Never write the code in this repository (it is public), in chat, or anywhere except App Store Connect. To make a new code, run the script again; the old one stops working.

**Contact:** your name, phone and email.

**Notes** (paste):

```
Retro Manette works fully without an account. Signing in is optional and only links the app to the user's account on our website, retromanette.com.

How to test:
1. Open the app. The Discover tab lists open-source and homebrew Game Boy and Game Boy Advance games. Every game is distributed by its authors with their permission or under an open license; the license and a link to the source are shown on each game's page. No game files are inside the app: a game is downloaded from retromanette.com when it is first played.
2. Tap a game, then Play. The game runs on the device with an on-screen controller (wireless controllers also work). The ... menu has save states, fast forward and reset.
3. Library tab: the user can add their own game files from the Files app (.gb, .gbc, .gba). They stay on the device and are never uploaded.
4. Settings > Account: optional sign-in with an email and a 6-digit code sent to that email. For App Review we created an account whose code is fixed: sign in with the email and password given in the App Review Information fields (type the email, tap Send code, then type the password in the Code field). The account screen also has Sign out and Delete account.
5. Settings > Premium: one auto-renewing monthly subscription ($9.99) that removes all ads in the app. It can be tested with a sandbox account, and "Restore purchases" is on the same page. The same subscription also unlocks extra features on our website, retromanette.com, when the user signs in there with the same email; those website features are not part of this review.

Ads: Google AdMob. On first launch Google's consent form (where required) and Apple's tracking prompt appear before any ad. A banner shows above the tab bar, an interstitial may show after a game session ends, and Settings has an optional rewarded video for one ad-free hour. No ads are shown while a game is being played. Premium removes all ads.

Emulator: mGBA (Mozilla Public License 2.0), unmodified; its source is linked in Settings > Licenses.
Privacy Policy: https://retromanette.com/legal/privacy
Terms of Use: https://retromanette.com/legal/terms
```
