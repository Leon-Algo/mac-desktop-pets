#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$PROJECT_DIR/build/DesktopPets.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

cd "$PROJECT_DIR"
swift build -c release --product DesktopPets ${SWIFT_BUILD_FLAGS:-}
BUILD_DIR="$(swift build -c release --show-bin-path ${SWIFT_BUILD_FLAGS:-})"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_DIR/DesktopPets" "$APP_MACOS/DesktopPets"
chmod +x "$APP_MACOS/DesktopPets"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp -R "$BUILD_DIR/DesktopPets_DesktopPets.bundle" "$APP_RESOURCES/DesktopPets_DesktopPets.bundle"

plutil -lint "$APP_CONTENTS/Info.plist"
codesign --force --deep --sign - --entitlements "$PROJECT_DIR/Resources/DesktopPets.entitlements" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# --- DMG 打包（路线 B：不签名免费分发）---
DMG_PATH="$PROJECT_DIR/build/DesktopPets.dmg"
STAGING="$PROJECT_DIR/build/dmg-stage"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/DesktopPets.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "DesktopPets" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
codesign --force --sign - "$DMG_PATH" 2>/dev/null || true

echo "$DMG_PATH"
