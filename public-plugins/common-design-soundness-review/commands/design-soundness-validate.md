---
description: 설계 문서 · 계획 파일에서 필수 절 누락 · mermaid 플로우 막힘 · 요구 ID · 숫자 없는 품질 요구 · 정의 전 용어를 찾는다
---

`DD-20` ~ `DD-24` 를 검사한다. 판정은 하지 않는다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/design-soundness-validate.sh" $ARGUMENTS
```

- `$ARGUMENTS` 는 설계 파일 경로다. 계획 파일이면 `--plan` 을 앞에 붙인다 (필수 절 목록이 다르다).
- `--strict` 가 있으면 신호가 있을 때 exit 2 다.

결과는 이렇게 정리해 보고한다.

- 신호를 파일별로 적는다. 고치지는 않는다.
- 신호는 후보다. 설계의 앞뒤가 맞는지는 `design-soundness-review` 스킬로 판정한다고 안내한다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/design-soundness-rules.md` 다.
