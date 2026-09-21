---
description: 프로젝트의 package.json · JS 코드 · 환경 변수 이름이 npm 규칙과 JS 관례를 지키는지 검증한다
---

프로젝트 전체의 `package.json` · `*.js` · `*.mjs` · `*.cjs` · `*.jsx` 와 TS 파일의 환경 변수를 검증한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-node-naming.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

인자가 주어졌으면 그 파일이나 디렉터리만 검사한다: `$ARGUMENTS`

결과를 이렇게 정리해 보고한다.

- 통과(종료 코드 0)면 검사한 범위와 경고(`ND-02` npm script · `ND-06` 파일 이름)를 적는다.
- 위반(종료 코드 2)이면 조항 번호별로 묶어 파일 · 줄 · 제안 이름을 적는다. 고치지는 않는다.
- 이름을 바꾸면 참조도 바뀌어야 한다. 환경 변수는 배포 설정까지, 패키지 이름은 import 하는 쪽까지 바뀐다. 고치자고 하면 `node-name-create` 스킬을 따른다.

규칙 원본은 `${CLAUDE_PLUGIN_ROOT}/references/node-naming-rules.md` 다.
