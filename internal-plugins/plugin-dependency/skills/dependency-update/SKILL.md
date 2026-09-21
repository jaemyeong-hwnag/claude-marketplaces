---
name: dependency-update
description: 플러그인의 dependencies 를 추가·변경·삭제할 때 사용한다. common 플러그인을 만들거나 참조할 때, 번들(-standard)을 구성할 때, 플러그인을 지우기 전에 누가 기대는지 볼 때 적용한다. 트리거 — "의존성", "dependencies", "common 추가", "번들", "순환 의존". 층 방향과 마켓플레이스 경계를 강제한다.
---

# 의존성 고치기

규칙 원본: [`references/dependency-rules.md`](../../references/dependency-rules.md)
기계 검증: [`scripts/validate-dependency.sh`](../../scripts/validate-dependency.sh)

스크립트는 이름으로 알 수 있는 층(common · 번들)과 그래프(존재 · 순환 · 경계 · 범위 겹침)만 본다. **가운데 층의 방향과 common 의 자격은 이 스킬이 판단한다.**

## 1. 선언하기 전에

| 질문 | 답이 "예" 면 |
|---|---|
| 이 플러그인이 **직접** 쓰는가 | 선언한다. 전이 의존성은 Claude Code 가 설치하므로 선언하지 않는다 |
| 대상이 `internal-plugins/` 인데 나는 `public-plugins/` 인가 | 선언할 수 없다 (`D-08`). 대상을 public 으로 옮기거나 내용을 가져온다 |
| 대상이 다른 마켓플레이스인가 | 선언할 수 없다 (`D-07`) |
| 대상이 `0.x` 인가 | 문자열(`"common-naming"`)로 최신을 따라간다. `1.0.0` 이 되면 범위(`~1.0.0`)로 고정한다 |

## 2. 층 방향 — 판단

```
common  ←  언어/프레임워크별  ←  워크플로우  ←  번들
```

- 화살표를 **거스르는** 선언이 있으면 층이 잘못 잡힌 것이다. 워크플로우 플러그인이 언어별 규칙에 기대는 것은 되지만, 언어별 규칙이 워크플로우에 기대면 안 된다
- 가운데 두 층은 이름으로 구분되지 않는다. 플러그인이 **규칙을 담는가(언어별)**, **절차를 담는가(워크플로우)** 로 가른다
- 순환(`D-03`)을 끊을 때도 이 방향을 거스르는 간선을 끊는다

## 3. common 의 자격 — 판단

`common-*` 이름은 약속이다. 둘 다 참이어야 common 이다.

1. **멱등성** — 어떤 프로젝트에 설치해도 부작용이 없다. 훅이 파일을 쓰거나 설정을 바꾸면 common 이 아니다. 검사하고 막거나 알리기만 해야 한다. 필요한 도구가 없으면 조용히 넘어가야 한다 (`exit 0`)
2. **범위** — 판정 기준이 특정 언어·프레임워크에 묶이지 않는다. 예시로 여러 언어를 드는 것은 괜찮다

common 은 의존성이 없다 (`D-04`). 그리고 배포가 목적이므로 `public-plugins/` 에만 둔다 (배치 검사가 본다).

## 4. 번들

- 이름은 `{역할}-standard`
- `plugin.json` 에 `dependencies` 만 둔다. 스킬 · 커맨드 · 에이전트 · 훅을 넣지 않는다 (`D-06`)
- 다른 번들에 기대지 않는다 (`D-05`). 두 번들이 같은 것을 담으면 각자 선언한다 — Claude Code 가 한 번만 설치한다

## 5. 지우기 전에

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-dependency.sh" --dependents {이름} "${CLAUDE_PROJECT_DIR:-.}"
```

기대는 플러그인이 있으면 그쪽 `dependencies` 에서 먼저 빼고 **그쪽 버전을 올린다** — 쓰는 쪽이 할 일이 생기므로 MAJOR (`0.x` 면 MINOR).

## 6. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-dependency.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

종료 코드 0 이어야 끝난 것이다. `plugin.json` 을 저장하면 `PostToolUse` 훅이 같은 검사를 돌려 알려 준다.

## 하지 않을 것

- 범위 문자열의 형식을 여기서 판단하지 않는다 — `plugin-versioning` 의 `V-11`
- 순환을 없애려고 필요한 의존을 지우지 않는다. 층을 다시 나눈다
- `allowCrossMarketplaceDependenciesOn` 을 추가하지 않는다
