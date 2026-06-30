#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/release-version.sh"

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
PER_ARCH_INSTALLER_MAX_BYTES="${PER_ARCH_INSTALLER_MAX_BYTES:-400000}"
PER_ARCH_INSTALLER_EXTENSION="${PER_ARCH_INSTALLER_EXTENSION:-tar.xz}"

fail() {
  echo "release size verification failed: $*" >&2
  exit 1
}

file_size() {
  stat -f '%z' "$1"
}

verify_under_budget() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing $path"

  local bytes
  bytes="$(file_size "$path")"
  if (( bytes >= PER_ARCH_INSTALLER_MAX_BYTES )); then
    fail "$path is $bytes bytes; per-architecture installer budget is < $PER_ARCH_INSTALLER_MAX_BYTES bytes"
  fi

  echo "OK: $path is $bytes bytes (< $PER_ARCH_INSTALLER_MAX_BYTES)."
}

if (( $# > 0 )); then
  for artifact in "$@"; do
    verify_under_budget "$artifact"
  done
else
  verify_under_budget "$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos-arm64.$PER_ARCH_INSTALLER_EXTENSION"
  verify_under_budget "$DIST_DIR/IHatePDFs-v$RELEASE_VERSION-macos-x86_64.$PER_ARCH_INSTALLER_EXTENSION"
fi
