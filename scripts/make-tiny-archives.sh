#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-version.sh"

APP_NAME="I Hate PDFs"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/tiny"
ARCHS_TO_BUILD="${ARCHS_TO_BUILD:-arm64 x86_64}"
PER_ARCH_INSTALLER_MAX_BYTES="${PER_ARCH_INSTALLER_MAX_BYTES:-400000}"

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

file_size() {
  stat -f '%z' "$1"
}

verify_under_budget() {
  local path="$1"
  [[ -f "$path" ]] || {
    echo "missing $path" >&2
    exit 1
  }

  local bytes
  bytes="$(file_size "$path")"
  if (( bytes >= PER_ARCH_INSTALLER_MAX_BYTES )); then
    echo "$path is $bytes bytes; per-architecture installer budget is < $PER_ARCH_INSTALLER_MAX_BYTES bytes" >&2
    exit 1
  fi

  echo "OK: $path is $bytes bytes (< $PER_ARCH_INSTALLER_MAX_BYTES)."
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
  verify_under_budget "$ARCHIVE_PATH"
done
