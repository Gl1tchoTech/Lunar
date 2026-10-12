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
# Refinements adopted from cranci1/Luna's working ipabuild.sh
# (https://github.com/cranci1/Luna/tree/main):
#   - `clean build` in a single xcodebuild invocation so the
#     DerivedData is fully wiped between runs (no stale object
#     leakage into the Release .app).
#   - Defensive `codesign --remove` + `_CodeSignature` /
#     `embedded.mobileprovision` cleanup. Harmless when
#     CODE_SIGNING_ALLOWED=NO (nothing signed) but guards against
#     any future path that might leave a partial signature or a
#     stale provisioning profile attached to the .app — both would
#     crash SideStore on import.
#   - `strip` on the embedded `Lunar` binary. Safe no-op if the
#     binary is already stripped (Debug), and shrinks the Release
#     IPA by ~5-10 MB by removing debug / symbol-table sections
#     the runner never needs at runtime.
#   - Cleans up the staging `$TARGET_APP` copy we use for the
#     codesign/strip pass, leaving only `build/Payload` and
#     `build/Lunar.ipa` behind.
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

# Force the generated project into an Xcode 15.4-compatible format.
# XcodeGen's `options.xcodeVersion` does NOT reliably control the
# pbxproj `objectVersion` in XcodeGen >= 2.42; it only sets
# `LastUpgradeCheck`. The reliable fix is to rewrite the format header
# lines immediately after generation, before `xcodebuild` touches the
# project. This is the same workaround documented in
# yonaskolb/XcodeGen#1578 and CocoaPods/CocoaPods#12583.
PBX="$REPO_ROOT/Lunar.xcodeproj/project.pbxproj"
if [ -f "$PBX" ]; then
  perl -pi -e 's/objectVersion\s*=\s*\d+;/objectVersion = 56;/' "$PBX"
  if grep -q 'compatibilityVersion' "$PBX"; then
    perl -pi -e 's/compatibilityVersion\s*=\s*"[^"]+";/compatibilityVersion = "Xcode 14.0";/' "$PBX"
  else
    perl -pi -e 's/(objectVersion = 56;)/$1\n\tcompatibilityVersion = "Xcode 14.0";/' "$PBX"
  fi
  echo "==> Patched pbxproj objectVersion/compatibilityVersion"
else
  echo "::error::$PBX not found after xcodegen generate; cannot patch project format."
  exit 1
fi

echo "==> Building $SCHEME for iOS (clean + Release)..."
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=iOS" \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA" \
  clean build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS=""

APP_PATH="$DERIVED_DATA/Build/Products/${CONFIG}-iphoneos/${APP_NAME}.app"
TARGET_APP="$BUILD_DIR/${APP_NAME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: built app not found at $APP_PATH"
  exit 1
fi

echo "==> Defensive code-signature cleanup on the staged .app..."
# These are no-ops when CODE_SIGNING_ALLOWED=NO (which it is in CI),
# but they keep the IPA safe to import into SideStore even if some
# future path leaves a partial signature or a stale provisioning
# profile attached. Order matters: `--remove` first, then the
# filesystem cleanup.
mkdir -p "$BUILD_DIR"
rm -rf "$TARGET_APP"
cp -R "$APP_PATH" "$TARGET_APP"
codesign --remove "$TARGET_APP" 2>/dev/null || true
[[ -e "$TARGET_APP/_CodeSignature" ]] && rm -rf "$TARGET_APP/_CodeSignature"
[[ -e "$TARGET_APP/embedded.mobileprovision" ]] && rm -rf "$TARGET_APP/embedded.mobileprovision"

echo "==> Packaging $APP_NAME as unsigned IPA..."
rm -rf "$BUILD_DIR/Payload" "$BUILD_DIR/$IPA_NAME"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$TARGET_APP" "$BUILD_DIR/Payload/${APP_NAME}.app"

if [[ -f "$BUILD_DIR/Payload/${APP_NAME}.app/$APP_NAME" ]]; then
  echo "==> Stripping debug + symbol table from $APP_NAME binary..."
  strip "$BUILD_DIR/Payload/${APP_NAME}.app/$APP_NAME" 2>/dev/null || true
fi

(
  cd "$BUILD_DIR"
  zip -qr "$IPA_NAME" "Payload"
)

# Clean up the intermediate staged copy so only Payload + the IPA
# survive in build/ (matches cranci1/Luna's ipabuild.sh behaviour and
# keeps the upload-artifact delta minimal).
rm -rf "$TARGET_APP"

echo
echo "✅ Built: $BUILD_DIR/$IPA_NAME"
ls -lh "$BUILD_DIR/$IPA_NAME"
echo
echo "Drop this IPA into SideStore to install Lunar on your iPhone."
echo "See docs/SIDESTORE.md for the full workflow."
