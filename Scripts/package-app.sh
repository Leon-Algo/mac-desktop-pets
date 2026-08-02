#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$PROJECT_DIR/build/DesktopPets.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

cd "$PROJECT_DIR"
swift build -c release --product DesktopPets
BUILD_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_DIR/DesktopPets" "$APP_MACOS/DesktopPets"
chmod +x "$APP_MACOS/DesktopPets"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp -R "$BUILD_DIR/DesktopPets_DesktopPets.bundle" "$APP_RESOURCES/DesktopPets_DesktopPets.bundle"

plutil -lint "$APP_CONTENTS/Info.plist"
codesign --force --deep --sign - --entitlements "$PROJECT_DIR/Resources/DesktopPets.entitlements" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "$APP_BUNDLE"
