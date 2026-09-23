#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"
tar -czf "$TMP/st.tar.gz" -C "$ROOT/bin" st st-lib

cat > "$TMP/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = -fsSL ]
[ "$3" = -o ]
cp "$ST_TEST_BUNDLE" "$4"
CURL
chmod +x "$TMP/bin/curl"

sed "s|^ST_VERSION='dev'$|ST_VERSION='v2.0.0'|" \
  "$ROOT/scripts/legacy-upgrade.sh" > "$TMP/bin/st"
chmod +x "$TMP/bin/st"

output=$(HOME="$TMP/home" PATH="$TMP/bin:$PATH" \
  ST_TEST_BUNDLE="$TMP/st.tar.gz" ST_RELEASE_ROOT=https://example.invalid/supertree \
  "$TMP/bin/st" --version)
[ "$output" = 'st v2.0.0' ]
[ -f "$TMP/bin/st-lib-v2.0.0/00-core.sh" ]
grep -q 'st_lib_dir=' "$TMP/bin/st"

printf 'ok: legacy single-file upgrade to modular bundle\n'
