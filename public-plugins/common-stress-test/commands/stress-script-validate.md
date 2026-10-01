---
description: 프로젝트의 부하 테스트 스크립트(k6 · Gatling · Locust · JMeter)가 측정 설계 규칙을 지키는지 검증한다
---

프로젝트 안의 부하 스크립트를 찾아 `ST-02` ~ `ST-06` 을 검사한다. `node_modules/` · `build/` · `target/` · `.venv/` 는 보지 않는다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/stress-script-validate.sh" "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 파일이나 디렉터리만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 찾은 스크립트 수와 경고를 조항별로 묶어 파일과 함께 적는다. 고치지는 않는다
- `ST-02` (closed 모델) 은 시스템이 실제로 closed 인지 묻는다. 맞으면 `stress-test: closed-model` 주석을 두라고 안내하고, 아니면 open executor 로 바꾸라고 안내한다
- 고치자고 하면 `stress-test-create` 스킬을 따른다

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/stress-test-rules.md` 다.
