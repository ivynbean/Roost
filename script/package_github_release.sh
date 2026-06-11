#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Roost"
APP_PATH="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.app.zip"
CHECKSUM_PATH="$DIST_DIR/$APP_NAME.app.zip.sha256"
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
  echo "APP_SIGN_IDENTITY is not set; packaging an unsigned app for tester downloads."
fi

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
/usr/bin/shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"

echo "Prepared:"
echo "  $APP_PATH"
echo "  $ZIP_PATH"
echo "  $CHECKSUM_PATH"
