---
description: 저장소 전체 플러그인의 의존 관계(순환 · 층 · 경계 · 범위 겹침)를 검증한다
---

저장소 전체의 의존 그래프를 검증한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-dependency.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자로 플러그인 이름이 주어졌으면 그 플러그인에 **기대는 것**을 보여준다: `$ARGUMENTS`

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-dependency.sh" --dependents "$ARGUMENTS" "${CLAUDE_PROJECT_DIR:-.}"
```

결과를 이렇게 정리해 보고한다.

- 위반(종료 코드 2)이면 조항 번호별로 묶고, 어느 플러그인의 `dependencies` 를 고쳐야 하는지 적는다. 고치지는 않는다.
- 순환(`D-03`)은 **어느 간선을 끊을지**가 판단이다. 층 방향(common ← 언어별 ← 워크플로우 ← 번들)을 거스르는 간선을 끊는다.
- 경고(`D-10`)는 막지 않는다. 정확히 고정한 이유가 있는지만 확인한다.

고쳐야 하면 `dependency-update` 스킬을 따른다. 규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/dependency-rules.md` 다.
