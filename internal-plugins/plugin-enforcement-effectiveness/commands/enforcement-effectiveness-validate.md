---
description: 플러그인이 적어 둔 강제가 실행에서 꺼지지 않았는지 훅 · MCP 를 실제로 돌려 검증한다
---

저장소 전체 플러그인의 강제 실효성을 검증한다. 훅 스크립트와 MCP 서버를 임시 디렉터리에서 실제로 실행한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-enforcement-effectiveness.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 플러그인만 검사한다 (실행 검사 `EF-20` ~ `EF-22` 는 빼고): `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 경고를 조항별 건수로 적는다 (`EF-07` · `EF-12` · `EF-20` · `EF-31`).
- 위반(종료 코드 2)이면 조항 번호별로 묶어 무엇을 고쳐야 하는지 적는다. 고치지는 않는다.
- `ℹ️ 실행 안 함` 줄은 검사하지 못한 훅이다. 통과로 세지 않는다.

역할 분리(`EF-40` ~ `EF-44`)까지 보려면 `enforcement-effectiveness-review` 스킬을 쓴다. 규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/enforcement-effectiveness-rules.md` 다.
