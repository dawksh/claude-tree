# shellcheck shell=bash
# supertree identity module

slugify() { printf '%s' "$1" | tr '/.: ' '----'; }

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256
  else die "a SHA-256 tool (shasum, sha256sum, or openssl) is required"
  fi | sed 's/^.*= //; s/ .*//'
}

identity_hash() { printf '%s' "$1" | sha256_stream | cut -c1-32; }

config_fingerprint() { sha256_stream < "$1"; }

key_part() {
  local label identity=${2:-$1}
  label=$(printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-' | cut -c1-48)
  [ -n "$label" ] || label=item
  printf '%s-%s' "$label" "$(identity_hash "$identity")"
}

repo_key() { key_part "$(basename "$1")" "$1"; }

branch_key() { key_part "$1"; }

tree_dir()  { printf '%s/%s/%s' "$ST_WORKTREE_ROOT" "$1" "$2"; }

sess_name() { printf '%s/%s' "$1" "$2"; }

tree_label() { printf '%s/%s' "${1%-*}" "$2"; }
