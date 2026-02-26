# gw

gw lets you create, switch, and clean up git worktrees with a single command.
When creating a worktree, it automatically copies over untracked files like
`.env` and runs setup commands like `pnpm install` through `.gwconfig` — so
each worktree is ready to work in immediately. It also provides tab completion,
one-command bulk cleanup of merged branches, and a simple init process to
restructure any existing project for the worktree workflow.

## Installation

### One-liner

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/eezy0/gw/main/install.sh)
```

Installs as an Oh My Zsh plugin if available, otherwise to `~/.zsh-functions/`.

### Oh My Zsh

```sh
git clone https://github.com/eezy0/gw.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/gw
```

Add `gw` to your plugins in `~/.zshrc`:

```zsh
plugins=(... gw)
```

### Manual

```sh
curl -fsSL https://raw.githubusercontent.com/eezy0/gw/main/gw.plugin.zsh -o ~/.zsh-functions/gw.zsh
echo 'source ~/.zsh-functions/gw.zsh' >> ~/.zshrc
```

After any method, restart your shell or run `source ~/.zshrc`.

## Quick Start

```sh
gw init              # restructure project for worktree workflow
gw task/1234         # create worktree and switch (based on current branch)
gw task/1234 develop # create worktree based on develop
gw task/1234         # already exists — just switch to it
gw delete task/1234  # remove worktree and its local branch
gw prune             # bulk-remove worktrees whose remote branch was deleted
gw list              # list worktrees — marks current with ← here
gw config            # open/create .gwconfig
gw -b init           # use -b when branch name conflicts with a subcommand
```

## How It Works

Running `gw <branch>` creates a worktree in the **parent directory** of the main worktree and switches to it.

```
~/projects/
├── my-app/          ← main worktree
├── task/1234/       ← gw task/1234
└── fix/login-bug/   ← gw fix/login-bug
```

Branch resolution:

- Local branch exists → use it
- Remote branch exists → create a tracking branch
- No branch found → create a new branch from the current branch (or from `base` if specified)

## Commands

### `gw init`

Converts an existing git project into the gw worktree structure.

```
# Before                    # After
~/projects/my-app/          ~/projects/my-app/
├── .git/                   ├── main/          ← main worktree
├── src/                    │   ├── .git/
└── ...                     │   ├── src/
                            │   └── ...
                            └── .gwconfig
```

Must be run on `main` or `master` branch with no linked worktrees.

### `gw delete <branch>`

Removes the worktree and deletes its local branch. Works even if you're currently inside the worktree being deleted (automatically moves you to the main worktree). Force-removes if there are uncommitted changes.

### `gw prune`

After merging PRs on GitHub, remote branches get deleted. `gw prune` detects these stale worktrees and removes them in bulk — along with their local branches.

```sh
gw prune             # interactive bulk removal
gw prune --dry-run   # preview what would be removed
```

Also cleans up broken worktrees whose directories were manually deleted.

## Tab Completion

- `gw <Tab>` — subcommands + branch names
- `gw d <Tab>` — existing worktree branches only

## Configuration (.gwconfig)

Place a `.gwconfig` file in the worktree parent directory. It is automatically applied when creating new worktrees. Use `gw config` to open or create it.

```sh
# gw config
# Applied automatically when creating new worktrees.

# Files to copy from main worktree to new worktrees
GW_COPY_FILES=(
  ".env"
  ".env.local"
)

# Commands to run after creating a worktree
GW_POST_COMMANDS=(
  "pnpm install"
  "pnpm build"
)
```

## License

MIT
