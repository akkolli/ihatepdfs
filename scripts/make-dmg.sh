#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-version.sh"
APP_NAME="I Hate PDFs"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos.dmg"
BUILD_APP="${BUILD_APP:-1}"

if [[ "$BUILD_APP" != "0" || ! -d "$APP_DIR" ]]; then
  APP_VERSION="$APP_VERSION" BUILD_NUMBER="$BUILD_NUMBER" "$ROOT_DIR/scripts/build-app.sh"
fi

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
