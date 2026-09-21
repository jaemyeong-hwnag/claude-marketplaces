---
name: pull-request-create
description: 작업을 마치고 PR 을 올릴 때 사용한다. 검증·테스트를 돌리고 기본 브랜치 위로 리베이스한 뒤 다시 돌리고 타입별 템플릿과 라벨로 PR 을 열 때 적용한다. 트리거 — "PR 올려", "PR 만들어", "리베이스", "검증 돌려", "작업 끝". 리베이스 뒤 재검증과 템플릿·라벨을 강제한다.
---

# 검증 · 테스트 → 리베이스 → PR

규칙 원본: [`references/workflow-rules.md`](../../references/workflow-rules.md) — 4 ~ 6 단계

## 4. 검증과 테스트

프로젝트가 정한 명령을 **전부** 돌린다. 어디서 찾나:

1. 프로젝트 `CLAUDE.md` 의 검증 · 테스트 절
2. 프로젝트가 켠 다른 플러그인의 스킬 (PR 전에 할 일 — 버전 올림 같은 — 이 있으면 여기서 한다)
3. 없으면 빌드 파일(`package.json` scripts · `build.gradle` · `Makefile` …)에서 찾고, 그래도 모르면 사용자에게 묻는다

**전부 통과해야 다음으로 간다.** 출력은 PR 본문 "어떻게 확인했나" 에 붙인다.

## 5. 리베이스 — 그다음 4 를 다시

```bash
git fetch origin
git rebase origin/main          # 기본 브랜치가 main 이 아니면 그 이름
# 4 단계 명령을 다시
git push --force-with-lease -u origin HEAD
```

- 리베이스 전에 돌린 결과는 다른 코드의 결과다. **다시 돌린 결과를 PR 에 붙인다**
- 강제 푸시는 `--force-with-lease` 만 (`W-08`)

## 6. PR 을 연다

`.github/PULL_REQUEST_TEMPLATE/{타입}.md` 를 채운 파일을 본문으로 준다. 에이전트는 편집기를 못 쓰므로 `--template` 대신 `--body-file` 을 쓴다.

```bash
gh pr create --base main --title "feat(order): 주문 동기화" --label feature --body-file /tmp/pr.md
```

| 채울 것 | 어떻게 |
|---|---|
| 이슈 | feature `Closes #N` · bugfix `Fixes #N` — 머지되면 이슈가 닫힌다 |
| 어떻게 확인했나 | 5 단계에서 다시 돌린 출력 그대로. 비우지 않는다 |
| 호환성 | 전에 되던 것이 여전히 되는가. 아니면 무엇이 바뀌는지 |
| 재발 방지 · 영향 범위 (bugfix) | 수정 전 실패 · 수정 후 통과하는 테스트, 같은 패턴을 다른 곳에서 찾아본 명령과 결과 |

제목은 커밋 형식 `feat({scope}): …` / `fix({scope}): …`. 훅이 템플릿 · 라벨 누락과 리베이스 누락을 막는다 (`W-05` · `W-06`).

PR 을 여는 것은 원격에 남는다. 처음이거나 범위가 크면 **사용자에게 먼저 보여준다**.
