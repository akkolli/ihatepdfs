#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="I Hate PDFs"
RELEASE_VERSION="${RELEASE_VERSION:-0.2}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos.dmg"

if [[ ! -d "$APP_DIR" ]]; then
  "$ROOT_DIR/scripts/build-app.sh"
fi

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
