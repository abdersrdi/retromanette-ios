#!/bin/bash
# App Store pictures: screenshots in English, Arabic and French on an iPhone and an iPad simulator, and a screen recording
# of a scripted tour in each language. Debug launch arguments (see RetroManette/App/DebugLaunch.swift) drive the app.
#   bash scripts/store_assets.sh <path to RetroManette.app>      -> out/store/{iphone,ipad}/<lang>/NN-name.png and out/store/video/*.mov
set -u
APP="${1:?usage: store_assets.sh <RetroManette.app>}"
BUNDLE=com.retromanette.app
OUT="$(cd "$(dirname "$0")/.." && pwd)/out/store"
LANGS="${LANGS:-en ar fr}"
mkdir -p "$OUT/video"

udid() { xcrun simctl list devices available | grep -E "$1" | tail -1 | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}'; }

locale_of() { case "$1" in ar) echo ar_SA;; fr) echo fr_FR;; *) echo en_US;; esac; }

run_device() {   # $1 = folder name, $2 = simulator name pattern, $3 = fallback pattern
    local dev="$1" UDID
    UDID=$(udid "$2"); [ -n "$UDID" ] || UDID=$(udid "$3")
    echo "== $dev: $UDID"
    [ -n "$UDID" ] || { echo "no simulator for $dev"; return; }
    xcrun simctl boot "$UDID" || true
    xcrun simctl bootstatus "$UDID" -b
    xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 || true
    xcrun simctl install "$UDID" "$APP"

    launch() {   # $1 = language, rest = app arguments
        local lang="$1"; shift
        xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
        xcrun simctl launch "$UDID" "$BUNDLE" -AppleLanguages "($lang)" -AppleLocale "$(locale_of "$lang")" -store "$@"
    }
    shoot() {    # $1 = language, $2 = file name, $3 = seconds to wait, rest = app arguments
        local lang="$1" name="$2" wait="$3"; shift 3
        mkdir -p "$OUT/$dev/$lang"
        launch "$lang" "$@"
        sleep "$wait"
        xcrun simctl io "$UDID" screenshot "$OUT/$dev/$lang/$name.png"
    }

    # first start: the simulator shows a one-time banner, and the games are downloaded and added to the library
    launch en -seedLibrary -tab 1
    sleep 45
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

    for lang in $LANGS; do
        shoot "$lang" 01-discover 9 -tab 0
        shoot "$lang" 02-game 9 -openGame tobutobugirl
        shoot "$lang" 03-play 15 -autoplay tobutobugirl -demo
        shoot "$lang" 04-play-gba 15 -autoplay zoomer-gba -demo
        shoot "$lang" 05-library 8 -tab 1
        shoot "$lang" 06-premium 9 -showPremium -tab 2
        shoot "$lang" 07-settings 8 -tab 2
    done

    # warm-up launch: covers into the cache so the recordings show finished screens
    launch en -warm
    sleep 45
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    # play the game to a mid-level moment and leave it: the app saves a resume point for the tour
    launch en -makeResume -demo
    sleep 50
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

    # screen recordings: a scripted tour in each language (about 24 seconds, recorded for 46 so the start can be trimmed)
    for lang in $LANGS; do
        xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/video/$dev-$lang.mov" &
        REC=$!
        sleep 2
        launch "$lang" -tour
        sleep 46
        kill -INT "$REC" || true
        wait "$REC" || true
        xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    done
    xcrun simctl shutdown "$UDID" || true
}

run_device iphone "iPhone 1[6-9] Pro Max" "iPhone .* Pro Max"
run_device ipad "iPad Pro 13-inch" "iPad Pro"
find "$OUT" -type f | sort
