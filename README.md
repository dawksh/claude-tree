# supertree

Work on several branches of the same repo at once, each in its own git worktree,
each with its own tmux session, each with your chosen coding agent and nvim
already running.

One key switches between trees, one key flips agent ↔ nvim, one key closes a
tree. Reopening a tree puts the agent back in the same conversation.

```
tmux sessions
  webauth/main       [codex][vim][shell]
  webauth/feat-otp   [codex][vim][shell]
  fe/crypto-monitor  [codex][vim][shell]
```

---

## Install

```sh
curl -fsSL https://github.com/dawksh/supertree/releases/latest/download/install.sh | bash
```

The installer first asks which coding-agent harness to use: Claude Code, Codex,
or OpenRouter via OpenCode. It writes the choice to
`~/.config/supertree/config`, checks `tmux`, `git`, `fzf`, `nvim` and the chosen
agent, and offers to install anything missing. Nothing is installed without a
yes; if there is no terminal to answer on, it skips and carries on.

Then it installs `st` to `~/.local/bin`, the tmux fragment to
`~/.config/supertree/`, and adds one `source-file` line to `~/.tmux.conf`
(backing it up first).

Overrides:

```sh
ST_VERSION=v0.1.0 …     pin a release instead of latest
ST_PREFIX=~/bin …       install st somewhere else
ST_CONFDIR=~/.tmux …    put the tmux fragment somewhere else
ST_NO_TMUX_CONF=1 …     do not touch ~/.tmux.conf
ST_YES=1 …              answer yes to every prompt (CI, dotfile bootstraps)
ST_HARNESS=codex …       choose claude, codex, or openrouter non-interactively
```

### From source

```sh
git clone https://github.com/dawksh/supertree ~/projects/supertree
ln -sf ~/projects/supertree/bin/st ~/.local/bin/st
echo 'source-file ~/projects/supertree/tmux/supertree.conf' >> ~/.tmux.conf
tmux source-file ~/.tmux.conf      # or prefix + r
```

Needs `tmux`, `git`, `fzf`, `nvim`, the configured agent binary, and
`~/.local/bin` on `PATH`. `st doctor` checks all of it.

### Update

Re-run the installer. `st` is a single file; nothing else changes.

---

## Quick start

```sh
cd ~/projects/webauth
st new feat-otp        # worktree + deps + env + session, drops you in the agent
# ... work ...
M-q                    # close the tree
st resume feat-otp     # back, the agent continues the same conversation
st rm feat-otp         # done with it: session, worktree and branch go away
```

---

## Commands

| command | what it does |
|---|---|
| `st new <branch>` | Create the worktree, bootstrap it, build the tmux session, switch to it. Reuses the branch if it already exists, otherwise creates it. |
| `st go [query]` | Switch to a tree. No query opens an fzf picker; a query picks the first match. Builds the session first if the tree is closed. |
| `st resume [query]` | Same as `go`. Named for the case where you closed a tree earlier and want it back. |
| `st down [branch]` | Close a tree's tmux session. Worktree, branch and agent history stay. No branch = the tree you are in. |
| `st down --all` | Close every tree session. Lists them and asks first. |
| `st ls` | Every worktree of every known repo: session live or not, `*` if the tree is dirty, path. |
| `st rm <branch>` | Destructive: kills the session, removes the worktree, deletes the branch if merged. |
| `st doctor` | Check dependencies, `PATH`, the symlink, the `~/.tmux.conf` line. |

### Flags

```
st new <branch> --from <base>    branch off <base> instead of current HEAD
st new <branch> --bare           skip deps, env and the agent; just print the worktree path
st rm <branch> --force           remove even with uncommitted or unpushed work
st down --all -y                 skip the confirmation
```

### Internal

`st agent`, `st toggle`, `st go --picker`, `st _run`, `st _agent`, `st _sessions` are called
by the tmux bindings, not by hand.

---

## Keys

`M` is Meta — the Option/Alt key.

| key | does |
|---|---|
| `M-w` | tree picker (fzf popup), including a `+ new branch…` row |
| `M-e` | toggle agent ↔ vim in the current tree |
| `M-1` / `M-2` / `M-3` | agent / vim / shell window |
| `M-q` | close this tree, asks first (worktree kept) |

Prefix stays `C-a`. `M-arrow` pane movement and `S-Enter` are untouched.
`status-left` shows the current session name, so the tree you are typing into is
always on screen.

---

## Layout

```
~/projects/webauth                        main checkout
~/projects/.worktrees/webauth/feat-otp    worktree for feat-otp
tmux session "webauth/feat-otp"           windows: codex, vim, shell
```

Session names are `<repo>/<branch>`, with `.` and `:` replaced by `-` (tmux
forbids them). Windows are addressed by **name**, not index, so your
`base-index` setting is irrelevant.

Each window runs its program directly, then drops to an interactive shell in the
same worktree. Quitting the agent or nvim leaves you in a shell there instead of
closing the window.

## Agent harnesses

The installer creates `~/.config/supertree/config`. Change `ST_HARNESS`, then
close and resume a tree to rebuild it cleanly with the new agent window:

```sh
ST_HARNESS=codex       # claude | codex | openrouter
```

| value | terminal program | continuation command |
|---|---|---|
| `claude` | Claude Code (`claude`) | `claude --continue` |
| `codex` | Codex CLI (`codex`) | `codex resume --last` |
| `openrouter` | OpenCode (`opencode`) connected to OpenRouter | `opencode --continue` |

For OpenRouter, launch OpenCode once, run `/connect`, and select OpenRouter. API
keys remain in OpenCode's own credential store; supertree does not read or copy
them.

Custom terminal agents work too:

```sh
ST_HARNESS=aider
ST_HARNESS_COMMAND='aider'
ST_HARNESS_RESUME_COMMAND='aider --resume'
```

The harness name becomes the tmux window name and must contain only letters,
digits, `_`, or `-`. The config is sourced as shell code, so only put commands
there that you trust. `ST_HARNESS` in the environment overrides the config for
one invocation.

---

## Creating a tree

`st new` does four things, all skippable with `--bare`:

1. **Worktree** — `git worktree add` under `~/projects/.worktrees/<repo>/<slug>`.
2. **Deps** — symlinks each `ST_LINK_DIRS` entry from the main checkout, but only
   when the lockfile is byte-identical. If it differs, runs `ST_INSTALL_CMD`
   instead, so a branch that changed dependencies never silently runs main's
   `node_modules` or writes into it.
3. **Env** — copies each `ST_COPY_GLOBS` match from the main checkout. Copies,
   not symlinks, so a tree can diverge.
4. **Hook** — runs `ST_POST_CREATE`.

Build output (`.next`, `dist`) is never shared between trees.

### Per-repo config

Optional `.supertree` at the repo root, sourced by `st new`:

```sh
ST_LINK_DIRS=(node_modules)      # symlinked from main when the lockfile matches
ST_COPY_GLOBS=('.env*')          # copied from main
ST_INSTALL_CMD='npm ci'          # used when the lockfile differs
ST_LOCKFILES=(package-lock.json yarn.lock pnpm-lock.yaml bun.lockb)
ST_POST_CREATE='echo "PORT=$((3000 + ST_TREE_INDEX))" >> .env.local'
```

The hook gets `ST_TREE_DIR`, `ST_TREE_BRANCH` and `ST_TREE_INDEX`.
`ST_TREE_INDEX` is a stable small integer per tree — derive a dev server port
from it so two trees can run at once.

The file is sourced as a shell script, so it runs as you. Fine for your own
repos; do not point `st` at a checkout you do not trust.

---

## Closing, resuming, exiting

**Leave the agent, keep the tree open** — use the agent's exit command or
`Ctrl-D`. The window falls back to a shell in the worktree. `M-1` recreates the
configured agent window if it has been closed.

**Close the tree** — `M-q` or `st down`. Kills only the tmux session. Unsaved
nvim buffers in that session are lost.

Closing never detaches you from tmux. tmux's `detach-on-destroy` is `on` by
default, so killing the session your client sits in would normally drop you to
the shell. `st` moves every attached client off the session first — back to the
session you came from when `st` switched you there (remembered per client tty
under `~/.local/state/supertree/origin/`), otherwise to the most recently used
other session. Same for `st rm` and `st down --all`. Your own
`detach-on-destroy` setting is left alone.

**Close everything** — `st down --all`, which lists the sessions and asks.

**Come back** — `st resume [branch]` or `M-w`. The session is rebuilt and the
configured agent resumes that worktree's own conversation. The first launch for
each agent in a tree starts fresh and leaves a marker; later launches use that
agent's continuation command. Agent transcripts live in their native stores, so
this survives a hard `kill-session`, not just a clean exit.

**Delete the tree** — `st rm <branch>`. Refuses while there are uncommitted
changes or unpushed commits unless you pass `--force`, prints what it will
remove, and asks. The branch is deleted only if it is merged.

---

## State

| path | holds |
|---|---|
| `~/projects/.worktrees/<repo>/<slug>` | the worktrees |
| `~/.local/state/supertree/repos` | repos `st` knows about (appended by `st new`) |
| `~/.local/state/supertree/idx/<repo>/<slug>` | that tree's `ST_TREE_INDEX` |
| `~/.local/state/supertree/seen/<repo>/<slug>.<harness>` | marker meaning that agent has run here, drives continuation |
| `~/.local/state/supertree/origin/<tty>` | which session a client came from, so closing a tree returns it there |

A repo only shows up in `st go` / `st ls` after its first `st new`. Override the
worktree root with `ST_WORKTREE_ROOT`, the state dir with `ST_STATE`.

---

## Troubleshooting

**`M-w` does nothing** — your terminal is eating Option. In WezTerm, Option must
send Meta rather than composing characters. Your `M-arrow` pane binds are the
quick test: if those work, these do.

**`st go` says "no current client"** — run from a shell that is not attached to a
tmux client. Harmless from scripts; from a real pane it switches normally.

**A tree is missing from the picker** — its repo was never registered. Run
`st new` once in that repo, or add the main checkout path to
`~/.local/state/supertree/repos`.

**`st new` ran a full install instead of linking** — the main checkout's lockfile
differs from the new tree's, usually because you have uncommitted lockfile
changes on main. Intended.

**The agent started fresh instead of continuing** — check `st doctor`, the
configured harness, and that tree's `seen` marker. Each agent keeps a separate
marker and its own native history.

**OpenRouter is selected but no models appear** — run `opencode`, enter
`/connect`, choose OpenRouter, then use `/models` to select a model.
