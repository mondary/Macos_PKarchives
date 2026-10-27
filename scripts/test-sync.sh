#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${ROOT}/.build"
mkdir -p "$BUILD"
SDK_FLAGS=()
if [[ -n "${PK_MACOS_SDK:-}" ]]; then SDK_FLAGS=(-sdk "$PK_MACOS_SDK"); fi
if [[ ${#SDK_FLAGS[@]} -eq 0 && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  SDK_FLAGS=(-sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk)
fi
RCLONE="${PK_TEST_RCLONE:-$HOME/.local/share/pkarchives/bin/rclone}"
[[ -x "$RCLONE" ]] || RCLONE="$(command -v rclone)"
swiftc "${SDK_FLAGS[@]}" -parse-as-library \
  "$ROOT/src/macos/PKSyncEngine.swift" "$ROOT/tests/SyncEngineTests.swift" \
  -framework AppKit -framework Combine -o "$BUILD/sync-tests"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pkarchives-sync-tests.XXXXXX")"
PK_TEST_RCLONE="$RCLONE" PK_TEST_ROOT="$TEST_ROOT" "$BUILD/sync-tests"
