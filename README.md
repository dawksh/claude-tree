# claude-tree

Work on several branches of the same repo at once, each in its own git worktree,
each with its own tmux session, each with Claude Code and nvim already running.

One key switches between trees, one key flips Claude ↔ nvim, one key closes a
tree. Reopening a tree puts Claude back in the same conversation.

```
tmux sessions
  webauth/main       [claude][vim][shell]
  webauth/feat-otp   [claude][vim][shell]
  fe/crypto-monitor  [claude][vim][shell]
```

---

## Install

```sh
ln -sf ~/projects/claude-tree/bin/ct ~/.local/bin/ct
echo 'source-file ~/projects/claude-tree/tmux/claude-tree.conf' >> ~/.tmux.conf
tmux source-file ~/.tmux.conf      # or prefix + r
ct doctor
```

Needs `tmux`, `git`, `fzf`, `nvim`, `claude`, and `~/.local/bin` on `PATH`.
`ct doctor` checks all of it.

---

## Quick start

```sh
cd ~/projects/webauth
ct new feat-otp        # worktree + deps + env + session, drops you in Claude
# ... work ...
M-q                    # close the tree
ct resume feat-otp     # back, Claude continues the same conversation
ct rm feat-otp         # done with it: session, worktree and branch go away
```

---

## Commands

| command | what it does |
|---|---|
| `ct new <branch>` | Create the worktree, bootstrap it, build the tmux session, switch to it. Reuses the branch if it already exists, otherwise creates it. |
| `ct go [query]` | Switch to a tree. No query opens an fzf picker; a query picks the first match. Builds the session first if the tree is closed. |
| `ct resume [query]` | Same as `go`. Named for the case where you closed a tree earlier and want it back. |
| `ct down [branch]` | Close a tree's tmux session. Worktree, branch and Claude history stay. No branch = the tree you are in. |
| `ct down --all` | Close every tree session. Lists them and asks first. |
| `ct ls` | Every worktree of every known repo: session live or not, `*` if the tree is dirty, path. |
| `ct rm <branch>` | Destructive: kills the session, removes the worktree, deletes the branch if merged. |
| `ct doctor` | Check dependencies, `PATH`, the symlink, the `~/.tmux.conf` line. |

### Flags

```
ct new <branch> --from <base>    branch off <base> instead of current HEAD
ct new <branch> --bare           skip deps, env and Claude; just print the worktree path
ct rm <branch> --force           remove even with uncommitted or unpushed work
ct down --all -y                 skip the confirmation
```

### Internal

`ct toggle`, `ct go --picker`, `ct _run`, `ct _claude`, `ct _sessions` are called
by the tmux bindings, not by hand.

---

## Keys

`M` is Meta — the Option/Alt key.

| key | does |
|---|---|
| `M-w` | tree picker (fzf popup), including a `+ new branch…` row |
| `M-e` | toggle claude ↔ vim in the current tree |
| `M-1` / `M-2` / `M-3` | claude / vim / shell window |
| `M-q` | close this tree, asks first (worktree kept) |

Prefix stays `C-a`. `M-arrow` pane movement and `S-Enter` are untouched.
`status-left` shows the current session name, so the tree you are typing into is
always on screen.

---

## Layout

```
~/projects/webauth                        main checkout
~/projects/.worktrees/webauth/feat-otp    worktree for feat-otp
tmux session "webauth/feat-otp"           windows: claude, vim, shell
```

Session names are `<repo>/<branch>`, with `.` and `:` replaced by `-` (tmux
forbids them). Windows are addressed by **name**, not index, so your
`base-index` setting is irrelevant.

Each window runs its program directly, then drops to an interactive shell in the
same worktree. Quitting Claude or nvim leaves you in a shell there instead of
closing the window.

---

## Creating a tree

`ct new` does four things, all skippable with `--bare`:

1. **Worktree** — `git worktree add` under `~/projects/.worktrees/<repo>/<slug>`.
2. **Deps** — symlinks each `CT_LINK_DIRS` entry from the main checkout, but only
   when the lockfile is byte-identical. If it differs, runs `CT_INSTALL_CMD`
   instead, so a branch that changed dependencies never silently runs main's
   `node_modules` or writes into it.
3. **Env** — copies each `CT_COPY_GLOBS` match from the main checkout. Copies,
   not symlinks, so a tree can diverge.
4. **Hook** — runs `CT_POST_CREATE`.

Build output (`.next`, `dist`) is never shared between trees.

### Per-repo config

Optional `.claude-tree` at the repo root, sourced by `ct new`:

```sh
CT_LINK_DIRS=(node_modules)      # symlinked from main when the lockfile matches
CT_COPY_GLOBS=('.env*')          # copied from main
CT_INSTALL_CMD='npm ci'          # used when the lockfile differs
CT_LOCKFILES=(package-lock.json yarn.lock pnpm-lock.yaml bun.lockb)
CT_POST_CREATE='echo "PORT=$((3000 + CT_TREE_INDEX))" >> .env.local'
```

The hook gets `CT_TREE_DIR`, `CT_TREE_BRANCH` and `CT_TREE_INDEX`.
`CT_TREE_INDEX` is a stable small integer per tree — derive a dev server port
from it so two trees can run at once.

The file is sourced as a shell script, so it runs as you. Fine for your own
repos; do not point `ct` at a checkout you do not trust.

---

## Closing, resuming, exiting

**Leave Claude, keep the tree open** — `/exit`, `Ctrl-D`, or `Ctrl-C` twice. The
window falls back to a shell in the worktree. `M-1` or re-running `claude` picks
it up again.

**Close the tree** — `M-q` or `ct down`. Kills only the tmux session. Unsaved
nvim buffers in that session are lost.

Closing never detaches you from tmux. tmux's `detach-on-destroy` is `on` by
default, so killing the session your client sits in would normally drop you to
the shell. `ct` moves every attached client off the session first — back to the
session you came from when `ct` switched you there (remembered per client tty
under `~/.local/state/claude-tree/origin/`), otherwise to the most recently used
other session. Same for `ct rm` and `ct down --all`. Your own
`detach-on-destroy` setting is left alone.

**Close everything** — `ct down --all`, which lists the sessions and asks.

**Come back** — `ct resume [branch]` or `M-w`. The session is rebuilt and Claude
resumes that worktree's own conversation: the first launch in a tree starts
fresh and leaves a marker, every launch after that runs `claude --continue`.
Because Claude writes its transcript as it goes, this survives a hard
`kill-session`, not just a clean exit.

**Delete the tree** — `ct rm <branch>`. Refuses while there are uncommitted
changes or unpushed commits unless you pass `--force`, prints what it will
remove, and asks. The branch is deleted only if it is merged.

---

## State

| path | holds |
|---|---|
| `~/projects/.worktrees/<repo>/<slug>` | the worktrees |
| `~/.local/state/claude-tree/repos` | repos `ct` knows about (appended by `ct new`) |
| `~/.local/state/claude-tree/idx/<repo>/<slug>` | that tree's `CT_TREE_INDEX` |
| `~/.local/state/claude-tree/seen/<repo>/<slug>` | marker meaning "Claude has run here", drives `--continue` |
| `~/.local/state/claude-tree/origin/<tty>` | which session a client came from, so closing a tree returns it there |

A repo only shows up in `ct go` / `ct ls` after its first `ct new`. Override the
worktree root with `CT_WORKTREE_ROOT`, the state dir with `CT_STATE`.

---

## Troubleshooting

**`M-w` does nothing** — your terminal is eating Option. In WezTerm, Option must
send Meta rather than composing characters. Your `M-arrow` pane binds are the
quick test: if those work, these do.

**`ct go` says "no current client"** — run from a shell that is not attached to a
tmux client. Harmless from scripts; from a real pane it switches normally.

**A tree is missing from the picker** — its repo was never registered. Run
`ct new` once in that repo, or add the main checkout path to
`~/.local/state/claude-tree/repos`.

**`ct new` ran a full install instead of linking** — the main checkout's lockfile
differs from the new tree's, usually because you have uncommitted lockfile
changes on main. Intended.

**Claude started fresh instead of continuing** — the `seen` marker for that tree
was removed, or Claude has no history for that directory yet. `--continue` also
falls back to a fresh session rather than failing.
