#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Roost.app"
ENTITLEMENTS="$ROOT_DIR/entitlements/AppStore.entitlements"

cd "$ROOT_DIR"
./script/build_and_run.sh --build-only

if [[ -n "${APP_SIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$APP_PATH"
else
  echo "APP_SIGN_IDENTITY is not set; leaving app unsigned."
fi

codesign -dvvv --entitlements :- "$APP_PATH" || true
plutil -p "$APP_PATH/Contents/Info.plist"

echo "Prepared $APP_PATH"
echo "Set APP_SIGN_IDENTITY to sign for distribution."
