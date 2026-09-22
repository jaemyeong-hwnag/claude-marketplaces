---
description: 프로젝트의 TypeScript 코드 이름이 TypeScript 관례를 지키는지 검증한다
---

프로젝트 전체의 `*.ts` · `*.tsx` · `*.mts` · `*.cts` 를 검증한다 (`*.d.ts` 는 보지 않는다).

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-typescript-naming.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 파일이나 디렉터리만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 검사한 범위와 경고(`TS-02` I 접두사 · `TS-04` enum 멤버 · `TS-05` 타입 매개변수 · `TS-06` class 멤버)를 적는다.
- 위반(종료 코드 2)이면 조항 번호별로 묶어 파일 · 줄 · 제안 이름을 적는다. 고치지는 않는다.
- 이름을 바꾸면 참조도 바뀌어야 한다. 고치자고 하면 `typescript-name-create` 스킬을 따르고, export 된 이름은 쓰는 쪽을 먼저 확인한다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/typescript-naming-rules.md` 다.
