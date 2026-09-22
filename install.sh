#!/usr/bin/env bash
# claude-tree installer
#   curl -fsSL https://raw.githubusercontent.com/dawksh/claude-tree/main/install.sh | bash
#
# env overrides:
#   CT_VERSION=v0.1.0   install a specific release instead of latest
#   CT_PREFIX=~/bin     where the ct binary goes        (default ~/.local/bin)
#   CT_CONFDIR=~/.conf  where the tmux fragment goes    (default ~/.config/claude-tree)
#   CT_NO_TMUX_CONF=1   skip touching ~/.tmux.conf
set -euo pipefail

REPO=dawksh/claude-tree
VERSION=${CT_VERSION:-latest}
PREFIX=${CT_PREFIX:-$HOME/.local/bin}
CONFDIR=${CT_CONFDIR:-$HOME/.config/claude-tree}
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

say "downloading claude-tree ($VERSION)"
curl -fsSL "$BASE/ct"              -o "$tmpdir/ct"              || die "could not download ct from $BASE"
curl -fsSL "$BASE/claude-tree.conf" -o "$tmpdir/claude-tree.conf" || die "could not download claude-tree.conf from $BASE"

head -1 "$tmpdir/ct" | grep -q '^#!' || die "downloaded ct does not look like a script"

mkdir -p "$PREFIX" "$CONFDIR"
install -m 0755 "$tmpdir/ct" "$PREFIX/ct"
say "installed $PREFIX/ct"

# point the bindings at wherever ct actually landed
sed "s|~/.local/bin/ct|$PREFIX/ct|g" "$tmpdir/claude-tree.conf" > "$CONFDIR/claude-tree.conf"
say "installed $CONFDIR/claude-tree.conf"

if [ "${CT_NO_TMUX_CONF:-0}" != 1 ]; then
  if [ -f "$TMUX_CONF" ] && grep -q 'claude-tree.conf' "$TMUX_CONF"; then
    say "$TMUX_CONF already sources claude-tree.conf"
  else
    [ -f "$TMUX_CONF" ] && cp "$TMUX_CONF" "$TMUX_CONF.pre-claude-tree"
    printf '\n# claude-tree\nsource-file %s/claude-tree.conf\n' "$CONFDIR" >> "$TMUX_CONF"
    say "added source-file line to $TMUX_CONF (backup: $TMUX_CONF.pre-claude-tree)"
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
say "done — run 'ct doctor' to verify, 'ct new <branch>' inside a repo to start"
