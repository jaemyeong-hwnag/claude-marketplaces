---
name: plugin-browser
description: 플러그인 조회 결과를 터미널 화면으로 보거나 화살표로 골라 설치하고 싶을 때 사용한다. 폭에 맞춘 표 · 카드로 그려 보이고, 대화형 선택은 사용자 터미널에서 실행할 명령을 준다. 트리거 — "터미널에서 고를래", "플러그인 브라우저", "표로 보여줘", "화살표로 선택", "plugin browser".
---

# 플러그인 브라우저

```bash
PB="${CLAUDE_PLUGIN_ROOT}/scripts/plugin-browser.sh"
```

조회 · 설치 로직은 `plugin-search-install` 이 갖는다. 이 스킬은 **화면**만 다룬다. 질의 문법은 `plugin-search` 스킬과 같다.

## 1. Claude 안에서 보여줄 때 — 그리기만

Claude 의 Bash 는 TTY 가 아니다. 대화형 선택은 열리지 않고 정적 화면만 나온다. 폭과 색을 고정해 코드 블록으로 보인다.

```bash
"$PB" search 테스트 커버리지 --width 100 --color never
"$PB" project . --width 100 --color never
"$PB" related plugin-naming --width 100 --color never
"$PB" show github-workflow --width 100 --color never
"$PB" facets tag --width 100 --color never
```

- 출력은 **그대로** 코드 블록에 넣는다. 표를 마크다운 표로 다시 만들지 않는다 — 폭 맞춤이 깨진다
- 번호는 `rank` 다. 설치는 `plugin-install` 스킬로 넘기거나 `"$PB" search … --select 1,3 --dry-run` 으로 계획을 보인다

## 2. 사용자가 직접 고르고 싶을 때 — 터미널 명령을 준다

경로를 절대 경로로 풀어서 준다.

```bash
echo "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-browser.sh"
```

```
<경로>                          # 메뉴 — 프로젝트 · 기능 검색 · 연관 · 태그 · 설치된 것
<경로> project                  # 이 프로젝트에 필요한 것 (필수 중 없는 것을 미리 골라 둔다)
<경로> search 테스트 커버리지
```

조작: ↑↓(j/k) 이동 · Space 선택 · a 전부 · n 해제 · i 반전 · Enter 설치 · q 취소 → 범위(Enter=project · u=user · l=local). 창이 작으면(행 < 8 · 열 < 24) 번호 입력으로 바뀐다. `--plain` 으로 처음부터 번호 입력.

화면이 깨져 보이면:

| 증상 | 해결 |
|---|---|
| `·` `─` 가 두 칸이라 줄이 넘친다 | `PLUGIN_BROWSER_AMBIGUOUS=2` (보통은 자동으로 판별) |
| 글자가 깨진다 | `--ascii` |
| 색이 거슬린다 | `NO_COLOR=1` 또는 `--color never` |

## 하지 않을 것

- Claude 의 Bash 에서 대화형 모드를 띄우려 하기 (`script` · `expect` 로 감싸기)
- 렌더 결과를 다시 정렬 · 재구성하기
- `--install-all` 을 사용자 확인 없이 붙이기
