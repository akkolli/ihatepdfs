#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-version.sh"

APP_NAME="I Hate PDFs"
BUNDLE_ID="${BUNDLE_ID:-net.akkolli.ihatepdfs}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos.dmg"
PKG_PATH="${PKG_PATH:-$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos-appstore.pkg}"
REQUIRE_APP_STORE_PKG="${REQUIRE_APP_STORE_PKG:-0}"
PLISTBUDDY="/usr/libexec/PlistBuddy"
TEMP_PATHS=()

cleanup() {
  ((${#TEMP_PATHS[@]})) || return 0
  for path in "${TEMP_PATHS[@]}"; do
    rm -rf "$path"
  done
}
trap cleanup EXIT

fail() {
  echo "release artifact verification failed: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -e "$path" ]] || fail "missing $path"
}

plist_value() {
  local plist="$1"
  local key="$2"
  "$PLISTBUDDY" -c "Print :$key" "$plist"
}

verify_app_bundle() {
  require_file "$APP_DIR/Contents/Info.plist"

  local version
  local build
  local bundle_id
  version="$(plist_value "$APP_DIR/Contents/Info.plist" "CFBundleShortVersionString")"
  build="$(plist_value "$APP_DIR/Contents/Info.plist" "CFBundleVersion")"
  bundle_id="$(plist_value "$APP_DIR/Contents/Info.plist" "CFBundleIdentifier")"

  [[ "$bundle_id" == "$BUNDLE_ID" ]] || fail "$APP_DIR bundle id is $bundle_id, expected $BUNDLE_ID"
  [[ "$version" == "$APP_VERSION" ]] || fail "$APP_DIR version is $version, expected $APP_VERSION"
  [[ "$build" == "$BUILD_NUMBER" ]] || fail "$APP_DIR build is $build, expected $BUILD_NUMBER"
  [[ ! -e "$APP_DIR/Contents/embedded.provisionprofile" ]] \
    || fail "$APP_DIR contains an embedded provisioning profile; direct DMG app should not"
}

verify_dmg() {
  require_file "$DMG_PATH"
  if command -v diskutil >/dev/null 2>&1 &&
     diskutil image info "$DMG_PATH" 2>/dev/null | grep -q "Image Format: UDZO"; then
    return
  fi

  if command -v hdiutil >/dev/null 2>&1 &&
     hdiutil imageinfo "$DMG_PATH" 2>/dev/null | grep -q "Format: UDZO"; then
    return
  fi

  fail "$DMG_PATH is not a compressed read-only UDZO image"
}

verify_pkg() {
  require_file "$PKG_PATH"
  pkgutil --check-signature "$PKG_PATH" >/dev/null

  local expanded_parent
  local expanded
  expanded_parent="$(mktemp -d "$DIST_DIR/pkg-verify.XXXXXX")"
  TEMP_PATHS+=("$expanded_parent")
  expanded="$expanded_parent/expanded.pkg"

  pkgutil --expand-full "$PKG_PATH" "$expanded" >/dev/null

  local plist
  plist="$(find "$expanded" -path "*/I Hate PDFs.app/Contents/Info.plist" -print -quit)"
  [[ -n "$plist" ]] || fail "$PKG_PATH does not contain I Hate PDFs.app"

  local app_contents
  app_contents="$(dirname "$plist")"
  local version
  local build
  local bundle_id
  version="$(plist_value "$plist" "CFBundleShortVersionString")"
  build="$(plist_value "$plist" "CFBundleVersion")"
  bundle_id="$(plist_value "$plist" "CFBundleIdentifier")"

  [[ "$bundle_id" == "$BUNDLE_ID" ]] || fail "$PKG_PATH app bundle id is $bundle_id, expected $BUNDLE_ID"
  [[ "$version" == "$APP_VERSION" ]] || fail "$PKG_PATH app version is $version, expected $APP_VERSION"
  [[ "$build" == "$BUILD_NUMBER" ]] || fail "$PKG_PATH app build is $build, expected $BUILD_NUMBER"
  [[ -e "$app_contents/embedded.provisionprofile" ]] \
    || fail "$PKG_PATH app is missing embedded.provisionprofile"

  local app_bundle
  local entitlements
  app_bundle="$(dirname "$app_contents")"
  entitlements="$expanded/entitlements.plist"
  codesign -d --entitlements :- "$app_bundle" > "$entitlements" 2>/dev/null \
    || fail "$PKG_PATH app entitlements could not be read"
  [[ "$(plist_value "$entitlements" "com.apple.security.app-sandbox")" == "true" ]] \
    || fail "$PKG_PATH app is missing com.apple.security.app-sandbox"
  [[ "$(plist_value "$entitlements" "com.apple.security.files.user-selected.read-write")" == "true" ]] \
    || fail "$PKG_PATH app is missing com.apple.security.files.user-selected.read-write"

  rm -rf "$expanded_parent"
}

verify_app_bundle
verify_dmg

if [[ "$REQUIRE_APP_STORE_PKG" == "1" || -e "$PKG_PATH" ]]; then
  verify_pkg
elif [[ "$REQUIRE_APP_STORE_PKG" == "0" ]]; then
  echo "Skipping App Store pkg verification because $PKG_PATH does not exist."
else
  fail "invalid REQUIRE_APP_STORE_PKG=$REQUIRE_APP_STORE_PKG"
fi

echo "Verified release artifacts for I Hate PDFs $APP_VERSION ($BUILD_NUMBER)."
