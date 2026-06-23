#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Roost.app"
PKG_PATH="$ROOT_DIR/dist/Roost-AppStore.pkg"
ENTITLEMENTS="$ROOT_DIR/entitlements/AppStore.entitlements"

cd "$ROOT_DIR"
ROOST_BUILD_CONFIGURATION=release ./script/build_and_run.sh --build-only
find "$APP_PATH" -depth -exec xattr -c {} \;
xattr -c "$APP_PATH"

if [[ -n "${APP_STORE_PROVISIONING_PROFILE:-}" ]]; then
  cp "$APP_STORE_PROVISIONING_PROFILE" "$APP_PATH/Contents/embedded.provisionprofile"
else
  echo "APP_STORE_PROVISIONING_PROFILE is not set; no provisioning profile embedded."
fi

if [[ -n "${APP_SIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$APP_PATH"
else
  echo "APP_SIGN_IDENTITY is not set; ad-hoc signing app for local validation only."
  codesign \
    --force \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign - \
    "$APP_PATH"
fi

codesign -dvvv --entitlements :- "$APP_PATH" || true
codesign --verify --strict --verbose=2 "$APP_PATH"
plutil -p "$APP_PATH/Contents/Info.plist"

echo "Prepared $APP_PATH"
echo "Set APP_SIGN_IDENTITY and APP_STORE_PROVISIONING_PROFILE to sign for App Store distribution."

if [[ -n "${APP_INSTALLER_IDENTITY:-}" ]]; then
  productbuild \
    --component "$APP_PATH" /Applications \
    --sign "$APP_INSTALLER_IDENTITY" \
    "$PKG_PATH"
  productbuild --check-signature "$PKG_PATH"
  echo "Prepared $PKG_PATH"
else
  echo "APP_INSTALLER_IDENTITY is not set; skipping signed App Store .pkg creation."
fi
