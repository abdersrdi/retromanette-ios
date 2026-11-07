#!/bin/bash
# Builds the emulator core (mGBA, MPL-2.0) as a static library for the iOS device and the iOS simulator.
#   bash scripts/build_cores.sh            -> Vendor/cores/iphoneos/libmgba_libretro.a and Vendor/cores/iphonesimulator/libmgba_libretro.a
# Needs: Xcode command line tools, cmake. The core's source is fetched at a pinned commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build-cores"
OUT="$ROOT/Vendor/cores"
MGBA_REPO="https://github.com/libretro/mgba"
MGBA_REF="7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6"
MIN_IOS="16.0"

mkdir -p "$WORK" "$OUT"
if [ ! -d "$WORK/mgba/.git" ]; then
    git init -q "$WORK/mgba"
    git -C "$WORK/mgba" remote add origin "$MGBA_REPO"
fi
git -C "$WORK/mgba" fetch -q --depth 1 origin "$MGBA_REF"
git -C "$WORK/mgba" checkout -q FETCH_HEAD
echo "mGBA at $(git -C "$WORK/mgba" rev-parse --short HEAD)"

for SDK in ${SDKS:-iphoneos iphonesimulator}; do
    BUILD="$WORK/build-$SDK"
    rm -rf "$BUILD"
    cmake -S "$WORK/mgba" -B "$BUILD" -G "Unix Makefiles" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT="$SDK" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_LIBRETRO=ON -DLIBRETRO_STATIC=ON -DSKIP_LIBRARY=ON \
        -DBUILD_QT=OFF -DBUILD_SDL=OFF -DBUILD_GL=OFF -DBUILD_GLES2=OFF -DBUILD_GLES3=OFF \
        -DBUILD_EXAMPLE=OFF -DBUILD_TEST=OFF -DBUILD_SUITE=OFF -DBUILD_HEADLESS=OFF -DBUILD_PERF=OFF \
        -DUSE_FFMPEG=OFF -DUSE_PNG=OFF -DUSE_LIBZIP=OFF -DUSE_MINIZIP=OFF -DUSE_SQLITE3=OFF -DUSE_ELF=OFF \
        -DUSE_LZMA=OFF -DUSE_EDITLINE=OFF -DUSE_DISCORD_RPC=OFF -DENABLE_SCRIPTING=OFF -DUSE_ZLIB=ON
    cmake --build "$BUILD" --target mgba_libretro --parallel "$(sysctl -n hw.ncpu)"
    LIB="$(find "$BUILD" -name '*mgba_libretro*.a' | head -1)"
    [ -n "$LIB" ] || { echo "mgba_libretro static library not found in $BUILD"; find "$BUILD" -name '*.a'; exit 1; }
    mkdir -p "$OUT/$SDK"
    cp "$LIB" "$OUT/$SDK/libmgba_libretro.a"
    echo "built $OUT/$SDK/libmgba_libretro.a ($(du -h "$OUT/$SDK/libmgba_libretro.a" | cut -f1))"
done
