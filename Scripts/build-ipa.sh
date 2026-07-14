#!/usr/bin/env bash
#
# Builds the Lunar iOS app and packages an unsigned IPA suitable for
# SideStore / AltStore sideloading.
#
# Usage:
#   bash Scripts/build-ipa.sh [Debug|Release]
#
# Default: Release
#
# Requirements:
#   - macOS 14+
#   - Xcode 15.4+
#   - xcodegen (brew install xcodegen)
#
set -euo pipefail

CONFIG="${1:-Release}"
SCHEME="Lunar"
APP_NAME="Lunar"
BUILD_DIR="build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
IPA_NAME="Lunar.ipa"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

echo "==> Working in $REPO_ROOT"
echo "==> Configuration: $CONFIG"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "==> Installing xcodegen via Homebrew..."
  brew install xcodegen
fi

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building $SCHEME for iOS..."
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/${CONFIG}-iphoneos/${APP_NAME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: built app not found at $APP_PATH"
  exit 1
fi

echo "==> Packaging $APP_NAME as unsigned IPA..."
rm -rf "$BUILD_DIR/Payload" "$BUILD_DIR/$IPA_NAME"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/"

(
  cd "$BUILD_DIR"
  zip -qr "$IPA_NAME" "Payload"
)

echo
echo "✅ Built: $BUILD_DIR/$IPA_NAME"
ls -lh "$BUILD_DIR/$IPA_NAME"
echo
echo "Drop this IPA into SideStore to install Lunar on your iPhone."
echo "See docs/SIDESTORE.md for the full workflow."
