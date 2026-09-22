---
description: 프로젝트의 Go 코드 이름이 Go 컨벤션을 지키는지 검증한다
---

프로젝트 전체의 `*.go` 를 검증한다. `vendor/` · `testdata/` 와 생성 파일(`// Code generated ... DO NOT EDIT.`)은 보지 않는다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-go-naming.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 파일이나 디렉터리만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 검사한 범위와 경고(`GO-03` 이니셜리즘 · `GO-04` 게터 · `GO-05` 파일 이름 · `GO-06` 리시버)를 적는다.
- 위반(종료 코드 2)이면 조항 번호별로 묶어 파일 · 줄 · 제안 이름을 적는다. 고치지는 않는다.
- 이름을 바꾸면 참조도 바뀌어야 한다. 고치자고 하면 `go-name-create` 스킬을 따르고, 공개(대문자로 시작하는) 이름은 패키지 밖 호출부와 호환성을 먼저 확인한다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/go-naming-rules.md` 다.
