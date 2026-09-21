---
description: 플러그인 버전과 CHANGELOG · marketplace 엔트리 · 태그의 정합성을 검증한다
---

저장소 전체의 버전 정합성을 검증한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-versioning.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 경로만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 검사한 플러그인 수와 각 버전을 한 줄로 적는다.
- 위반(종료 코드 2)이면 조항 번호별로 묶어 무엇을 어떻게 고쳐야 하는지 적는다. 고치지는 않는다.
- `V-09` 위반은 **marketplace 엔트리 쪽을 고친다.** 설치 시점에는 `plugin.json` 이 이긴다.
- `V-06` 위반은 CHANGELOG 에 항목을 추가한다. 무엇이 바뀌었는지 모르면 `git log` 로 확인하고 쓴다.

버전을 실제로 올려야 하는 상황이면 `version-update` 스킬을 따른다. 규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/versioning-rules.md` 다.
