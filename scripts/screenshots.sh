#!/bin/bash
# Runs the simulator build and takes screenshots: home, library, settings and a game being played, in English, Arabic and
# French. Used by the GitHub workflow; the pictures end up in out/screenshots.
#   bash scripts/screenshots.sh <path to RetroManette.app>
set -u
APP="${1:?usage: screenshots.sh <RetroManette.app>}"
BUNDLE=com.retromanette.app
OUT="$(cd "$(dirname "$0")/.." && pwd)/out/screenshots"
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available | grep -E "iPhone 1[5-9] Pro Max|iPhone 1[5-9] Pro \(" | tail -1 | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
[ -n "$UDID" ] || UDID=$(xcrun simctl list devices available | grep -E "iPhone" | tail -1 | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

shoot() {   # $1 = language code, $2 = locale, $3 = file name, rest = launch arguments
    local lang="$1" locale="$2" name="$3"; shift 3
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" -AppleLanguages "($lang)" -AppleLocale "$locale" "$@"
    sleep "${WAIT:-12}"
    xcrun simctl io "$UDID" screenshot "$OUT/$lang-$name.png"
}

for pair in "en en_US" "ar ar_SA" "fr fr_FR"; do
    set -- $pair
    shoot "$1" "$2" discover -tab 0
    shoot "$1" "$2" library -tab 1
    shoot "$1" "$2" settings -tab 2
done

# a real game running (the ROM is downloaded from retromanette.com first)
WAIT=30 shoot en en_US play -autoplay tobutobugirl
sleep 5
xcrun simctl io "$UDID" screenshot "$OUT/en-play-later.png"
WAIT=30 shoot ar ar_SA play -autoplay tobutobugirl

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
ls -la "$OUT"
