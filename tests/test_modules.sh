#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/bin"
cp "$ROOT/bin/st" "$TMP/bin/st"
cp -R "$ROOT/bin/st-lib" "$TMP/bin/st-lib"
ln -s "$TMP/bin/st" "$TMP/st"

cat > "$TMP/bin/st-lib/85-greeting.sh" <<'MODULE'
cmd_greet() { printf 'hello %s\n' "${1:-world}"; }
st_register_command greet cmd_greet 'greet someone'
MODULE

[ "$("$TMP/st" greet friend)" = 'hello friend' ]
help=$("$TMP/st" help)
grep -q 'greet someone' <<< "$help"

rm "$TMP/bin/st-lib/85-greeting.sh"
if "$TMP/st" greet > /dev/null 2>&1; then
  printf 'removed module still supplied its command\n' >&2
  exit 1
fi

# Feature modules can be removed without breaking the loader.
rm "$TMP/bin/st-lib/60-picker.sh" "$TMP/bin/st-lib/70-worktrees.sh" \
  "$TMP/bin/st-lib/90-maintenance.sh"
[ "$("$TMP/st" --version)" = 'st dev' ]
"$TMP/st" help > /dev/null

printf 'ok: module discovery, removal, and source symlink\n'
