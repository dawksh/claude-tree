#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
export ST_WORKTREE_ROOT="$TEST_ROOT/trees"
export ST_STATE="$TEST_ROOT/state"
export ST_CONFDIR="$TEST_ROOT/config"
export ST_CONFIG="$ST_CONFDIR/config"
export TMUX_CONF="$HOME/.tmux.conf"
mkdir -p "$HOME/.local/bin" "$ST_WORKTREE_ROOT" "$ST_STATE" "$ST_CONFDIR"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

printf '%s\n' '#!/bin/sh' 'exit 1' > "$HOME/.local/bin/tmux"
chmod +x "$HOME/.local/bin/tmux"

main="$TEST_ROOT/main"
git init -q "$main"
git -C "$main" -c user.name=Test -c user.email=test@example.com \
  commit -q --allow-empty -m init
linked="$ST_WORKTREE_ROOT/group/linked"
git -C "$main" worktree add -q -b linked "$linked"
standalone="$ST_WORKTREE_ROOT/group/standalone"
git init -q "$standalone"
git -C "$standalone" -c user.name=Test -c user.email=test@example.com \
  commit -q --allow-empty -m init
printf '%s\n' "$main" > "$ST_STATE/repos"
printf 'keep\n' > "$ST_WORKTREE_ROOT/group/notes"

if printf 'n\n' | "$ROOT/bin/st" remove all --force > "$TEST_ROOT/no.out" 2>&1; then
  fail 'declined bulk removal succeeded'
fi
[ -d "$linked" ] && [ -d "$standalone" ] || fail 'decline removed a checkout'
if printf 'y\n' | "$ROOT/bin/st" remove all > "$TEST_ROOT/safe.out" 2>&1; then
  fail 'bulk removal accepted a standalone repo without force'
fi
[ -d "$linked" ] && [ -d "$standalone" ] || fail 'preflight removed a checkout'
printf 'y\n' | "$ROOT/bin/st" remove all --force > "$TEST_ROOT/force.out" 2>&1
[ ! -e "$linked" ] && [ ! -e "$standalone" ] || fail 'bulk removal left a checkout'
[ -f "$ST_WORKTREE_ROOT/group/notes" ] || fail 'bulk removal deleted an unrelated file'
[ -d "$main" ] || fail 'bulk removal deleted main repo outside root'

# A standalone repo still owning a worktree elsewhere must not be destroyed.
git init -q "$standalone"
git -C "$standalone" -c user.name=Test -c user.email=test@example.com \
  commit -q --allow-empty -m init
external="$TEST_ROOT/external"
git -C "$standalone" worktree add -q -b external "$external"
if printf 'y\n' | "$ROOT/bin/st" remove all --force > "$TEST_ROOT/external.out" 2>&1; then
  fail 'bulk removal orphaned an external worktree'
fi
[ -d "$standalone" ] && [ -d "$external" ] || fail 'external guard deleted a checkout'
git -C "$standalone" worktree remove "$external"
printf 'y\n' | "$ROOT/bin/st" remove all --force > "$TEST_ROOT/clear.out" 2>&1
[ ! -e "$standalone" ] || fail 'bulk removal left standalone repo after guard cleared'

# The normal path keeps the existing dirty-tree protection.
git -C "$main" worktree add -q -b dirty "$linked"
printf 'change\n' > "$linked/new-file"
if printf 'y\n' | "$ROOT/bin/st" remove all > "$TEST_ROOT/dirty.out" 2>&1; then
  fail 'bulk removal accepted a dirty worktree without force'
fi
[ -d "$linked" ] || fail 'dirty worktree was removed'
printf 'y\n' | "$ROOT/bin/st" remove all --force > "$TEST_ROOT/dirty-force.out" 2>&1
[ ! -e "$linked" ] || fail 'forced bulk removal left dirty worktree'

# Exercise the installed command via a source-install symlink. It must remove
# the link and Supertree files while leaving the source checkout intact.
ln -s "$ROOT/bin/st" "$HOME/.local/bin/st"
printf 'ST_HARNESS=codex\n' > "$ST_CONFIG"
printf '# user setting\n\n# supertree\nsource-file %s/supertree.conf\n# keep\n' \
  "$ST_CONFDIR" > "$TMUX_CONF"
printf 'bindings\n' > "$ST_CONFDIR/supertree.conf"
printf 'other\n' > "$ST_CONFDIR/other"
printf 'state\n' > "$ST_STATE/recent"
if printf 'n\n' | "$HOME/.local/bin/st" uninstall > "$TEST_ROOT/uninstall-no.out" 2>&1; then
  fail 'declined uninstall succeeded'
fi
[ -L "$HOME/.local/bin/st" ] || fail 'decline removed command'
printf 'y\n' | "$HOME/.local/bin/st" uninstall > "$TEST_ROOT/uninstall.out" 2>&1
[ ! -e "$HOME/.local/bin/st" ] || fail 'uninstall left command'
[ ! -e "$ST_CONFDIR/supertree.conf" ] && [ ! -e "$ST_CONFIG" ] || fail 'uninstall left config'
[ ! -e "$ST_STATE" ] || fail 'uninstall left state'
[ -f "$ST_CONFDIR/other" ] || fail 'uninstall deleted unrelated config'
grep -q '^# keep$' "$TMUX_CONF" || fail 'uninstall damaged tmux config'
if grep -q 'supertree' "$TMUX_CONF"; then fail 'uninstall left tmux source'; fi
[ -f "$ROOT/bin/st" ] || fail 'uninstall deleted source command'

printf 'ok: bulk removal and uninstall\n'
