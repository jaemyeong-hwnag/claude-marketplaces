---
description: 마켓플레이스 루트와 플러그인의 디렉터리 구조가 규칙을 지키는지 검증한다
argument-hint: [플러그인 디렉터리 | 파일 경로 | --all | --marketplace]
allowed-tools: Bash, Read, Glob
---

검사 대상: $ARGUMENTS

1. 인자가 없으면 `--all .` 로 저장소 전체를 검사한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" ${ARGUMENTS:---all .}
```

2. 위반이 나오면 조항 번호(`P-0x` / `R-0x`)를 [`references/directory-structure-rules.md`](../references/directory-structure-rules.md) 에서 찾아 **왜 그 위치가 아닌지**와 **어디로 옮겨야 하는지**를 함께 보고한다.
3. 규칙 자체가 현실과 맞지 않는다고 판단되면 파일을 옮기지 말고 규칙을 고칠지 먼저 묻는다. 규칙을 고치면 `test/validate-directory-structure.test.sh` 에 TC 를 함께 추가한다.
4. 이름이 잘못된 것은 이 커맨드의 몫이 아니다. `/naming-review` 로 넘긴다.
