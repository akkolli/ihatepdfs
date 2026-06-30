#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-version.sh"

APP_NAME="I Hate PDFs"
BUNDLE_ID="${BUNDLE_ID:-net.akkolli.ihatepdfs}"
APP_SIGNING_IDENTITY="${APP_SIGNING_IDENTITY:-}"
INSTALLER_SIGNING_IDENTITY="${INSTALLER_SIGNING_IDENTITY:-}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-$ROOT_DIR/Signing/IHatePDFs-AppStore.entitlements}"
DIST_DIR="$ROOT_DIR/dist"
PKG_PATH="${PKG_PATH:-$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos-appstore.pkg}"
VALIDATE_WITH_ALTOOL="${VALIDATE_WITH_ALTOOL:-0}"
STAGING_DIR=""

cleanup() {
  if [[ -n "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT

require_value() {
  local name="$1"
  local value="$2"
  local hint="$3"

  if [[ -z "$value" ]]; then
    echo "Missing $name." >&2
    echo "$hint" >&2
    exit 2
  fi
}

require_value "APP_SIGNING_IDENTITY" "$APP_SIGNING_IDENTITY" \
  "Example: APP_SIGNING_IDENTITY=\"Apple Distribution: Your Name (TEAMID)\" or \"3rd Party Mac Developer Application: Your Name (TEAMID)\""
require_value "INSTALLER_SIGNING_IDENTITY" "$INSTALLER_SIGNING_IDENTITY" \
  "Example: INSTALLER_SIGNING_IDENTITY=\"3rd Party Mac Developer Installer: Your Name (TEAMID)\""
require_value "PROVISIONING_PROFILE" "$PROVISIONING_PROFILE" \
  "Download an App Store provisioning profile for $BUNDLE_ID and pass its local path."

mkdir -p "$DIST_DIR"
rm -f "$PKG_PATH"
STAGING_DIR="$(mktemp -d "$DIST_DIR/appstore-pkg.XXXXXX")"
APP_DIR="$STAGING_DIR/$APP_NAME.app"

BUNDLE_ID="$BUNDLE_ID" \
APP_VERSION="$APP_VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
APP_DIR="$APP_DIR" \
SIGNING_IDENTITY="$APP_SIGNING_IDENTITY" \
ENTITLEMENTS_PATH="$ENTITLEMENTS_PATH" \
PROVISIONING_PROFILE="$PROVISIONING_PROFILE" \
"$ROOT_DIR/scripts/build-app.sh"

xattr -cr "$APP_DIR" 2>/dev/null || true
productbuild \
  --component "$APP_DIR" /Applications \
  --sign "$INSTALLER_SIGNING_IDENTITY" \
  "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"

if [[ "$VALIDATE_WITH_ALTOOL" == "1" ]]; then
  require_value "ASC_USERNAME" "${ASC_USERNAME:-}" \
    "Set ASC_USERNAME to the Apple ID or App Store Connect API key issuer format expected by altool."
  require_value "ASC_PASSWORD" "${ASC_PASSWORD:-}" \
    "Set ASC_PASSWORD to an app-specific password or app-store-connect API key password."

  xcrun altool --validate-app \
    --type macos \
    --file "$PKG_PATH" \
    --username "$ASC_USERNAME" \
    --password "@env:ASC_PASSWORD"
fi

echo "Created App Store package: $PKG_PATH"
