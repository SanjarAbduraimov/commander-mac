#!/bin/bash
# Builds a Universal (Apple silicon + Intel) Release of Commander and packs it into build/Commander.dmg.
# The app is ad-hoc signed (no Developer ID), so on another Mac the first launch needs right-click → Open.
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD=build
DERIVED="$BUILD/DerivedData"
STAGING="$BUILD/dmg-root"
DMG="$BUILD/Commander.dmg"

xcodegen generate >/dev/null
xcodebuild -project Commander.xcodeproj -scheme Commander -configuration Release \
    -derivedDataPath "$DERIVED" -destination 'generic/platform=macOS' \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build | grep -E "error:|BUILD" || true

APP="$DERIVED/Build/Products/Release/Commander.app"
test -d "$APP" || { echo "Build failed: $APP not found" >&2; exit 1; }
codesign --verify --deep --strict "$APP"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname Commander -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"

echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Commander")"
echo "Created $DMG ($(du -h "$DMG" | cut -f1))"
