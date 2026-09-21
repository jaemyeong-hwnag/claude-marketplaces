---
description: 이슈·PR 템플릿과 현재 브랜치가 개발 플로우를 지키는지 검증한다
---

개발 플로우 상태를 확인한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --templates "${CLAUDE_PROJECT_DIR:-.}"
git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --branch "$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD)"
git -C "${CLAUDE_PROJECT_DIR:-.}" fetch -q origin main && "${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --up-to-date "${CLAUDE_PROJECT_DIR:-.}"
```

결과를 이렇게 정리해 보고한다.

- 템플릿(`W-01` · `W-02`) — 통과/위반
- 현재 브랜치 — 이름이 `W-03` 을 지키는가. `main` 이면 "작업 브랜치가 아니다"
- 최신 여부(`W-06`) — `origin/main` 을 포함하는가. 아니면 `git rebase origin/main` 이 필요하다고

고치지는 않는다. 다음 단계가 무엇인지(이슈 → 브랜치 → PR → 릴리즈) 한 줄로 안내한다. 규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/workflow-rules.md` 다.
