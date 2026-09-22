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

Claude resumes per tree: the first launch in a worktree starts fresh, every
later one runs `claude --continue`, which picks up that directory's own
conversation.

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
