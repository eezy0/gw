# gw - Git Worktree helper
# https://github.com/eezy0/gw
#
# Usage:
#   gw -i               프로젝트를 gw 구조로 초기화
#   gw <branch> [base]  워크트리 생성 후 이동
#   gw -d <branch-name> 워크트리 제거
#   gw prune [--dry-run] pruneable 워크트리 정리
#   gw -l               워크트리 목록
#   gw -c               .gwconfig 열기/생성

gw() {
  # If not in a git repo but .gwconfig exists, cd to main worktree
  if ! git rev-parse --show-toplevel &>/dev/null && [[ -f ".gwconfig" ]]; then
    local gw_main
    for d in */; do
      if [[ -d "${d}.git" ]]; then
        gw_main="${d%/}"
        break
      fi
    done
    if [[ -z "$gw_main" ]]; then
      echo "Error: .gwconfig는 있지만 main 워크트리를 찾을 수 없습니다"
      return 1
    fi
    cd "$gw_main"
  fi

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
    -i|--init)
      _gw_init
      return $?
      ;;
    prune)
      _gw_prune "$2"
      return $?
      ;;
    -h|--help|"")
      _gw_usage
      return 0
      ;;
  esac

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

  # Worktree already exists → just cd
  if [[ -d "$worktree_path" ]]; then
    [[ -n "$base" ]] && echo "Warning: base branch '$base' ignored (worktree already exists)"
    echo "Worktree already exists, moving to: $worktree_path"
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
    git worktree add -b "$branch" "$worktree_path" "$base_branch" || return 1
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
  gw -i              프로젝트를 gw 구조로 초기화
  gw <branch> [base] 워크트리 생성 후 이동 (이미 있으면 이동만)
  gw -d <branch>     워크트리 제거
  gw prune           리모트에서 삭제된 브랜치의 워크트리 정리
  gw prune --dry-run 정리 대상만 확인
  gw -l              워크트리 목록
  gw -c              .gwconfig 열기/생성
  gw -h              도움말

Examples:
  gw -i              현재 프로젝트를 project/main/ 구조로 변환
  gw task/1234       task/1234 브랜치로 워크트리 생성 (현재 브랜치 기반)
  gw task/1234 develop  develop 기반으로 워크트리 생성
  gw task/1234       이미 있으면 해당 워크트리로 이동
  gw -d task/1234    task/1234 워크트리 제거
  gw prune           리모트에서 삭제된 브랜치의 워크트리 한번에 정리
  gw prune --dry-run 정리 대상 목록만 확인
  gw -c              .gwconfig 편집 (없으면 템플릿 생성)

Init (gw -i):
  일반 git 프로젝트를 gw 워크트리 구조로 변환합니다.

    Before:  my-app/          ← git root
    After:   my-app/main/     ← main worktree
             my-app/.gwconfig

Branch 처리:
  - 로컬 브랜치 있음     → 해당 브랜치로 워크트리 생성
  - 리모트 브랜치만 있음 → 리모트 tracking 브랜치로 생성
  - 브랜치 없음          → 현재 브랜치 기반 새 브랜치 생성 (base 지정 시 해당 브랜치 기반)

Config (.gwconfig):
  워크트리 부모 디렉토리에 .gwconfig 파일을 두면
  워크트리 생성 시 파일 복사 및 명령어를 자동 실행합니다.

  예시:
    GW_COPY_FILES=(".env" ".env.local")
    GW_POST_COMMANDS=("pnpm install" "pnpm build")
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
  # ".env"
  # ".env.local"
)

# 워크트리 생성 후 실행할 명령어
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

  # Already in gw structure? (parent has .gwconfig or main worktree is a subdirectory)
  if [[ -f "$worktree_parent/.gwconfig" ]]; then
    echo "Already initialized. Config: $worktree_parent/.gwconfig"
    return 0
  fi

  # Must run from the main worktree
  if [[ "$git_root" != "$main_worktree" ]]; then
    echo "Error: Must run from the main worktree"
    return 1
  fi

  # Must not have linked worktrees
  local worktree_count=$(git worktree list | wc -l | tr -d ' ')
  if (( worktree_count > 1 )); then
    echo "Error: Linked worktrees exist. Remove them first with 'gw -d <branch>'"
    return 1
  fi

  local branch_name=$(git rev-parse --abbrev-ref HEAD)

  if [[ "$branch_name" != "main" && "$branch_name" != "master" ]]; then
    echo "Error: gw -i must be run on 'main' or 'master' branch. (current: $branch_name)"
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

  # Step 1: Move to parent to manipulate the project directory
  cd "$parent_dir" || return 1

  # Step 2: Rename to temp
  local temp_name=".gw_init_temp_$$"
  mv "$project_dir" "$parent_dir/$temp_name" || {
    echo "Error: Failed to move project directory"
    return 1
  }

  # Step 3: Recreate project directory as the new parent
  mkdir -p "$project_dir" || {
    mv "$parent_dir/$temp_name" "$project_dir"
    echo "Error: Failed to create directory"
    return 1
  }

  # Step 4: Move repo into branch-named subdirectory
  mv "$parent_dir/$temp_name" "$project_dir/$branch_name" || {
    rmdir "$project_dir" 2>/dev/null
    mv "$parent_dir/$temp_name" "$project_dir"
    echo "Error: Failed to restructure"
    return 1
  }

  # Step 5: Create .gwconfig
  cat > "$project_dir/.gwconfig" <<'TEMPLATE'
# gw config
# 워크트리 생성 시 자동으로 적용됩니다.

# 메인 워크트리에서 새 워크트리로 복사할 파일
GW_COPY_FILES=(
  # ".env"
  # ".env.local"
)

# 워크트리 생성 후 실행할 명령어
GW_POST_COMMANDS=(
  # "pnpm install"
  # "pnpm build"
)
TEMPLATE

  # Step 6: cd to main worktree
  cd "$project_dir/$branch_name" || return 1

  echo ""
  echo "Done! Restructured:"
  echo "  $(basename "$project_dir")/"
  echo "  ├── $branch_name/    ← you are here"
  echo "  └── .gwconfig"
  echo ""
  echo "Run 'gw -c' to customize your config."
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

  # Fetch and prune remote tracking refs
  echo "Fetching..."
  $git_bin fetch --prune origin 2>/dev/null

  # Get gone branches (remote deleted)
  local -a gone_branches
  gone_branches=(${(f)"$(LC_ALL=C $git_bin branch -vv 2>/dev/null | awk '/: gone\]/{sub(/^[ *+]+/, ""); print $1}')"})

  local -a pruneable_paths=()
  local -a pruneable_names=()
  local -a pruneable_reasons=()
  local needs_cd=false

  # Parse worktree list (porcelain), skip main worktree
  local is_main=true
  local wt_path="" wt_branch=""

  while IFS= read -r line || [[ -n "$wt_path" ]]; do
    if [[ -z "$line" ]]; then
      if [[ -n "$wt_path" && "$is_main" == false ]]; then
        local display_name="${wt_branch:-${wt_path#$worktree_parent/}}"

        if [[ ! -d "$wt_path" ]]; then
          pruneable_paths+=("$wt_path")
          pruneable_names+=("$display_name")
          pruneable_reasons+=("디렉토리 없음")
        elif [[ -n "$wt_branch" ]] && (( ${gone_branches[(Ie)$wt_branch]} )); then
          pruneable_paths+=("$wt_path")
          pruneable_names+=("$display_name")
          pruneable_reasons+=("리모트 브랜치 삭제됨")
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
    echo "정리할 워크트리가 없습니다."
    return 0
  fi

  echo "정리 대상:"
  echo ""
  for i in {1..${#pruneable_paths[@]}}; do
    echo "  ${pruneable_names[$i]}  (${pruneable_reasons[$i]})"
  done
  echo ""

  if $dry_run; then
    return 0
  fi

  echo -n "모두 제거할까요? [y/N] "
  read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "취소됨."
    return 0
  fi

  echo ""

  # If current dir is being removed, cd to main first
  if $needs_cd; then
    cd "$main_worktree"
  fi

  # Clean stale entries first (broken worktrees with missing directories)
  $git_bin worktree prune

  local -a removed_branches=()

  for i in {1..${#pruneable_paths[@]}}; do
    local path="${pruneable_paths[$i]}"
    local name="${pruneable_names[$i]}"
    if [[ -d "$path" ]]; then
      echo "제거 중: $name"
      if ! $git_bin worktree remove "$path" 2>/dev/null; then
        echo "  강제 제거 중: $name (uncommitted changes)"
        $git_bin worktree remove --force "$path" || {
          echo "  Warning: $name 제거 실패"
          continue
        }
      fi
    else
      echo "정리됨: $name"
    fi
    removed_branches+=("$name")
  done

  # Clean up local branches
  for branch in "${removed_branches[@]}"; do
    if $git_bin show-ref --verify --quiet "refs/heads/$branch"; then
      $git_bin branch -D "$branch" 2>/dev/null && echo "브랜치 삭제: $branch"
    fi
  done

  echo ""
  echo "Done! $(pwd)"
}

_gw_delete() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    echo "Usage: gw -d <branch-name>"
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

  if [[ ! -d "$worktree_path" ]]; then
    echo "Error: Worktree not found: $worktree_path"
    return 1
  fi

  # Auto-cd to main if currently in the target worktree
  if [[ "$(pwd)" == "$worktree_path"* ]]; then
    cd "$main_worktree"
  fi

  echo "Removing worktree: $worktree_path"
  if ! $git_bin worktree remove "$worktree_path" 2>/dev/null; then
    echo "  강제 제거 중 (uncommitted changes)"
    $git_bin worktree remove --force "$worktree_path" || {
      echo "  Error: 워크트리 제거 실패"
      return 1
    }
  fi

  # Clean up local branch
  if $git_bin show-ref --verify --quiet "refs/heads/$branch"; then
    $git_bin branch -D "$branch" 2>/dev/null && echo "브랜치 삭제: $branch"
  fi

  echo "Done! $(pwd)"
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
    '-i[gw 구조로 초기화]'
    '--init[gw 구조로 초기화]'
    '-h[도움말]'
    '--help[도움말]'
  )

  local -a subcmds
  subcmds=(
    'prune:머지됨/깨진 워크트리 정리'
  )

  _arguments -s $opts '1:branch or command:_gw_first_arg' '2:base branch:_gw_git_branches'
}

_gw_first_arg() {
  _alternative \
    'subcommands:command:(prune)' \
    'branches:branch:_gw_git_branches'
}

_gw_git_branches() {
  local -a branches
  branches=(${(f)"$(git branch --all --format='%(refname:short)' 2>/dev/null | grep -v '^origin$' | sed 's|^origin/||' | sort -u)"})
  _describe 'branch' branches
}

_gw_worktree_branches() {
  local -a branches
  branches=(${(f)"$(git worktree list --porcelain 2>/dev/null | awk '/^branch refs\/heads\//{sub("^branch refs/heads/", ""); print}')"})
  _describe 'worktree branch' branches
}

compdef _gw gw
