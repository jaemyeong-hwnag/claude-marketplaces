---
description: 프로젝트의 Kotlin 코드 이름이 Kotlin 컨벤션을 지키는지 검증한다
---

프로젝트 전체의 `*.kt` 를 검증한다 (`*.kts` 는 보지 않는다).

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-kotlin-naming.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 파일이나 디렉터리만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 검사한 범위와 경고(`KN-01` 밑줄 · `KN-03` 파일 이름 · `KN-07` 약어)를 적는다.
- 위반(종료 코드 2)이면 조항 번호별로 묶어 파일 · 줄 · 제안 이름을 적는다. 고치지는 않는다.
- 이름을 바꾸면 참조도 바뀌어야 한다. 고치자고 하면 `kotlin-name-create` 스킬을 따르고, public API 는 호환성을 먼저 확인한다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/kotlin-naming-rules.md` 다.
