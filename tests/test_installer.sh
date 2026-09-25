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
export ST_TEST_LATEST=v9.8.7
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
  '    -w) shift 2;;' \
  '    -*) shift;;' \
  '    *) url=$1; shift;;' \
  '  esac' \
  'done' \
  'case $url in' \
  '  */releases/latest) printf "%s/releases/tag/%s" "$ST_RELEASE_ROOT" "$ST_TEST_LATEST";;' \
  '  */st.tar.gz) tar -czf "$output" -C "$ST_TEST_SOURCE/bin" st st-lib;;' \
  '  */supertree.conf) cp "$ST_TEST_SOURCE/tmux/supertree.conf" "$output";;' \
  '  *) exit 1;;' \
  'esac' > "$HOME/.local/bin/curl"
chmod +x "$HOME/.local/bin/curl"

export ST_RELEASE_ROOT=https://example.invalid/supertree
output=$("$ROOT/install.sh")

[ -x "$ST_PREFIX/st" ] || { printf 'FAIL: st was not installed\n' >&2; exit 1; }
[ -f "$ST_PREFIX/st-lib-$ST_TEST_LATEST/00-core.sh" ] || {
  printf 'FAIL: st modules were not installed\n' >&2; exit 1
}
grep -F "supertree $ST_TEST_LATEST" <<<"$output" >/dev/null || {
  printf 'FAIL: installer did not show the resolved version\n' >&2
  exit 1
}
[ "$("$ST_PREFIX/st" --version)" = "st $ST_TEST_LATEST" ] || {
  printf 'FAIL: installer did not stamp the resolved version\n' >&2
  exit 1
}
grep -qx 'ST_HARNESS=codex' "$ST_CONFDIR/config" || {
  printf 'FAIL: installer did not persist the harness choice\n' >&2
  exit 1
}
grep -qx "ST_WINDOWS='agent vim shell'" "$ST_CONFDIR/config" || {
  printf 'FAIL: installer did not persist the default window layout\n' >&2
  exit 1
}
grep -F "$ST_PREFIX/st window 1" "$ST_CONFDIR/supertree.conf" >/dev/null || {
  printf 'FAIL: tmux window binding did not use the install prefix\n' >&2
  exit 1
}

# A layout override updates the existing config and omits disabled dependencies.
export ST_WINDOWS='agent shell'
rm "$HOME/.local/bin/nvim"
output=$("$ROOT/install.sh")
grep -qx 'ST_WINDOWS="agent shell"' "$ST_CONFDIR/config" || {
  printf 'FAIL: installer did not update the window layout\n' >&2
  exit 1
}
if grep -Eq '^[[:space:]]+.[[:space:]]+nvim[[:space:]]' <<<"$output"; then
  printf 'FAIL: installer checked nvim for a layout without vim\n' >&2
  exit 1
fi

( unset ST_CONFDIR ST_CONFIG TMUX_CONF
  printf 'y\n' | "$ST_PREFIX/st" uninstall ) > "$TEST_ROOT/uninstall.out" 2>&1
[ ! -e "$ST_PREFIX/st" ] || {
  printf 'FAIL: uninstall left the installed command\n' >&2
  exit 1
}
[ ! -e "$ST_PREFIX/st.install" ] || {
  printf 'FAIL: uninstall left install metadata\n' >&2
  exit 1
}
[ ! -e "$ST_PREFIX/st-lib-$ST_TEST_LATEST" ] || {
  printf 'FAIL: uninstall left installed modules\n' >&2
  exit 1
}
[ ! -e "$ST_CONFDIR/config" ] && [ ! -e "$ST_CONFDIR/supertree.conf" ] || {
  printf 'FAIL: uninstall left installed config\n' >&2
  exit 1
}

printf 'ok: installer harness selection, window config, dependencies, and uninstall\n'
