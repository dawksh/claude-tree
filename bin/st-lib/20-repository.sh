# shellcheck shell=bash
# supertree repository module

trusted_config_snapshot=''

main_worktree() {
  git -C "${1:-.}" worktree list --porcelain 2>/dev/null |
    awk 'NR==1 && /^worktree /{print substr($0,10)}'
}

require_repo() {
  local m
  m=$(main_worktree "${1:-.}") || true
  [ -n "$m" ] || die "not inside a git repository"
  printf '%s' "$m"
}

register_repo() {
  mkdir -p "$ST_STATE"
  grep -qxF "$1" "$ST_REPOS" 2>/dev/null || printf '%s\n' "$1" >> "$ST_REPOS"
}

session_for_label() {
  local wanted=$1 repo branch path
  while IFS=$'\t' read -r repo branch path; do
    if [ "$(tree_label "$repo" "$branch")" = "$wanted" ]; then
      sess_name "$repo" "$(branch_key "$branch")"
      return 0
    fi
  done < <(list_trees)
  return 1
}

label_for_session() {
  local wanted=$1 repo branch path
  while IFS=$'\t' read -r repo branch path; do
    if [ "$(sess_name "$repo" "$(branch_key "$branch")")" = "$wanted" ]; then
      tree_label "$repo" "$branch"
      return 0
    fi
  done < <(list_trees)
  printf 'unknown tree'
}

branch_worktree() {
  local main=$1 branch=$2 line path=''
  while IFS= read -r line; do
    case $line in
      'worktree '*) path=${line#worktree };;
      'branch '*)
        if [ "${line#branch }" = "refs/heads/$branch" ]; then
          printf '%s' "$path"
          return 0
        fi;;
    esac
  done < <(git -C "$main" worktree list --porcelain)
  return 1
}

managed_tree() {
  local main=$1 branch=$2 path=$3 repo slug
  repo=$(repo_key "$main")
  slug=$(branch_key "$branch")
  [ "$path" -ef "$(tree_dir "$repo" "$slug")" ] && return 0
  [ "$path" -ef "$(tree_dir "$(basename "$main")" "$(slugify "$branch")")" ]
}

prepare_repo_config() {
  local main=$1 expected actual
  [ -f "$main/.supertree" ] || return 0
  trusted_config_snapshot=$(mktemp)
  trap 'rm -f "${trusted_config_snapshot:-}"' EXIT
  cp "$main/.supertree" "$trusted_config_snapshot"
  actual=$(config_fingerprint "$trusted_config_snapshot")
  expected=$(cat "$ST_STATE/trust/$(repo_key "$main")" 2>/dev/null || true)
  [ "$actual" = "$expected" ] ||
    die "untrusted or changed $main/.supertree; review it, then run 'st trust' in that repository"
}

tree_index() {
  local repo=$1 slug=$2 old_repo=$3 f="$ST_STATE/idx/$1/$2" n
  if [ -f "$f" ]; then cat "$f"; return; fi
  mkdir -p "$ST_STATE/idx/$repo"
  n=$(cat "$ST_STATE/idx/$repo"/* "$ST_STATE/idx/$old_repo"/* 2>/dev/null | sort -n | tail -1)
  n=$(( ${n:-0} + 1 ))
  printf '%s\n' "$n" | tee "$f"
}

list_trees() {
  local r repo
  [ -f "$ST_REPOS" ] || return 0
  while read -r r; do
    [ -d "$r" ] || continue
    repo=$(repo_key "$r")
    git -C "$r" worktree list --porcelain 2>/dev/null | awk -v repo="$repo" '
      /^worktree /{p=substr($0,10)}
      /^branch /{b=$2; sub("refs/heads/","",b); print repo"\t"b"\t"p}
      /^detached$/{print repo"\t(detached)\t"p}'
  done < "$ST_REPOS"
}
