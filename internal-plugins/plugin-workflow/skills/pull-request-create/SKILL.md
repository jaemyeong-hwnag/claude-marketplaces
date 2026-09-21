---
name: pull-request-create
description: 작업을 마치고 PR 을 올릴 때 사용한다. 버전을 올리고 검증·테스트를 돌리고 origin/main 위로 리베이스한 뒤 타입별 템플릿으로 PR 을 열 때 적용한다. 트리거 — "PR 올려", "PR 만들어", "리베이스", "검증 돌려", "작업 끝". 리베이스 뒤 재검증과 템플릿·라벨을 강제한다.
---

# 버전 → 검증 → 테스트 → 리베이스 → PR

규칙 원본: [`references/workflow-rules.md`](../../references/workflow-rules.md) — 4 ~ 8 단계

## 4. 버전을 올린다

이번 브랜치에서 파일이 바뀐 플러그인마다 올린다 (`V-14`).

```bash
git diff --name-only origin/main...HEAD | awk -F/ '/^(public|internal)-plugins\//{print $1"/"$2}' | sort -u
```

각각 `version-update` 스킬대로 — **CHANGELOG 먼저**, 그다음 `plugin.json`. 기본 등급은 이슈 타입에서 온다 (feature → MINOR, bugfix → PATCH). 판정이 바뀌면 MAJOR (`0.x` 면 MINOR).

## 5 · 6. 검증과 테스트

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-all.sh" "${CLAUDE_PROJECT_DIR:-.}"
```

정적 검증 전부 · `--since origin/main` · 회귀 테스트 전부 · `claude plugin validate --strict` 를 돌리고 한 줄씩 요약한다. **전부 ✅ 여야 다음으로 간다.** 출력은 PR 본문 "어떻게 확인했나" 에 그대로 붙인다.

## 7. 리베이스 — 그다음 5 · 6 을 다시

```bash
git fetch origin
git rebase origin/main
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-all.sh" "${CLAUDE_PROJECT_DIR:-.}"
git push --force-with-lease -u origin HEAD
```

- 리베이스 전에 돌린 결과는 다른 코드의 결과다. **다시 돌린 결과를 PR 에 붙인다**
- 강제 푸시는 `--force-with-lease` 만 (`W-08`)

## 8. PR 을 연다

`.github/PULL_REQUEST_TEMPLATE/{타입}.md` 를 채운 파일을 본문으로 준다. 에이전트는 편집기를 못 쓰므로 `--template` 대신 `--body-file` 을 쓴다.

```bash
gh pr create --base main --title "feat(plugin-dependency): 의존성 방향 검사" --label feature --body-file /tmp/pr.md
```

| 절 | 채우는 법 |
|---|---|
| 이슈 | feature `Closes #N` · bugfix `Fixes #N` |
| 변경한 플러그인과 버전 | 4 단계에서 올린 것 전부. 등급과 근거 |
| 호환성 | 전에 통과하던 것이 여전히 통과하는가. 아니면 무엇이 깨지는지 |
| 어떻게 확인했나 | 7 단계의 `verify-all.sh` 출력 그대로. 비우지 않는다 |
| 재발 방지 · 영향 범위 (bugfix) | 수정 전 실패·수정 후 통과하는 TC, 같은 패턴을 다른 곳에서 찾아본 명령과 결과 |
| AI 사용 | 예/아니오와 어디에 |

제목은 커밋 형식 `feat({scope}): …` / `fix({scope}): …`. 훅이 템플릿·라벨 누락과 리베이스 누락을 막는다 (`W-05` · `W-06`).

PR 을 여는 것은 원격에 남는다. 처음이거나 범위가 크면 **사용자에게 먼저 보여준다**.
