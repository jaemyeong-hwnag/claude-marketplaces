---
description: 코드에서 성능 위험 패턴(루프 안 쿼리 · 원격 호출 · await, 상한 없는 조회, SELECT * 등)을 찾는다
---

`PF-01` ~ `PF-20` 패턴을 찾는다. 인자가 없으면 기본 브랜치 대비 바뀐 줄만 본다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/performance-validate.sh" --diff
```

인자가 주어졌으면 그 파일이나 디렉터리 전체를 본다: `$ARGUMENTS`

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/performance-validate.sh" $ARGUMENTS
```

결과를 이렇게 정리해 보고한다.

- 경고를 조항별로 묶어 파일 · 줄과 함께 적는다. 고치지는 않는다
- 패턴은 후보다. 정말 문제인지 판정하려면 `performance-review` 스킬을 따른다고 안내한다

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/performance-rules.md` 다.
