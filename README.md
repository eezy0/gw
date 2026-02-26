# gw

Git worktree를 간편하게 관리하는 zsh 플러그인.

```
gw task/1234       # 워크트리 생성 후 이동
gw task/1234       # 이미 있으면 이동만
gw -d task/1234    # 워크트리 제거
gw -l              # 워크트리 목록
gw -c              # .gwconfig 편집 (없으면 생성)
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
- 브랜치 없음 → 현재 브랜치 기반으로 새 브랜치 생성

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

## 탭 자동완성

- `gw <Tab>` — 브랜치 이름 자동완성 (로컬 + 리모트)
- `gw -d <Tab>` — 기존 워크트리 브랜치 자동완성

## 프로젝트 설정 (.gwconfig)

워크트리 부모 디렉토리에 `.gwconfig` 파일을 두면, 워크트리 생성 시 파일 복사와 명령어 실행을 자동으로 수행합니다.

`gw -c`로 설정 파일을 열거나 새로 만들 수 있습니다.

```sh
# ~/projects/.gwconfig

# 메인 워크트리에서 새 워크트리로 복사할 파일
GW_COPY_FILES=(.env .env.local)

# 워크트리 생성 후 실행할 명령어
GW_POST_COMMANDS=("pnpm install")
```

## License

MIT
