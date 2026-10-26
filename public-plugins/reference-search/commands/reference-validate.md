---
description: 문서의 DOI · arXiv ID 가 실제로 있는지, 철회됐는지, URL 이 살아 있는지 확인한다
---

인자로 받은 파일을 본다: `$ARGUMENTS`. 인자가 없으면 무엇을 볼지 묻는다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/reference-validate.sh" --urls $ARGUMENTS
```

결과는 이렇게 정리해 보고한다.

- `❌` (`RS-01` · `RS-02` · `RS-05`) 는 파일 · 식별자와 함께 먼저 적는다. 고치지는 않는다.
- `⚠️ RS-03` 철회는 문서에 표시하라고 안내한다. `⚠️ RS-06` 접근 제한은 유료 장벽 · 봇 차단일 수 있어 실패로 보지 않는다.
- `❓ RS-04` 는 네트워크 · 한도로 확인하지 못한 것이다. 잠시 뒤 다시 돌리라고 안내한다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/reference-search-rules.md` 다.
