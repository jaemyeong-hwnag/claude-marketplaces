---
description: 이름 또는 저장소 전체가 네이밍 규칙과 glossary 를 지키는지 검증하고 판정한다
argument-hint: [이름 | 경로 | --all]
allowed-tools: Bash, Read, Grep, Glob
---

검토 대상: $ARGUMENTS

1. 대상이 비어 있으면 변경분(`git status --porcelain`)에서 플러그인·스킬·커맨드·에이전트 이름을 추린다.
   `--all` 이면 저장소 전체를 대상으로 한다.
2. 기계 검증을 돌린다.
   - 대상별: `"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" <대상>`
   - 전체: `"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --all .`
   - 사전: `"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --glossary`
3. `${CLAUDE_PLUGIN_ROOT}/references/naming-rules.md` 를 읽고, 훅이 잡지 못하는 항목(의도 전달, 대상-관심사 순서, 기존 이름과의 일관성)을 사람 기준으로 판정한다.
4. 이름마다 `통과 / 수정필요` 와 위반 조항, 대안을 보고한다. 파일은 고치지 않는다.

깊은 판정이 필요하면 `naming-reviewer` 에이전트에 위임한다.
