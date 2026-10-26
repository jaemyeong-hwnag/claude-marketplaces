---
description: 기본 브랜치 대비 변경에서 테스트 약화 신호(skip · focus 표지 증가 · 단언 감소)를 찾는다
---

`E-20` 을 검사한다. 기본 브랜치 대비 바뀐 테스트 파일과 추적되지 않는 테스트 파일을 본다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/evidence-validate.sh" --diff $ARGUMENTS
```

`$ARGUMENTS` 에 `--strict` 가 있으면 신호가 있을 때 exit 2 다.

결과는 이렇게 정리해 보고한다.

- 신호를 파일별로 적는다. 고치지는 않는다.
- 신호는 후보다. 그 변경이 필요했는지 · 테스트가 변경을 덮는지는 `evidence-review` 스킬로 판정한다고 안내한다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/evidence-rules.md` 다.
