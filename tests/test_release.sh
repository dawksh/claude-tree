#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/scripts/release.sh"

assert_equal() {
  [ "$1" = "$2" ] || {
    printf 'expected %s, got %s\n' "$2" "$1" >&2
    exit 1
  }
}

assert_equal "$(next_version v0.3.2 patch)" v0.3.3
assert_equal "$(next_version v0.3.2 minor)" v0.4.0
assert_equal "$(next_version v0.3.2 major)" v1.0.0
assert_equal "$(next_version v1.9.9 minor)" v1.10.0
if next_version v0.3 invalid >/dev/null 2>&1; then
  printf 'accepted an invalid release tag\n' >&2
  exit 1
fi

assert_equal "$(choose_bump '')" patch
assert_equal "$(choose_bump $'docs\nrelease:minor')" minor
assert_equal "$(choose_bump $'release:major\nfix')" major
assert_equal "$(choose_bump $'release:minor\nrelease:major')" major

printf 'ok: release version and label selection\n'
