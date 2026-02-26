# gw

Git worktree를 간편하게 관리하는 zsh 플러그인.

```
gw init            # 프로젝트를 gw 구조로 초기화 (gw i)
gw task/1234       # 워크트리 생성 후 이동 (현재 브랜치 기반)
gw task/1234 develop  # develop 기반으로 워크트리 생성
gw task/1234       # 이미 있으면 이동만
gw delete task/1234   # 워크트리 제거 (gw d)
gw prune           # 리모트에서 삭제된 브랜치의 워크트리 일괄 정리
gw list            # 워크트리 목록 (gw l) — 현재 위치 ← here 표시
gw config          # .gwconfig 편집 (gw c)
gw -b <branch>     # 서브커맨드와 이름 충돌 시 브랜치 강제 지정
```

## 동작 방식

`gw <branch>`를 실행하면 메인 워크트리의 **부모 디렉토리**에 워크트리를 생성하고 이동합니다.

```
~/projects/
├── my-app/          ← 메인 워크트리
├── task/1234/       ← gw task/1234
└── fix/login-bug/   ← gw fix/login-bug
```

브랜치 처리:
- 로컬 브랜치 있음 → 해당 브랜치 사용
- 리모트 브랜치만 있음 → tracking 브랜치 생성
- 브랜치 없음 → 현재 브랜치 기반으로 새 브랜치 생성 (base 지정 시 해당 브랜치 기반)

## 초기화 (gw init)

기존 git 프로젝트를 gw 워크트리 구조로 변환합니다.

```
# Before                    # After
~/projects/my-app/          ~/projects/my-app/
├── .git/                   ├── main/          ← main worktree
├── src/                    │   ├── .git/
└── ...                     │   ├── src/
                            │   └── ...
                            └── .gwconfig
```

```sh
cd ~/projects/my-app
gw init
# → my-app/main/ 으로 재구조화되고 .gwconfig 생성
```

## 설치

### Oh My Zsh

```sh
git clone https://github.com/eezy0/gw.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/gw
```

`~/.zshrc`의 plugins에 `gw` 추가:

```zsh
plugins=(... gw)
```

### 수동 설치

```sh
curl -fsSL https://raw.githubusercontent.com/eezy0/gw/main/gw.plugin.zsh -o ~/.zsh-functions/gw.zsh
```

`~/.zshrc`에 추가:

```zsh
source ~/.zsh-functions/gw.zsh
```

### 원라인 설치

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/eezy0/gw/main/install.sh)
```

Oh My Zsh가 있으면 커스텀 플러그인으로, 없으면 `~/.zsh-functions/`에 설치합니다.

## 정리 (gw prune)

GitHub에서 PR 머지 후 브랜치가 삭제되면, 해당 워크트리를 한번에 정리합니다.

```sh
gw prune
# Fetching...
# 정리 대상:
#   task/dto-geo-point  (리모트 브랜치 삭제됨)
#   task/old-feature    (리모트 브랜치 삭제됨)
#
# 모두 제거할까요? [y/N] y
#
# 제거 중: task/dto-geo-point
# 브랜치 삭제: task/dto-geo-point
# 제거 중: task/old-feature
# 브랜치 삭제: task/old-feature
#
# Done! /Users/you/projects/my-app/main
```

- 디렉토리가 수동 삭제된 깨진 워크트리도 함께 정리
- 현재 위치가 정리 대상이면 main으로 자동 이동
- `gw prune --dry-run`으로 정리 대상만 확인 가능

## 삭제 (gw delete)

```sh
gw d task/1234     # 워크트리 + 로컬 브랜치 삭제
```

- 현재 워크트리에서도 삭제 가능 (main으로 자동 이동)
- uncommitted changes가 있어도 강제 제거

## 탭 자동완성

- `gw <Tab>` — 서브커맨드 + 브랜치 이름 자동완성
- `gw d <Tab>` — 기존 워크트리 브랜치 자동완성

## 프로젝트 설정 (.gwconfig)

워크트리 부모 디렉토리에 `.gwconfig` 파일을 두면, 워크트리 생성 시 파일 복사와 명령어 실행을 자동으로 수행합니다.

`gw c`로 설정 파일을 열거나 새로 만들 수 있습니다.

```sh
# ~/projects/.gwconfig

# 메인 워크트리에서 새 워크트리로 복사할 파일
GW_COPY_FILES=(
  ".env"
  ".env.local"
)

# 워크트리 생성 후 실행할 명령어
GW_POST_COMMANDS=(
  "pnpm install"
  "pnpm build"
)
```

## License

MIT
