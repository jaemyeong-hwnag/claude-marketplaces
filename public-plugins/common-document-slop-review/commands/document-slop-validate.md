---
description: 문서에서 slop 흔적(대화 잔재 · 플레이스홀더 · 챗봇 토큰 · 깨진 링크)과 근거 없는 주장 · 형식 과잉 신호를 찾는다
---

`DS-01` ~ `DS-16` 을 검사한다. 인자가 없으면 기본 브랜치 대비 바뀐 줄만 본다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/document-slop-validate.sh" --diff
```

인자가 주어졌으면 그 파일이나 디렉터리 전체를 본다: `$ARGUMENTS`

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/document-slop-validate.sh" $ARGUMENTS
```

결과는 이렇게 정리해 보고한다.

- 차단과 경고를 조항별로 묶고, 파일 · 줄과 함께 적는다. 고치지는 않는다.
- 경고는 후보다. 판정하고 고치려면 `document-slop-review` 스킬을 따른다고 안내한다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/document-slop-rules.md` 다.
