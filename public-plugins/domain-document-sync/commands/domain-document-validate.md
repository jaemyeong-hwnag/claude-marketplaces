---
description: docs/domain 3계층 도메인 문서의 정합성(카탈로그·메타 등재, 링크, 크기, code 글롭)을 검증한다
---

도메인 문서 트리를 검증한다. 규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/domain-document-rules.md` 2절.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/domain-document-sync.sh" validate "${CLAUDE_PROJECT_DIR:-.}"
"${CLAUDE_PLUGIN_ROOT}/scripts/domain-document-sync.sh" map "${CLAUDE_PROJECT_DIR:-.}"
```

두 명령을 돌리고 결과를 요약한다.

- `❌` 는 조항 번호와 함께 무엇을 고칠지 적는다. 사용자가 원하면 `domain-document-update` 스킬로 고친다
- `⚠️ D-08` (걸리는 파일이 없는 글롭) 은 코드가 옮겨졌는지 찾아본 뒤 새 글롭을 제안한다
- `map` 에서 파일 수가 0 이거나 지나치게 많은 도메인을 짚는다
- 문서 루트가 없으면 `domain-document-create` 스킬로 만들지 묻는다

$ARGUMENTS
