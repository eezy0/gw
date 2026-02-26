# gw - Git Worktree helper
# https://github.com/eezy0/gw
#
# Usage:
#   gw <branch-name>    워크트리 생성 후 이동
#   gw -d <branch-name> 워크트리 제거
#   gw -l               워크트리 목록
#   gw -c               .gwconfig 열기/생성

gw() {
  case "$1" in
    -d|--delete)
      _gw_delete "$2"
      return $?
      ;;
    -l|--list)
      git worktree list
      return $?
      ;;
    -c|--config)
      _gw_config
      return $?
      ;;
    -h|--help|"")
      _gw_usage
      return 0
      ;;
  esac

  local branch="$1"

  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not in a git repository"
    return 1
  }

  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local main_worktree=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  local worktree_parent=$(dirname "$main_worktree")
  local worktree_path="$worktree_parent/$branch"

  # Worktree already exists → just cd
  if [[ -d "$worktree_path" ]]; then
    echo "Worktree already exists, moving to: $worktree_path"
    cd "$worktree_path"
    return 0
  fi

  echo "Creating worktree: $worktree_path"
  echo "Branch: $branch (base: $current_branch)"
  echo ""

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "Using existing local branch: $branch"
    git worktree add "$worktree_path" "$branch" || return 1
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    echo "Using existing remote branch: origin/$branch"
    git worktree add -b "$branch" "$worktree_path" "origin/$branch" || return 1
  else
    echo "Creating new branch: $branch"
    git worktree add -b "$branch" "$worktree_path" "$current_branch" || return 1
  fi

  # Load project-specific config
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

  echo "Done! [$branch] $(pwd)"
}

_gw_usage() {
  cat <<'USAGE'
gw - Git Worktree helper

Usage:
  gw <branch>        워크트리 생성 후 이동 (이미 있으면 이동만)
  gw -d <branch>     워크트리 제거
  gw -l              워크트리 목록
  gw -c              .gwconfig 열기/생성
  gw -h              도움말

Examples:
  gw task/1234       task/1234 브랜치로 워크트리 생성 (현재 브랜치 기반)
  gw task/1234       이미 있으면 해당 워크트리로 이동
  gw -d task/1234    task/1234 워크트리 제거
  gw -c              .gwconfig 편집 (없으면 템플릿 생성)

Branch 처리:
  - 로컬 브랜치 있음     → 해당 브랜치로 워크트리 생성
  - 리모트 브랜치만 있음 → 리모트 tracking 브랜치로 생성
  - 브랜치 없음          → 현재 브랜치 기반 새 브랜치 생성

Config (.gwconfig):
  워크트리 부모 디렉토리에 .gwconfig 파일을 두면
  워크트리 생성 시 파일 복사 및 명령어를 자동 실행합니다.

  예시:
    GW_COPY_FILES=(.env .env.local)
    GW_POST_COMMANDS=("pnpm install")
USAGE
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
# 워크트리 생성 시 자동으로 적용됩니다.

# 메인 워크트리에서 새 워크트리로 복사할 파일
GW_COPY_FILES=(
  # .env
  # .env.local
)

# 워크트리 생성 후 실행할 명령어
GW_POST_COMMANDS=(
  # "pnpm install"
)
TEMPLATE
    echo "Created: $config_file"
  fi

  ${EDITOR:-vi} "$config_file"
}

_gw_delete() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    echo "Usage: gw -d <branch-name>"
    return 1
  fi

  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not in a git repository"
    return 1
  }

  local main_worktree=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  local worktree_parent=$(dirname "$main_worktree")
  local worktree_path="$worktree_parent/$branch"

  if [[ ! -d "$worktree_path" ]]; then
    echo "Error: Worktree not found: $worktree_path"
    return 1
  fi

  if [[ "$(pwd)" == "$worktree_path"* ]]; then
    echo "Error: Cannot delete current worktree. cd to another worktree first."
    return 1
  fi

  echo "Removing worktree: $worktree_path"
  git worktree remove "$worktree_path" && echo "Done!"
}

# --- Zsh completion ---

_gw() {
  local -a opts
  opts=(
    '-d[워크트리 제거]:branch:_gw_worktree_branches'
    '--delete[워크트리 제거]:branch:_gw_worktree_branches'
    '-l[워크트리 목록]'
    '--list[워크트리 목록]'
    '-c[.gwconfig 열기/생성]'
    '--config[.gwconfig 열기/생성]'
    '-h[도움말]'
    '--help[도움말]'
  )

  _arguments -s $opts '1:branch:_gw_git_branches'
}

_gw_git_branches() {
  local -a branches
  branches=(${(f)"$(git branch --all --format='%(refname:short)' 2>/dev/null | sed 's|^origin/||' | sort -u)"})
  _describe 'branch' branches
}

_gw_worktree_branches() {
  local -a branches
  branches=(${(f)"$(git worktree list --porcelain 2>/dev/null | awk '/^branch refs\/heads\//{sub("refs/heads/", ""); print}')"})
  _describe 'worktree branch' branches
}

compdef _gw gw
