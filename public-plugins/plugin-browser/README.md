# plugin-browser

plugin-search-install 의 조회 결과를 터미널에서 보고 골라 설치하는 CLI 화면 — 폭에 따라 표 · 축약 표 · 카드 · 목록, 한글 · 이모지 · 모호 폭 처리, 화살표 · 스페이스 선택과 번호 입력, 메뉴, 범위 확인.

```
검색 테스트 커버리지  3개
──────────────────────────────────────────────────────────────────────────────
#   이름                         마켓                  설명
1   java-spring-aitest-coverage  plugin-marketplace    Java · Spring Boot(Gr⋯
2 ✓ project-completeness         plugin-marketplace    프로젝트가 서비스로서 ⋯

❯ [x]   java-spring-aitest-coverage  Java · Spring Boot(Gradle) 프로젝트에서 ⋯
  [ ] ✓ project-completeness         프로젝트가 서비스로서 갖출 것을 갖췄는지 재⋯
↑↓ 이동 · Space 선택 · a 전부 · n 해제 · i 반전 · Enter 설치 · q 취소
```

조회 · 설치는 [`plugin-search-install`](../plugin-search-install/README.md) 이 한다. 이 플러그인은 그 결과(JSON)를 그리고 고르게 할 뿐이다.

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install plugin-browser@plugin-marketplace --scope user
```

`plugin-search-install` 은 의존성으로 같이 설치된다. 필요한 것: `bash` (3.2 이상), `jq` (1.6 이상), `stty`.

터미널에서 바로 쓰려면 별칭을 둔다 (경로는 `claude plugin list --json` 의 `installPath`).

```bash
alias plugins='bash <installPath>/scripts/plugin-browser.sh'
```

## 의존성

| 플러그인 | 이유 |
|---|---|
| plugin-search-install | 카탈로그 · 검색 · 연관 · 프로젝트 · 설치 엔진 |

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| plugin-browser | 터미널에서 고를래 · 표로 보여줘 · 플러그인 브라우저 | Claude 안에서는 폭 고정 렌더를 코드 블록으로, 대화형은 사용자 터미널 명령을 준다 |

## 주의

- **대화형 선택은 진짜 터미널에서만** 열린다 (stdin · stdout 이 TTY). Claude 의 Bash · 파이프 · CI 에서는 정적 화면과 `--select` 안내만 나온다
- 모호 폭 글자(`·` `─` `…`)를 두 칸으로 그리는 터미널(동아시아 폭 설정)은 시작할 때 커서 위치를 물어 판별한다. 응답하지 않는 터미널이면 1초 기다린 뒤 한 칸으로 본다 — `PLUGIN_BROWSER_AMBIGUOUS=1|2` 로 고정
- 창 크기 변경은 1초 안에 다시 그린다 (`SIGWINCH` 대신 주기 확인 — bash 3.2 의 `read` 는 신호로 깨지 않는다)
- 이모지 폭은 Unicode 15.1 기준이다. 오래된 터미널 · 글꼴은 일부 이모지를 한 칸으로 그려 줄이 짧아질 수 있다 (넘치지는 않는다)
- 설치는 기본 `project` 범위다. 선택 화면 뒤 범위를 묻는다

## 사용

```bash
P=scripts/plugin-browser.sh
$P                                   # 메뉴
$P project                           # 이 프로젝트에 필요한 것
$P search naming has:hook -java      # 질의 문법은 plugin-search-install 과 같다
$P related plugin-naming --by name
$P installed
$P show github-workflow
$P facets tag
$P search 커버리지 --width 60 --no-pick           # 그리기만, 폭 고정
$P search 커버리지 --select 1,3 --scope user --dry-run   # 묻지 않고 설치 계획
plugin-search-install.sh search x | $P render -   # 엔진 JSON 을 그리기만
```

| 옵션 | 뜻 |
|---|---|
| `--width N` | 폭 고정 (기본: 터미널 → `$COLUMNS` → 80) |
| `--ascii` | 장식을 ASCII 로 (UTF-8 아닌 로케일은 자동) |
| `--color auto\|always\|never` | 기본 auto — TTY 이고 `NO_COLOR` 가 없을 때 |
| `--plain` | 화살표 선택 대신 번호 입력 |
| `--no-pick` | 그리기만 |
| `--select` · `--install-all` · `--scope` · `--dry-run` | 묻지 않고 설치 |

## 폭별 레이아웃

| 폭 | 레이아웃 |
|---|---|
| 120 이상 | 표 — # · 표시 · 이름 · 마켓 · 태그 · 이유 · 설명 |
| 100 ~ 119 | 표 — # · 표시 · 이름 · 마켓 · 설명 |
| 70 ~ 99 | 한 줄 — # · 표시 · 이름 · 설명 |
| 40 ~ 69 | 카드 — 이름 / 마켓 · 태그 / 설명 2줄 / 이유 |
| 40 미만 | 목록 — 이름 / 설명 1줄 (24 이상) |

표시: `✓` 설치됨 · `!` 필수인데 없음 · `-` 꺼짐 (ASCII 는 `*` `!` `-`). 모든 줄은 폭 − 1 칸 안에 들어간다 (마지막 열에 쓰면 자동 줄바꿈하는 터미널).

## 파일

| 경로 | 역할 |
|---|---|
| `scripts/plugin-browser.sh` | 메뉴 · 렌더 · 대화형 선택 · 설치 확인 |
| `references/display-width.json` | 표시 폭 표 — 0칸 · 2칸 · 모호 폭 범위 (Unicode 15.1, 한글 음절은 스크립트의 빠른 경로) |
| `test/` | 회귀 테스트와 TC 명세 — 폭 16가지 · pty 조작 |
| `evals/` | `claude plugin eval` 케이스 — 스킬 발동(`browser-request`) |

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
