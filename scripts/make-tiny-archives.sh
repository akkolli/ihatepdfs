#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-version.sh"

APP_NAME="I Hate PDFs"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/tiny"
ARCHS_TO_BUILD="${ARCHS_TO_BUILD:-arm64 x86_64}"

if ! command -v xz >/dev/null 2>&1; then
  echo "xz is required to build size-gated tiny archives with architecture filters." >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

compression_args_for_arch() {
  local arch="$1"

  if [[ -n "${XZ_OPT:-}" ]]; then
    # Preserve explicit caller overrides.
    echo "$XZ_OPT"
    return
  fi

  case "$arch" in
    arm64)
      echo "--arm64 --lzma2=preset=9e"
      ;;
    x86_64)
      echo "--x86 --lzma2=preset=9e"
      ;;
    *)
      echo "--lzma2=preset=9e"
      ;;
  esac
}

for ARCH in $ARCHS_TO_BUILD; do
  APP_DIR="$STAGING_DIR/$ARCH/$APP_NAME.app"
  ARCHIVE_PATH="$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos-$ARCH.tar.xz"

  rm -f "$ARCHIVE_PATH"
  mkdir -p "$(dirname "$APP_DIR")"

  ARCHS="$ARCH" \
    SIZE_OPTIMIZED=1 \
    ICON_MAX_SIZE="${ICON_MAX_SIZE:-32}" \
    APP_VERSION="$APP_VERSION" \
    BUILD_NUMBER="$BUILD_NUMBER" \
    APP_DIR="$APP_DIR" \
    "$ROOT_DIR/scripts/build-app.sh"

  read -r -a XZ_ARGS <<< "$(compression_args_for_arch "$ARCH")"
  COPYFILE_DISABLE=1 tar -C "$(dirname "$APP_DIR")" -cf - "$APP_NAME.app" \
    | env XZ_OPT= xz "${XZ_ARGS[@]}" -c > "$ARCHIVE_PATH"

  echo "Created $ARCHIVE_PATH"
done

"$ROOT_DIR/scripts/verify-release-size.sh"
