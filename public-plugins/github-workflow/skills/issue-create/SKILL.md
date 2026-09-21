---
name: issue-create
description: 작업을 시작할 때 사용한다. 새 기능을 만들거나 버그를 고치기 전에 GitHub 이슈를 발행하고 이슈 번호로 브랜치와 워크트리를 만들 때 적용한다. 트리거 — "이슈 만들어", "작업 시작", "브랜치 만들어", "워크트리", "버그 등록". feature · bugfix 두 타입과 브랜치 이름 규칙을 강제한다.
---

# 이슈 발행 → 브랜치 · 워크트리

규칙 원본: [`references/workflow-rules.md`](../../references/workflow-rules.md) — 1 · 2 단계

## 1. 타입을 정한다

| 타입 | 언제 |
|---|---|
| `feature` | 기능 · 동작을 **추가하거나 바꾼다**. 기존 동작을 바꾸는 것도 여기 |
| `bugfix` | 코드가 **의도와 다르게** 동작한다 — 잘못된 결과, 오류, 누락 |

애매하면 "전에 되던 것이 이제 다르게 되는가" 를 본다. 그렇다면 feature 다.

## 2. 이슈를 발행한다

본문은 이슈 폼(`.github/ISSUE_TEMPLATE/{타입}.yml`)의 **`label` 을 `###` 제목으로** 채운다. CLI 는 폼을 그리지 못하므로 같은 구조의 본문을 직접 넘긴다.

```bash
grep -E '^\s+label:' .github/ISSUE_TEMPLATE/feature.yml     # 채울 절
gh issue create --title "[feature] 주문 동기화" --label feature --body-file /tmp/issue.md
```

- 저장소에 없는 로컬 문서(git 미추적)는 링크하지 말고 요점을 붙인다
- bugfix 의 "최소 재현" 은 그대로 테스트가 된다. 명령 한 줄이나 입력 예로 쓴다
- 템플릿이나 라벨 `feature` · `bugfix` 가 없으면 `github-template-create` 부터 한다
- **이슈는 원격에 남는다.** 처음이면 사용자에게 먼저 보여준다

## 3. 브랜치와 워크트리를 만든다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/branch-create.sh" feature 12 order-sync
```

- `origin/main`(기본 브랜치)을 받아와 거기서 `feature/12-order-sync` 를 만들고 `.claude/worktrees/12-order-sync` 에 워크트리를 둔다
- slug 는 영문 kebab-case 1 ~ 5 단어. 이슈 제목을 줄인 것이다 (`W-03`)
- 이후 작업은 워크트리에서 한다

## 하지 않을 것

- 이슈 없이 브랜치를 만들지 않는다 (처음 도입하는 PR 하나만 예외 — 규칙 원본 5절)
- `develop` 같은 장기 브랜치를 만들지 않는다
- 라벨 생성 · 이슈 발행을 사용자 확인 없이 처음 하지 않는다 — 원격에 남는다
