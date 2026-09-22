#!/usr/bin/env bash
# supertree installer
#   curl -fsSL https://raw.githubusercontent.com/dawksh/supertree/main/install.sh | bash
#
# env overrides:
#   ST_VERSION=v0.1.0   install a specific release instead of latest
#   ST_PREFIX=~/bin     where the st binary goes        (default ~/.local/bin)
#   ST_CONFDIR=~/.conf  where the tmux fragment goes    (default ~/.config/supertree)
#   ST_NO_TMUX_CONF=1   skip touching ~/.tmux.conf
set -euo pipefail

REPO=dawksh/supertree
VERSION=${ST_VERSION:-latest}
PREFIX=${ST_PREFIX:-$HOME/.local/bin}
CONFDIR=${ST_CONFDIR:-$HOME/.config/supertree}
TMUX_CONF=${TMUX_CONF:-$HOME/.tmux.conf}

if [ "$VERSION" = latest ]; then
  BASE="https://github.com/$REPO/releases/latest/download"
else
  BASE="https://github.com/$REPO/releases/download/$VERSION"
fi

say()  { printf '\033[2m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

say "downloading supertree ($VERSION)"
curl -fsSL "$BASE/st"              -o "$tmpdir/st"              || die "could not download st from $BASE"
curl -fsSL "$BASE/supertree.conf" -o "$tmpdir/supertree.conf" || die "could not download supertree.conf from $BASE"

head -1 "$tmpdir/st" | grep -q '^#!' || die "downloaded st does not look like a script"

mkdir -p "$PREFIX" "$CONFDIR"
install -m 0755 "$tmpdir/st" "$PREFIX/st"
say "installed $PREFIX/st"

# point the bindings at wherever st actually landed
sed "s|~/.local/bin/st|$PREFIX/st|g" "$tmpdir/supertree.conf" > "$CONFDIR/supertree.conf"
say "installed $CONFDIR/supertree.conf"

if [ "${ST_NO_TMUX_CONF:-0}" != 1 ]; then
  if [ -f "$TMUX_CONF" ] && grep -q 'supertree.conf' "$TMUX_CONF"; then
    say "$TMUX_CONF already sources supertree.conf"
  else
    [ -f "$TMUX_CONF" ] && cp "$TMUX_CONF" "$TMUX_CONF.pre-supertree"
    printf '\n# supertree\nsource-file %s/supertree.conf\n' "$CONFDIR" >> "$TMUX_CONF"
    say "added source-file line to $TMUX_CONF (backup: $TMUX_CONF.pre-supertree)"
  fi
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$TMUX_CONF" && say "reloaded tmux config"
  fi
fi

case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) warn "$PREFIX is not on your PATH — add: export PATH=\"$PREFIX:\$PATH\"";;
esac

missing=""
for b in tmux git fzf nvim claude; do
  command -v "$b" >/dev/null 2>&1 || missing="$missing $b"
done
[ -n "$missing" ] && warn "missing dependencies:$missing"

printf '\n'
say "done — run 'st doctor' to verify, 'st new <branch>' inside a repo to start"
