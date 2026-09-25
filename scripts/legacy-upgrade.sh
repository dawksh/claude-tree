#!/usr/bin/env bash
# Compatibility entrypoint for single-file st installations. The old updater
# downloads this as /st; its first invocation installs the modular bundle.
set -euo pipefail

ST_VERSION='dev'
release_root=${ST_RELEASE_ROOT:-https://github.com/dawksh/supertree}
case $ST_VERSION in
  dev|'') printf 'st: the upgrade command is missing its release version\n' >&2; exit 1;;
  *[!A-Za-z0-9._-]*) printf 'st: invalid release version\n' >&2; exit 1;;
esac

self=$0
case $self in */*) ;; *) self=$(command -v -- "$self");; esac
prefix=$(cd "$(dirname "$self")" && pwd)
self="$prefix/$(basename "$self")"
tmp=$(mktemp -d)
staged=$(mktemp "$prefix/.st.upgrade.XXXXXX")
staged_lib=$(mktemp -d "$prefix/.st-lib.upgrade.XXXXXX")
printf -v cleanup 'rm -rf %q %q %q' "$tmp" "$staged" "$staged_lib"
trap "$cleanup" EXIT

curl -fsSL "$release_root/releases/download/$ST_VERSION/st.tar.gz" -o "$tmp/st.tar.gz" ||
  { printf 'st: could not download modular release %s\n' "$ST_VERSION" >&2; exit 1; }
tar -tzf "$tmp/st.tar.gz" | awk '
  $0 == "st" || $0 == "st-lib/" || $0 ~ /^st-lib\/[A-Za-z0-9_.-]+\.sh$/ { next }
  { exit 1 }
' || { printf 'st: invalid modular release archive\n' >&2; exit 1; }
mkdir "$tmp/package"
tar -xzf "$tmp/st.tar.gz" -C "$tmp/package"
[ -f "$tmp/package/st-lib/00-core.sh" ] ||
  { printf 'st: modular release is missing its modules\n' >&2; exit 1; }
head -1 "$tmp/package/st" | grep -qx '#!/usr/bin/env bash'
for file in "$tmp/package"/st-lib/*.sh; do bash -n "$file"; done
sed "s|^ST_VERSION='dev'$|ST_VERSION='$ST_VERSION'|" "$tmp/package/st" > "$tmp/stamped"
grep -qx "ST_VERSION='$ST_VERSION'" "$tmp/stamped"
bash -n "$tmp/stamped"

install -m 0755 "$tmp/stamped" "$staged"
cp "$tmp/package"/st-lib/*.sh "$staged_lib/"
previous_lib=''
if [ -e "$prefix/st-lib-$ST_VERSION" ]; then
  previous_lib=$(mktemp -d "$prefix/.st-lib.previous.XXXXXX")
  rmdir "$previous_lib"
  mv "$prefix/st-lib-$ST_VERSION" "$previous_lib"
fi
if ! mv "$staged_lib" "$prefix/st-lib-$ST_VERSION"; then
  [ -z "$previous_lib" ] || mv "$previous_lib" "$prefix/st-lib-$ST_VERSION"
  printf 'st: could not install modules\n' >&2
  exit 1
fi
if ! mv -f "$staged" "$self"; then
  rm -rf "$prefix/st-lib-$ST_VERSION"
  [ -z "$previous_lib" ] || mv "$previous_lib" "$prefix/st-lib-$ST_VERSION"
  printf 'st: could not replace command\n' >&2
  exit 1
fi
[ -z "$previous_lib" ] || rm -rf "$previous_lib"
rm -rf "$tmp" "$staged" "$staged_lib"
trap - EXIT
exec "$self" "$@"
