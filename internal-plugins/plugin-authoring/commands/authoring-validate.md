---
description: 플러그인의 스킬·커맨드·에이전트 프런트매터와 README 절 구성을 검증한다
---

저장소 전체 플러그인의 작성 규칙을 검증한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-authoring.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 플러그인만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 검사한 플러그인 수와 경고(`A-05` · `A-06` · `A-07`)를 적는다.
- 위반(종료 코드 2)이면 조항 번호별로 묶어 무엇을 고쳐야 하는지 적는다. 고치지는 않는다.
- README 표 불일치(`A-24` ~ `A-27`)는 **README 쪽을 고친다.** 실제 구성요소가 원본이다.

고쳐야 하면 `document-create` 스킬을 따른다. 규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/authoring-rules.md` 다.
