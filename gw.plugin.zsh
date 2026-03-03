# gw - Git Worktree helper
# https://github.com/eezy0/gw
#
# Usage:
#   gw <branch> [base]    create worktree and switch
#   gw -b <branch> [base] use when name conflicts with subcommand
#   gw d|delete <branch>  remove worktree
#   gw p|prune [--dry-run] clean up stale worktrees
#   gw l|list             list worktrees
#   gw c|config           open/create .gwconfig
#   gw i|init             initialize gw structure
#   gw h|help             show help

gw() {
  if ! git rev-parse --show-toplevel &>/dev/null && [[ -f ".gwconfig" ]]; then
    local gw_main
    for d in */; do
      if [[ -d "${d}.git" ]]; then
        gw_main="${d%/}"
        break
      fi
    done
    if [[ -n "$gw_main" ]]; then
      cd "$gw_main"
    fi
  fi

  if [[ "$1" == "-b" ]]; then
    shift
  else
    case "$1" in
      d|delete)
        _gw_delete "$2"
        return $?
        ;;
      l|list)
        _gw_list
        return $?
        ;;
      c|config)
        _gw_config
        return $?
        ;;
      i|init)
        _gw_init
        return $?
        ;;
      p|prune)
        _gw_prune "$2"
        return $?
        ;;
      h|help)
        _gw_usage
        return 0
        ;;
      "")
        _gw_usage
        return 0
        ;;
    esac
  fi

  local branch="$1"
  local base="$2"

  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not in a git repository"
    return 1
  }

  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local main_worktree=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  local worktree_parent=$(dirname "$main_worktree")
  local worktree_path="$worktree_parent/$branch"

  if [[ -d "$worktree_path" ]]; then
    [[ -n "$base" ]] && echo "Warning: base branch '$base' ignored (worktree already exists)"
    cd "$worktree_path"
    return 0
  fi

  local base_branch="$current_branch"
  if [[ -n "$base" ]]; then
    if git show-ref --verify --quiet "refs/heads/$base"; then
      base_branch="$base"
    elif git show-ref --verify --quiet "refs/remotes/origin/$base"; then
      base_branch="origin/$base"
    elif git fetch origin "$base" 2>/dev/null && git show-ref --verify --quiet "refs/remotes/origin/$base"; then
      base_branch="origin/$base"
    else
      echo "Error: base branch '$base' not found"
      return 1
    fi
  fi

  echo "Creating worktree: $worktree_path"
  echo "Branch: $branch (base: $base_branch)"
  echo ""

  local _gw_did_stash=false

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    [[ -n "$base" ]] && echo "Warning: base branch '$base' ignored (local branch '$branch' already exists)"
    echo "Using existing local branch: $branch"
    git worktree add "$worktree_path" "$branch" || return 1
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    [[ -n "$base" ]] && echo "Warning: base branch '$base' ignored (remote branch 'origin/$branch' already exists)"
    echo "Using existing remote branch: origin/$branch"
    git worktree add -b "$branch" "$worktree_path" "origin/$branch" || return 1
  elif git fetch origin "$branch" 2>/dev/null && git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    [[ -n "$base" ]] && echo "Warning: base branch '$base' ignored (remote branch 'origin/$branch' found)"
    echo "Fetched remote branch: origin/$branch"
    git worktree add -b "$branch" "$worktree_path" "origin/$branch" || return 1
  else
    echo "Creating new branch: $branch"

    if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet HEAD 2>/dev/null; then
      echo ""
      echo "You have uncommitted changes in the current worktree."
      echo -n "Carry uncommitted changes to new branch? [y/N] "
      read -r confirm
      if [[ "$confirm" == [yY] ]]; then
        git stash push -m "gw: carry changes to $branch" || {
          echo "Error: Failed to stash changes"
          return 1
        }
        _gw_did_stash=true
      fi
    fi

    git worktree add -b "$branch" "$worktree_path" "$base_branch" || {
      if $_gw_did_stash; then
        echo "Restoring stashed changes..."
        git stash pop --quiet
      fi
      return 1
    }
  fi

  local config_file="$worktree_parent/.gwconfig"
  if [[ -f "$config_file" ]]; then
    local GW_COPY_FILES=()
    local GW_POST_COMMANDS=()
    source "$config_file"

    if (( ${#GW_COPY_FILES[@]} > 0 )); then
      echo "Copying files..."
      for file in "${GW_COPY_FILES[@]}"; do
        if [[ -f "$git_root/$file" ]]; then
          mkdir -p "$worktree_path/$(dirname "$file")"
          cp "$git_root/$file" "$worktree_path/$file"
          echo "  + $file"
        fi
      done
      echo ""
    fi

    cd "$worktree_path"

    if (( ${#GW_POST_COMMANDS[@]} > 0 )); then
      echo "Running post commands..."
      for cmd in "${GW_POST_COMMANDS[@]}"; do
        echo "  > $cmd"
        eval "$cmd" || {
          echo "Warning: Command failed: $cmd"
        }
      done
      echo ""
    fi
  else
    cd "$worktree_path"
  fi

  if $_gw_did_stash; then
    echo "Applying uncommitted changes..."
    if ! git stash pop; then
      echo ""
      echo "Warning: Stash could not be applied cleanly."
      echo "Your changes are still in the stash. Run 'git stash pop' manually to resolve conflicts."
    fi
    echo ""
  fi

  echo "Done! [$branch] $(pwd)"
}

_gw_usage() {
  cat <<'USAGE'
gw - Git Worktree helper

Usage:
  gw i|init             initialize gw structure
  gw <branch> [base]    create worktree and switch (or just switch if exists)
  gw d|delete <branch>  remove worktree
  gw p|prune            clean up worktrees whose remote branch was deleted
  gw p|prune --dry-run  preview what would be removed
  gw l|list             list worktrees
  gw c|config           open/create .gwconfig
  gw h|help             show help
  gw -b <branch> [base] use when branch name conflicts with a subcommand

Examples:
  gw i                 restructure project into project/main/ layout
  gw task/1234         create worktree for task/1234 (based on current branch)
  gw task/1234 develop create worktree based on develop
  gw task/1234         already exists — just switch to it
  gw d task/1234       remove task/1234 worktree
  gw prune             bulk-remove stale worktrees
  gw prune --dry-run   preview pruneable worktrees
  gw c                 edit .gwconfig (creates template if missing)
  gw -b init           create worktree for branch named "init"
USAGE
}

_gw_list() {
  local git_bin=$(command -v git)
  local current_dir=$(pwd)

  local -a gone_branches
  gone_branches=(${(f)"$(LC_ALL=C $git_bin branch -vv 2>/dev/null | awk '/: gone\]/{sub(/^[ *+]+/, ""); print $1}')"})

  $git_bin worktree list | while IFS= read -r line; do
    local wt_path=$(echo "$line" | awk '{print $1}')
    local wt_branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\].*/\1/p')
    local suffix=""
    if [[ "$current_dir" == "$wt_path" || "$current_dir" == "$wt_path/"* ]]; then
      suffix=" ← here"
    fi
    if [[ -n "$wt_branch" ]] && (( ${gone_branches[(Ie)$wt_branch]} )); then
      suffix=" (remote deleted)$suffix"
    fi
    echo "$line$suffix"
  done
}

_gw_config() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not in a git repository"
    return 1
  }

  local main_worktree=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  local worktree_parent=$(dirname "$main_worktree")
  local config_file="$worktree_parent/.gwconfig"

  if [[ ! -f "$config_file" ]]; then
    cat > "$config_file" <<'TEMPLATE'
# gw config
# Applied automatically when creating new worktrees.

# Files to copy from main worktree to new worktrees
GW_COPY_FILES=(
  # ".env"
  # ".env.local"
)

# Commands to run after creating a worktree
GW_POST_COMMANDS=(
  # "pnpm install"
  # "pnpm build"
)
TEMPLATE
    echo "Created: $config_file"
  fi

  ${EDITOR:-vi} "$config_file"
}

_gw_init() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not in a git repository"
    return 1
  }

  local main_worktree=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  local worktree_parent=$(dirname "$main_worktree")

  if [[ -f "$worktree_parent/.gwconfig" ]]; then
    echo "Already initialized. Config: $worktree_parent/.gwconfig"
    return 0
  fi

  if [[ "$git_root" != "$main_worktree" ]]; then
    echo "Error: Must run from the main worktree"
    return 1
  fi

  local worktree_count=$(git worktree list | wc -l | tr -d ' ')
  if (( worktree_count > 1 )); then
    echo "Error: Linked worktrees exist. Remove them first with 'gw d <branch>'"
    return 1
  fi

  local branch_name=$(git rev-parse --abbrev-ref HEAD)

  if [[ "$branch_name" != "main" && "$branch_name" != "master" ]]; then
    echo "Error: gw init must be run on 'main' or 'master' branch. (current: $branch_name)"
    return 1
  fi

  local project_dir="$git_root"
  local parent_dir=$(dirname "$project_dir")

  echo "gw init: Restructuring for git worktree workflow"
  echo ""
  echo "  Before:  $(basename "$project_dir")/"
  echo "             ├── .git/"
  echo "             └── (your files)"
  echo ""
  echo "  After:   $(basename "$project_dir")/"
  echo "             ├── $branch_name/    ← main worktree"
  echo "             └── .gwconfig"
  echo ""
  echo -n "Continue? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "Cancelled."
    return 0
  fi

  cd "$parent_dir" || return 1

  local temp_name=".gw_init_temp_$$"
  mv "$project_dir" "$parent_dir/$temp_name" || {
    echo "Error: Failed to move project directory"
    return 1
  }

  mkdir -p "$project_dir" || {
    mv "$parent_dir/$temp_name" "$project_dir"
    echo "Error: Failed to create directory"
    return 1
  }

  mv "$parent_dir/$temp_name" "$project_dir/$branch_name" || {
    rmdir "$project_dir" 2>/dev/null
    mv "$parent_dir/$temp_name" "$project_dir"
    echo "Error: Failed to restructure"
    return 1
  }

  cat > "$project_dir/.gwconfig" <<'TEMPLATE'
# gw config
# Applied automatically when creating new worktrees.

# Files to copy from main worktree to new worktrees
GW_COPY_FILES=(
  # ".env"
  # ".env.local"
)

# Commands to run after creating a worktree
GW_POST_COMMANDS=(
  # "pnpm install"
  # "pnpm build"
)
TEMPLATE

  cd "$project_dir/$branch_name" || return 1

  echo ""
  echo "Done! Restructured:"
  echo "  $(basename "$project_dir")/"
  echo "  ├── $branch_name/    ← you are here"
  echo "  └── .gwconfig"
  echo ""
  echo "Run 'gw c' to customize your config."
}

_gw_prune() {
  local dry_run=false
  if [[ "$1" == "-n" || "$1" == "--dry-run" ]]; then
    dry_run=true
  fi

  local git_bin=$(command -v git)

  local git_root
  git_root=$($git_bin rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not in a git repository"
    return 1
  }

  local main_worktree=$($git_bin worktree list --porcelain | head -1 | sed 's/^worktree //')
  local worktree_parent=$(dirname "$main_worktree")
  local current_dir=$(pwd)

  echo "Fetching..."
  $git_bin fetch --prune origin 2>/dev/null

  local -a gone_branches
  gone_branches=(${(f)"$(LC_ALL=C $git_bin branch -vv 2>/dev/null | awk '/: gone\]/{sub(/^[ *+]+/, ""); print $1}')"})

  local -a pruneable_paths=()
  local -a pruneable_names=()
  local -a pruneable_reasons=()
  local needs_cd=false

  local is_main=true
  local wt_path="" wt_branch=""

  while IFS= read -r line || [[ -n "$wt_path" ]]; do
    if [[ -z "$line" ]]; then
      if [[ -n "$wt_path" && "$is_main" == false ]]; then
        local display_name="${wt_branch:-${wt_path#$worktree_parent/}}"

        if [[ ! -d "$wt_path" ]]; then
          pruneable_paths+=("$wt_path")
          pruneable_names+=("$display_name")
          pruneable_reasons+=("directory missing")
        elif [[ -n "$wt_branch" ]] && (( ${gone_branches[(Ie)$wt_branch]} )); then
          pruneable_paths+=("$wt_path")
          pruneable_names+=("$display_name")
          pruneable_reasons+=("remote branch deleted")
          if [[ "$current_dir" == "$wt_path"* ]]; then
            needs_cd=true
          fi
        fi
      fi
      wt_path=""
      wt_branch=""
      is_main=false
      continue
    fi

    if [[ "$line" == "worktree "* ]]; then
      wt_path="${line#worktree }"
    elif [[ "$line" == "branch refs/heads/"* ]]; then
      wt_branch="${line#branch refs/heads/}"
    fi
  done < <($git_bin worktree list --porcelain; echo "")

  if (( ${#pruneable_paths[@]} == 0 )); then
    echo "No worktrees to prune."
    return 0
  fi

  echo "Pruneable:"
  echo ""
  for i in {1..${#pruneable_paths[@]}}; do
    echo "  ${pruneable_names[$i]}  (${pruneable_reasons[$i]})"
  done
  echo ""

  if $dry_run; then
    return 0
  fi

  echo -n "Remove all? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "Cancelled."
    return 0
  fi

  echo ""

  if $needs_cd; then
    cd "$main_worktree"
  fi

  $git_bin worktree prune

  local -a removed_branches=()

  for i in {1..${#pruneable_paths[@]}}; do
    local wt="${pruneable_paths[$i]}"
    local name="${pruneable_names[$i]}"
    if [[ -d "$wt" ]]; then
      echo "Removing: $name"
      if ! $git_bin worktree remove "$wt" 2>/dev/null; then
        echo "  Force removing: $name (uncommitted changes)"
        $git_bin worktree remove --force "$wt" || {
          echo "  Warning: failed to remove $name"
          continue
        }
      fi
    else
      echo "Cleaned: $name"
    fi
    removed_branches+=("$name")
  done

  for branch in "${removed_branches[@]}"; do
    if $git_bin show-ref --verify --quiet "refs/heads/$branch"; then
      $git_bin branch -D "$branch" 2>/dev/null && echo "Branch deleted: $branch"
    fi
  done

  echo ""
  echo "Done! $(pwd)"
}

_gw_delete() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    echo "Usage: gw d <branch-name>"
    return 1
  fi

  local git_bin=$(command -v git)

  local git_root
  git_root=$($git_bin rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not in a git repository"
    return 1
  }

  local main_worktree=$($git_bin worktree list --porcelain | head -1 | sed 's/^worktree //')
  local worktree_parent=$(dirname "$main_worktree")
  local worktree_path="$worktree_parent/$branch"
  local actual_branch=""

  if [[ -d "$worktree_path" ]]; then
    # matched by path, look up the branch
    local wt_line=""
    local found=false
    while IFS= read -r line; do
      if [[ "$line" == "worktree $worktree_path" ]]; then
        found=true
      elif $found; then
        if [[ "$line" == "branch refs/heads/"* ]]; then
          actual_branch="${line#branch refs/heads/}"
          break
        elif [[ -z "$line" ]]; then
          break
        fi
      fi
    done < <($git_bin worktree list --porcelain)
  else
    # not found by path, search by branch name
    local wt_path="" wt_branch=""
    while IFS= read -r line; do
      if [[ "$line" == "worktree "* ]]; then
        wt_path="${line#worktree }"
      elif [[ "$line" == "branch refs/heads/"* ]]; then
        wt_branch="${line#branch refs/heads/}"
      elif [[ -z "$line" ]]; then
        if [[ "$wt_branch" == "$branch" && "$wt_path" != "$main_worktree" ]]; then
          worktree_path="$wt_path"
          actual_branch="$wt_branch"
          break
        fi
        wt_path=""
        wt_branch=""
      fi
    done < <($git_bin worktree list --porcelain; echo "")

    if [[ ! -d "$worktree_path" ]]; then
      echo "Error: Worktree not found for: $branch"
      return 1
    fi
  fi

  if [[ "$(pwd)" == "$worktree_path"* ]]; then
    cd "$main_worktree"
  fi

  echo "Removing worktree: $worktree_path"
  if ! $git_bin worktree remove "$worktree_path" 2>/dev/null; then
    echo "  Force removing (uncommitted changes)"
    $git_bin worktree remove --force "$worktree_path" || {
      echo "  Error: Failed to remove worktree"
      return 1
    }
  fi

  local del_branch="${actual_branch:-$branch}"
  if $git_bin show-ref --verify --quiet "refs/heads/$del_branch"; then
    $git_bin branch -D "$del_branch" 2>/dev/null && echo "Branch deleted: $del_branch"
  fi

  echo "Done! $(pwd)"
}

# --- Zsh completion ---

_gw() {
  if [[ "${words[2]}" == "-b" ]]; then
    case $CURRENT in
      3) _gw_git_branches ;;
      4) _gw_git_branches ;;
    esac
    return
  fi

  _arguments -s \
    '1:command or branch:_gw_first_arg' \
    '2:branch or base:_gw_second_arg'
}

_gw_first_arg() {
  local -a subcmds
  subcmds=(
    'd:remove worktree'
    'delete:remove worktree'
    'l:list worktrees'
    'list:list worktrees'
    'c:open/create .gwconfig'
    'config:open/create .gwconfig'
    'i:initialize gw structure'
    'init:initialize gw structure'
    'p:clean up stale worktrees'
    'prune:clean up stale worktrees'
    'h:show help'
    'help:show help'
  )
  _describe 'command' subcmds
  _gw_git_branches
}

_gw_second_arg() {
  local cmd="${words[2]}"
  case "$cmd" in
    d|delete)
      _gw_worktree_branches
      ;;
    *)
      _gw_git_branches
      ;;
  esac
}

_gw_resolve_git_c() {
  _gw_git_c_args=()
  if ! git rev-parse --show-toplevel &>/dev/null && [[ -f ".gwconfig" ]]; then
    local d
    for d in */; do
      if [[ -d "${d}.git" ]]; then
        _gw_git_c_args=(-C "${PWD}/${d%/}")
        return 0
      fi
    done
    return 1
  fi
  return 0
}

_gw_git_branches() {
  _gw_resolve_git_c || return
  local -a branches
  branches=(${(f)"$(git ${_gw_git_c_args[@]} branch --all --format='%(refname:short)' 2>/dev/null | grep -v '^origin$' | sed 's|^origin/||' | sort -u)"})
  _describe 'branch' branches
}

_gw_worktree_branches() {
  _gw_resolve_git_c || return
  local -a branches
  branches=(${(f)"$(git ${_gw_git_c_args[@]} worktree list --porcelain 2>/dev/null | awk '/^branch refs\/heads\//{sub("^branch refs/heads/", ""); print}')"})
  _describe 'worktree branch' branches
}

compdef _gw gw
