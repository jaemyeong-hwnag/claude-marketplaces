---
description: 작업 트리(또는 커밋 이력)에 시크릿 · ignore 안 된 민감 파일이 있는지 검증한다
---

작업 트리 전체(추적 파일 + ignore 되지 않은 새 파일)를 검사한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-git-secret.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 `history` 면 `--history` 로 커밋 이력 전체를 검사하고, 그 밖의 인자는 그 파일이나 디렉터리만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 검사한 범위와 엔진(gitleaks · 내장)을 적는다. `GS-05` 알림이 있으면 gitleaks 설치를 권한다.
- 위반(종료 코드 2)이면 조항(`GS-01` 시크릿 · `GS-02` 추적되는 민감 파일 · `GS-04` ignore 안 된 민감 파일)별로 파일과 규칙 이름을 적는다. 값은 다시 적지 않는다. 고치지는 않는다.
- 고치자고 하면 `secret-review` 스킬을 따른다. 이미 커밋 · 푸시된 시크릿은 폐기가 먼저다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/secret-rules.md` 다.
