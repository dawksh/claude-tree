# claude-tree

One git worktree per branch, one tmux session per worktree, Claude Code and nvim
already running inside it. Built for juggling several parallel features in the
same repo without losing which window belongs to which tree.

## Install

```sh
ln -sf ~/projects/claude-tree/bin/ct ~/.local/bin/ct
echo 'source-file ~/projects/claude-tree/tmux/claude-tree.conf' >> ~/.tmux.conf
tmux source-file ~/.tmux.conf      # or prefix + r
ct doctor
```

## Commands

```
ct new <branch> [--from <base>] [--bare]   create worktree, bootstrap, open session
ct go [query]                              pick a tree (fzf) and switch to it
ct resume [query]                          reopen a closed tree; Claude continues where it left off
ct down [branch|--all]                     close the tree's session, keep the worktree
ct ls                                      list worktrees, session state, dirtiness
ct rm <branch> [--force]                   kill session, remove worktree, prune branch
ct doctor                                  check the install
```

## Keys

| key | does |
|---|---|
| `M-w` | tree picker (fzf popup), including "+ new branch…" |
| `M-e` | toggle claude ↔ vim in the current tree |
| `M-1` / `M-2` / `M-3` | claude / vim / shell |
| `M-q` | close this tree (asks first; worktree kept) |

Prefix stays `C-a`; `M-arrow` pane movement is untouched.

## Layout

```
~/projects/webauth                     main checkout
~/projects/.worktrees/webauth/feat-otp  worktree
tmux session  webauth/feat-otp  ->  windows: claude, vim, shell
```

Each window starts a shell in the tree and then runs its command, so quitting
Claude or nvim leaves a shell in the right directory rather than closing the
window.

`M` is Meta — Option/Alt.

## Closing and resuming

`ct down` (or `M-q`) kills the tree's tmux session and nothing else: the
worktree, the branch and Claude's history all stay. `ct down --all` closes every
tree at once, after listing them and asking. `ct rm` is the destructive one.

`ct resume [query]` rebuilds the session and Claude picks up the same
conversation — the first launch in a worktree starts fresh and leaves a marker,
every later one runs `claude --continue`, which reads that directory's own
history. This survives a hard `kill-session`, since Claude writes its transcript
as it goes.

To leave Claude without closing the tree: `/exit`, `Ctrl-D`, or `Ctrl-C` twice.
The window drops back to a shell in the worktree.

## Per-repo config

Optional `.claude-tree` at the repo root, sourced by `ct new`:

```sh
CT_LINK_DIRS=(node_modules)      # symlinked from main when the lockfile matches
CT_COPY_GLOBS=('.env*')          # copied from main, so a tree can diverge
CT_INSTALL_CMD='npm ci'          # used instead when the lockfile differs
CT_POST_CREATE='echo "PORT=$((3000 + CT_TREE_INDEX))" >> .env.local'
```

`CT_TREE_DIR`, `CT_TREE_BRANCH` and `CT_TREE_INDEX` are exported to the hook.
`CT_TREE_INDEX` is a stable small integer per tree — use it to derive a dev
server port so two trees can run at once.

Build output (`.next`, `dist`) is never shared between trees.

`--bare` skips deps, env and Claude, and just prints the new worktree path.
