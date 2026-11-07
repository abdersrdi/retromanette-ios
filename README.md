# Retro Manette for iOS

A native iPhone and iPad app for retromanette.com: a catalog of openly licensed retro games, your own library, and a real
emulator running on the device. Written in SwiftUI with a small C frontend around the mGBA core. It is not a website in a
wrapper: there is no web view anywhere.

- **Languages:** English, Arabic (right to left) and French
- **Play:** handheld-style games in the GB, GBC and GBA formats through mGBA (MPL-2.0). More systems come later with permissive cores.
- **Controls:** glass touch controls with haptics, wireless controllers, save states (9 slots), automatic resume
- **Catalog:** the same list as the website (`games.json`), with a copy inside the app for offline first launch
- **Library:** add your own `.gb`, `.gbc`, `.gba` files from Files. They stay on the device and are never uploaded.
- **Ads and Premium:** free with Google AdMob ads (banner above the tab bar, an interstitial after a game session, a rewarded video for an ad-free hour; never during play). Premium (one monthly plan) removes ads.
- **Privacy:** no account and no analytics of our own; consent (Google UMP) and Apple's tracking prompt come before any ad

## Build

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not committed.

```bash
brew install xcodegen cmake
bash scripts/build_cores.sh      # builds mGBA as a static library for device and simulator
xcodegen generate
open RetroManette.xcodeproj
```

GitHub Actions (`.github/workflows/ios.yml`) does the same on a macOS runner and builds for the simulator and a device.

## Layout

| Path | What is there |
|---|---|
| `RetroManette/Emulation` | `retro_host.c` (libretro frontend in C: video, audio, input, saves) and `EmulatorSession.swift` (thread, sound, display) |
| `RetroManette/Screens` | SwiftUI screens: discover, game detail, library, player with touch controls, settings |
| `RetroManette/Design` | colors, fonts and components shared by the screens |
| `RetroManette/Models` | catalog, library, recents, file locations |
| `RetroManette/Resources` | strings in three languages, icon, bundled catalog |
| `scripts/build_cores.sh` | builds the emulator core at a pinned commit |
| `tools/make_icon.py` | draws the app icon from the website icon |

## Licenses

The app's own code is © 2026 PDFSwift, all rights reserved. It includes the mGBA emulator core (Mozilla Public License 2.0,
source at https://github.com/libretro/mgba, pinned in `scripts/build_cores.sh`; mGBA is used unmodified) and the libretro API
header (MIT). The catalog games are distributed by their authors under open licenses; each game's license is shown in the app.
See `THIRD_PARTY_NOTICES.md`.
