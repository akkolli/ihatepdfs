#!/usr/bin/env bash
set -euo pipefail

APP_NAME="I Hate PDFs"
EXECUTABLE_NAME="IHatePDFs"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-version.sh"
CONFIGURATION="${CONFIGURATION:-release}"
BUNDLE_ID="${BUNDLE_ID:-net.akkolli.ihatepdfs}"
SIZE_OPTIMIZED="${SIZE_OPTIMIZED:-0}"
STRIP_RELEASE="${STRIP_RELEASE:-1}"
ICON_MAX_SIZE="${ICON_MAX_SIZE:-1024}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"
CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:-1}"
CODESIGN_OPTIONS="${CODESIGN_OPTIONS:-}"
PLISTBUDDY="/usr/libexec/PlistBuddy"
if [[ -z "${ARCHS+x}" && "$CONFIGURATION" == "release" ]]; then
  ARCHS="arm64 x86_64"
else
  ARCHS="${ARCHS:-}"
fi
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="${APP_DIR:-$DIST_DIR/$APP_NAME.app}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="${ICON_SOURCE:-$ROOT_DIR/assets/app-icon.png}"
if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon source: $ICON_SOURCE" >&2
  echo "Set ICON_SOURCE to the path of a transparent PNG icon (for example: $ROOT_DIR/assets/app-icon.png)." >&2
  exit 1
fi

if ! sips -g hasAlpha "$ICON_SOURCE" 2>/dev/null | grep -q "hasAlpha: yes"; then
  echo "App icon source must include an alpha channel for transparent rendering: $ICON_SOURCE" >&2
  exit 1
fi
ICON_NAME="AppIcon"
DERIVED_ENTITLEMENTS_PATH=""
PROFILE_PLIST_PATH=""
NORMALIZED_ICON_SOURCE=""

cleanup() {
  if [[ -n "$DERIVED_ENTITLEMENTS_PATH" ]]; then
    rm -f "$DERIVED_ENTITLEMENTS_PATH"
  fi
  if [[ -n "$NORMALIZED_ICON_SOURCE" ]]; then
    rm -f "$NORMALIZED_ICON_SOURCE"
  fi
  if [[ -n "$PROFILE_PLIST_PATH" ]]; then
    rm -f "$PROFILE_PLIST_PATH"
  fi
}
trap cleanup EXIT

set_plist_string() {
  local plist="$1"
  local key="$2"
  local value="$3"

  if "$PLISTBUDDY" -c "Set :$key $value" "$plist" >/dev/null 2>&1; then
    return
  fi
  "$PLISTBUDDY" -c "Add :$key string $value" "$plist"
}

cd "$ROOT_DIR"
SWIFT_BUILD_ARGS=(-c "$CONFIGURATION")
for ARCH in $ARCHS; do
  SWIFT_BUILD_ARGS+=(--arch "$ARCH")
done
if [[ "$CONFIGURATION" == "release" && "$SIZE_OPTIMIZED" == "1" ]]; then
  SWIFT_BUILD_ARGS+=(
    -Xswiftc -Osize
    -Xswiftc -Xfrontend -Xswiftc -disable-reflection-metadata
    -Xswiftc -Xfrontend -Xswiftc -remove-runtime-asserts
  )
fi

BUILD_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"
swift build "${SWIFT_BUILD_ARGS[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"

if [[ "$CONFIGURATION" == "release" && "$STRIP_RELEASE" != "0" ]]; then
  if [[ "$SIZE_OPTIMIZED" == "1" ]]; then
    strip -u -r "$MACOS_DIR/$EXECUTABLE_NAME"
  else
    strip -x "$MACOS_DIR/$EXECUTABLE_NAME"
  fi
fi

NORMALIZED_ICON_SOURCE="$(mktemp /tmp/ihatepdf-appicon-XXXXXX.png)"
if ! sips -s format png "$ICON_SOURCE" --out "$NORMALIZED_ICON_SOURCE" >/dev/null; then
  rm -f "$NORMALIZED_ICON_SOURCE"
  NORMALIZED_ICON_SOURCE=""
  echo "Failed to normalize icon source: $ICON_SOURCE" >&2
  exit 1
fi
ICON_SOURCE="$NORMALIZED_ICON_SOURCE"

if [[ -n "$PROVISIONING_PROFILE" ]]; then
  if [[ ! -f "$PROVISIONING_PROFILE" ]]; then
    echo "Missing provisioning profile: $PROVISIONING_PROFILE" >&2
    exit 1
  fi
  cp "$PROVISIONING_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"
  xattr -cr "$CONTENTS_DIR/embedded.provisionprofile" 2>/dev/null || true
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon source: $ICON_SOURCE" >&2
  exit 1
fi

ICONSET_DIR="$DIST_DIR/$ICON_NAME.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

make_icon() {
  local pixels="$1"
  local output="$2"
  local output_path="$ICONSET_DIR/$output"

  sips -s format png --resampleHeightWidth "$pixels" "$pixels" "$ICON_SOURCE" --out "$output_path" >/dev/null
}

make_icon 16 "icon_16x16.png"
make_icon 32 "icon_16x16@2x.png"
make_icon 32 "icon_32x32.png"
make_icon 64 "icon_32x32@2x.png"
if (( ICON_MAX_SIZE >= 128 )); then
  make_icon 128 "icon_128x128.png"
fi
if (( ICON_MAX_SIZE >= 128 )); then
  make_icon 256 "icon_128x128@2x.png"
fi
if (( ICON_MAX_SIZE >= 256 )); then
  make_icon 256 "icon_256x256.png"
fi
if (( ICON_MAX_SIZE >= 512 )); then
  make_icon 512 "icon_256x256@2x.png"
  make_icon 512 "icon_512x512.png"
fi
if (( ICON_MAX_SIZE >= 1024 )); then
  make_icon 1024 "icon_512x512@2x.png"
fi

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$ICON_NAME.icns"
rm -rf "$ICONSET_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>PDF Document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.adobe.pdf</string>
      </array>
    </dict>
  </array>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>LSSupportsOpeningDocumentsInPlace</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>GNU General Public License version 2</string>
</dict>
</plist>
PLIST

if [[ -n "$SIGNING_IDENTITY" ]]; then
  if [[ -n "$ENTITLEMENTS_PATH" && ! -f "$ENTITLEMENTS_PATH" ]]; then
    echo "Missing entitlements file: $ENTITLEMENTS_PATH" >&2
    exit 1
  fi

  APP_ENTITLEMENTS_PATH="$ENTITLEMENTS_PATH"
  if [[ -n "$PROVISIONING_PROFILE" ]]; then
    PROFILE_PLIST_PATH="$(mktemp "$DIST_DIR/profile.XXXXXX.plist")"
    security cms -D -i "$PROVISIONING_PROFILE" > "$PROFILE_PLIST_PATH"
    APP_IDENTIFIER="$("$PLISTBUDDY" -c "Print :Entitlements:com.apple.application-identifier" "$PROFILE_PLIST_PATH")"
    TEAM_IDENTIFIER="$("$PLISTBUDDY" -c "Print :Entitlements:com.apple.developer.team-identifier" "$PROFILE_PLIST_PATH")"

    DERIVED_ENTITLEMENTS_PATH="$(mktemp "$DIST_DIR/entitlements.XXXXXX.plist")"
    if [[ -n "$ENTITLEMENTS_PATH" ]]; then
      cp "$ENTITLEMENTS_PATH" "$DERIVED_ENTITLEMENTS_PATH"
    else
      cat > "$DERIVED_ENTITLEMENTS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
    fi

    set_plist_string "$DERIVED_ENTITLEMENTS_PATH" "com.apple.application-identifier" "$APP_IDENTIFIER"
    set_plist_string "$DERIVED_ENTITLEMENTS_PATH" "com.apple.developer.team-identifier" "$TEAM_IDENTIFIER"
    APP_ENTITLEMENTS_PATH="$DERIVED_ENTITLEMENTS_PATH"
  fi

  CODESIGN_ARGS=(--force --sign "$SIGNING_IDENTITY")
  if [[ "$CODESIGN_TIMESTAMP" != "0" ]]; then
    CODESIGN_ARGS+=(--timestamp)
  fi
  if [[ -n "$CODESIGN_OPTIONS" ]]; then
    CODESIGN_ARGS+=(--options "$CODESIGN_OPTIONS")
  fi
  if [[ -n "$APP_ENTITLEMENTS_PATH" ]]; then
    CODESIGN_ARGS+=(--entitlements "$APP_ENTITLEMENTS_PATH")
  fi

  codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
  codesign --verify --strict --verbose=2 "$APP_DIR"
fi

echo "Built $APP_DIR"
du -sh "$APP_DIR" "$MACOS_DIR/$EXECUTABLE_NAME" "$RESOURCES_DIR/$ICON_NAME.icns"
