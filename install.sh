#!/usr/bin/env bash
# supertree installer
#   curl -fsSL https://github.com/dawksh/supertree/releases/latest/download/install.sh | bash
#
# env overrides:
#   ST_VERSION=v0.1.0   install a specific release instead of latest
#   ST_PREFIX=~/bin     where the st binary goes        (default ~/.local/bin)
#   ST_CONFDIR=~/.conf  where the tmux fragment goes    (default ~/.config/supertree)
#   ST_NO_TMUX_CONF=1   skip touching ~/.tmux.conf
#   ST_YES=1            answer yes to every prompt (non-interactive installs)
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

# ----------------------------------------------------------------- output

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$(printf '\033[1m'); D=$(printf '\033[2m'); R=$(printf '\033[0m')
  GRN=$(printf '\033[32m'); RED=$(printf '\033[31m'); YLW=$(printf '\033[33m')
else
  B=""; D=""; R=""; GRN=""; RED=""; YLW=""
fi

WIDTH=52
# progress lines overwrite themselves on a terminal, stack up in a pipe or log
if [ -t 1 ]; then CLEAR='\033[2K\r'; else CLEAR='\n'; fi
rule() { printf '%s' "$D"; printf '─%.0s' $(seq 1 $WIDTH); printf '%s\n' "$R"; }
title() {
  printf '\n  %ssupertree%s %sinstaller%s\n' "$B" "$R" "$D" "$R"
  printf '  %sworktree + tmux + Claude Code harness%s\n\n' "$D" "$R"
}
step() { printf '\n  %s%s%s\n\n' "$B" "$1" "$R"; }
ok()   { printf '  %s✔%s %s\n' "$GRN" "$R" "$1"; }
bad()  { printf '  %s✘%s %s\n' "$RED" "$R" "$1"; }
warn() { printf '  %s!%s %s\n' "$YLW" "$R" "$1"; }
die()  { printf '\n  %s✘ %s%s\n\n' "$RED" "$1" "$R" >&2; exit 1; }

row() { # name, status glyph+color, detail
  printf '  %s %-9s %s%s%s\n' "$2" "$1" "$D" "$3" "$R"
}

ask() { # question -> 0 yes, 1 no
  [ "${ST_YES:-0}" = 1 ] && return 0
  [ -r /dev/tty ] || { warn "no terminal to ask on; skipping"; return 1; }
  local a
  printf '\n  %s %s[Y/n]%s ' "$1" "$D" "$R"
  # a failed read means no one is there to answer — never take that as consent
  if ! { read -r a < /dev/tty; } 2>/dev/null; then
    printf '\n'; warn "no terminal to ask on; skipping"; return 1
  fi
  case ${a:-y} in y|Y|yes|YES) return 0;; *) return 1;; esac
}

# ------------------------------------------------------------ dependencies

DEPS="tmux git fzf nvim claude"

dep_why() {
  case $1 in
    tmux)   echo "required for sessions and windows";;
    git)    echo "required for worktrees";;
    fzf)    echo "tree picker (M-w)";;
    nvim)   echo "editor window (M-2)";;
    claude) echo "claude window (M-1)";;
  esac
}

dep_version() {
  local v
  case $1 in
    tmux) v=$(tmux -V 2>/dev/null);;                    # tmux has no --version
    nvim) v=$(nvim --version 2>/dev/null | head -1);;
    *)    v=$("$1" --version 2>/dev/null | head -1) || v="";;
  esac
  printf '%s' "$v" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

detect_pm() {
  if command -v brew >/dev/null 2>&1; then echo brew
  elif command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v pacman >/dev/null 2>&1; then echo pacman
  elif command -v apk >/dev/null 2>&1; then echo apk
  else echo none; fi
}

pkg_name() { # cmd, pm
  case $1 in
    nvim) echo neovim;;
    *)    echo "$1";;
  esac
}

sudo_if_needed() {
  [ "$(id -u)" = 0 ] && { echo ""; return; }
  command -v sudo >/dev/null 2>&1 && echo sudo || echo ""
}

install_one() { # cmd, pm, logfile
  local cmd=$1 pm=$2 log=$3 pkg S
  pkg=$(pkg_name "$cmd"); S=$(sudo_if_needed)

  # Claude Code ships its own installer; package managers only carry it on brew.
  # https://code.claude.com/docs/en/setup#install-claude-code
  if [ "$cmd" = claude ]; then
    if [ "$pm" = brew ]; then brew install --cask claude-code >>"$log" 2>&1
    else curl -fsSL https://claude.ai/install.sh | bash >>"$log" 2>&1; fi
    return
  fi

  case $pm in
    brew)   brew install "$pkg" >>"$log" 2>&1;;
    apt)    $S apt-get update -qq >>"$log" 2>&1 && $S apt-get install -y "$pkg" >>"$log" 2>&1;;
    dnf)    $S dnf install -y "$pkg" >>"$log" 2>&1;;
    pacman) $S pacman -S --noconfirm "$pkg" >>"$log" 2>&1;;
    apk)    $S apk add "$pkg" >>"$log" 2>&1;;
    *)      return 1;;
  esac
}

# ------------------------------------------------------------------ main

command -v curl >/dev/null 2>&1 || die "curl is required"

tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
LOG="$tmpdir/install.log"

title
rule
step "dependencies"

missing=""
for d in $DEPS; do
  if command -v "$d" >/dev/null 2>&1; then
    row "$d" "${GRN}✔${R}" "$(dep_version "$d")"
  else
    row "$d" "${RED}✘${R}" "not found — $(dep_why "$d")"
    missing="$missing $d"
  fi
done

if [ -n "$missing" ]; then
  pm=$(detect_pm)
  n=$(printf '%s' "$missing" | wc -w | tr -d ' ')
  if [ "$pm" = none ]; then
    printf '\n'
    warn "$n missing, and no supported package manager found"
    warn "install them yourself, then re-run this installer"
    [ "$(uname -s)" = Darwin ] && warn "on macOS: https://brew.sh"
  elif ask "install $n missing package(s) with $B$pm$R?"; then
    printf '\n'
    for d in $missing; do
      printf '  %s…%s installing %-8s' "$D" "$R" "$d"
      if install_one "$d" "$pm" "$LOG"; then printf "$CLEAR"; ok "installed $d"
      else printf "$CLEAR"; bad "failed $d — see log below"; fi
    done
    hash -r 2>/dev/null || true
    still=""
    for d in $missing; do command -v "$d" >/dev/null 2>&1 || still="$still $d"; done
    if [ -n "$still" ]; then
      printf '\n'; warn "still missing:$still"
      if [ -s "$LOG" ]; then
        printf '\n%s' "$D"; tail -12 "$LOG" | sed 's/^/    /'; printf '%s\n' "$R"
      fi
    fi
  else
    printf '\n'; warn "skipped — supertree installs anyway, some features stay dark"
  fi
fi

# ------------------------------------------------------------- supertree

step "supertree"

curl -fsSL "$BASE/st"            -o "$tmpdir/st"            || die "could not download st from $BASE"
curl -fsSL "$BASE/supertree.conf" -o "$tmpdir/supertree.conf" || die "could not download supertree.conf from $BASE"
head -1 "$tmpdir/st" | grep -q '^#!' || die "downloaded st does not look like a script"

mkdir -p "$PREFIX" "$CONFDIR"
install -m 0755 "$tmpdir/st" "$PREFIX/st"
ok "st           $PREFIX/st"

sed "s|~/.local/bin/st|$PREFIX/st|g" "$tmpdir/supertree.conf" > "$CONFDIR/supertree.conf"
ok "bindings     $CONFDIR/supertree.conf"

if [ "${ST_NO_TMUX_CONF:-0}" != 1 ]; then
  if [ -f "$TMUX_CONF" ] && grep -q 'supertree.conf' "$TMUX_CONF"; then
    ok "tmux config  already wired up"
  else
    [ -f "$TMUX_CONF" ] && cp "$TMUX_CONF" "$TMUX_CONF.pre-supertree"
    printf '\n# supertree\nsource-file %s/supertree.conf\n' "$CONFDIR" >> "$TMUX_CONF"
    ok "tmux config  $TMUX_CONF (backup: .pre-supertree)"
  fi
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$TMUX_CONF" >/dev/null 2>&1 && ok "tmux         reloaded"
  fi
fi

case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) printf '\n'; warn "$PREFIX is not on your PATH"
     printf '    %sexport PATH="%s:$PATH"%s\n' "$D" "$PREFIX" "$R";;
esac

step "next"
printf '  %sst doctor%s          verify the install\n' "$B" "$R"
printf '  %sst new <branch>%s    from inside any git repo\n' "$B" "$R"
printf '  %sM-w%s picker   %sM-e%s claude↔vim   %sM-q%s close tree\n\n' "$B" "$R" "$B" "$R" "$B" "$R"
rule
printf '\n'
