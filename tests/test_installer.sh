#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export ST_PREFIX="$TEST_ROOT/bin"
export ST_CONFDIR="$TEST_ROOT/config"
export ST_NO_TMUX_CONF=1
export ST_HARNESS=codex
export ST_YES=1
export ST_TEST_SOURCE="$ROOT"
mkdir -p "$HOME/.local/bin"

for command in tmux fzf nvim codex; do
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s 1.0.0\n" "$(basename "$0")"' > "$HOME/.local/bin/$command"
  chmod +x "$HOME/.local/bin/$command"
done

printf '%s\n' \
  '#!/bin/sh' \
  'output=""' \
  'url=""' \
  'while [ "$#" -gt 0 ]; do' \
  '  case $1 in' \
  '    -o) output=$2; shift 2;;' \
  '    -*) shift;;' \
  '    *) url=$1; shift;;' \
  '  esac' \
  'done' \
  'case $url in' \
  '  */st) cp "$ST_TEST_SOURCE/bin/st" "$output";;' \
  '  */supertree.conf) cp "$ST_TEST_SOURCE/tmux/supertree.conf" "$output";;' \
  '  *) exit 1;;' \
  'esac' > "$HOME/.local/bin/curl"
chmod +x "$HOME/.local/bin/curl"

"$ROOT/install.sh" >/dev/null

[ -x "$ST_PREFIX/st" ] || { printf 'FAIL: st was not installed\n' >&2; exit 1; }
grep -qx 'ST_HARNESS=codex' "$ST_CONFDIR/config" || {
  printf 'FAIL: installer did not persist the harness choice\n' >&2
  exit 1
}
grep -F "$ST_PREFIX/st agent" "$ST_CONFDIR/supertree.conf" >/dev/null || {
  printf 'FAIL: tmux agent binding did not use the install prefix\n' >&2
  exit 1
}

printf 'ok: installer harness selection and config\n'
