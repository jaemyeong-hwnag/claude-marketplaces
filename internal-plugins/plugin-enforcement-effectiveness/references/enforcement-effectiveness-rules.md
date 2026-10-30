# 강제 실효성 규칙 (단일 원본)

플러그인이 훅 설정 · 에이전트 프런트매터 · 규칙 원본에 적어 둔 강제가 **실행에서 실제로 효력을 내는가**를 본다.
기계 판정은 [`scripts/validate-enforcement-effectiveness.sh`](../scripts/validate-enforcement-effectiveness.sh), 판단은 `enforcement-effectiveness-reviewer` 에이전트가 한다.

이 문서가 보장하는 것은 판정이 `차단` 인 조항뿐이다. `경고` 는 드러낼 뿐이고, 4절은 근거를 붙인 지적이지 보장이 아니다.
조항마다 근거(5절)와 확인한 Claude Code 버전을 단다. 버전이 오르면 동작이 바뀔 수 있다.

## 1. 언제 판정하는가

| 표기 | 시점 | 결과 |
|---|---|---|
| Pre | PreToolUse(`Write`) — 쓰려는 내용과 디스크의 같은 플러그인 파일 | 위반이면 exit 2 |
| Post | PostToolUse(`Write\|Edit`) — 저장 뒤 그 플러그인 전체 (2 · 3.1 · 3.3 절) | `additionalContext` 알림, exit 0 |
| all | `--all [루트]` — 저장소 전체 (+ 3.2 절) | 차단 조항 위반이면 exit 2 |
| since | `--since <ref> [루트]` — `<ref>` 와의 merge-base 이후 파일이 바뀐 플러그인 (+ 3.2 절) | 차단 조항 위반이면 exit 2 |

`verify-all.sh` 는 `--all` 과 `--since origin/main` 을 둘 다 돌린다. 그래서 `since` 에서만 차단인 조항은 **새로 만들거나 고친 플러그인에만** PR 전에 걸린다.
`Edit` 는 Pre 에서 보지 않는다 — 부분 문자열만 오므로 파일 전체를 판정할 수 없다. Edit 경로는 Post 가 알린다.
Post 가 막지 않는 이유: `EF-02` · `EF-05` · `EF-30` 은 파일 두 개 이상이 맞아야 성립한다. 첫 파일을 쓸 때 막으면 아무것도 만들 수 없다.

## 2. 강제 사슬 — 막는다고 적은 것이 실제로 막히는가

| 조항 | 내용 | 판정 |
|---|---|---|
| EF-01 | 훅의 `command` · `args`, MCP stdio 서버의 `command` · `args` 에 **플러그인 상대 경로로 읽히는 토큰**이 없다 — `/` · `$` · `~` · `-` 로 시작하지 않고 `/` 를 포함하는 것 (`./x.sh` · `scripts/x.sh`). 플러그인 파일은 `${CLAUDE_PLUGIN_ROOT}/…` 로 쓴다 | 차단 (Pre · all · since) |
| EF-02 | `${CLAUDE_PLUGIN_ROOT}/…` 토큰이 가리키는 파일이 있다 | 차단 (all · since) |
| EF-03 | 첫 토큰이 `${CLAUDE_PLUGIN_ROOT}/…` 인 파일(직접 실행)은 작업 트리에서 실행 권한이 있고, git 이 추적하면 인덱스 모드도 `100755` 다. 인터프리터 뒤의 파일(`bash "${CLAUDE_PLUGIN_ROOT}/x.sh"`)은 보지 않는다 | 차단 (all · since) |
| EF-04 | matcher 를 받지 않는 이벤트(`UserPromptSubmit` · `Stop` · `CwdChanged` · `PostToolBatch` · `TeammateIdle` · `TaskCreated` · `TaskCompleted` · `WorktreeCreate` · `WorktreeRemove` · `MessageDisplay`)에 `matcher` 키를 쓰지 않는다 (빈 문자열도) | 차단 (Pre · all · since) |
| EF-05 | 규칙 원본(`references/*.md`) 표에서 머리글이 `판정` · `검증` 인 열의 값에 `차단` · `경고` 가 들어 있는 조항은 그 ID 가 `test/*.test.sh` 에 나온다 | 차단 (all · since) |
| EF-06 | `EF-05` 의 조항이 하나라도 있으면 `scripts/validate-*.sh` 또는 `hooks/hooks.json` 이 있다 | 차단 (all · since) |
| EF-07 | `PreToolUse` · `UserPromptSubmit` 의 `command` 훅은 `"onFailure": "block"` 을 둔다 | all 경고 · since 차단 |

- `EF-05` 가 보는 것은 조항과 TC 의 **연결 표시**다. ID 가 TC 파일에 있다는 것이지 그 TC 가 그 조항을 막는다는 증명은 아니다. 증명은 각 플러그인의 TC 와 변이 테스트가 한다. 스크립트 메시지에서 ID 를 찾지 않는다 — ID 를 메시지에 쓰지 않고 강제하는 플러그인이 있다 (`*-aitest-coverage` 의 `C-01` ~ `C-04`)
- `EF-07` 의 반대 위험: `onFailure: "block"` 인 훅이 깨지면 그 matcher 에 걸리는 모든 도구 호출이 막힌다. 조용히 풀리는 것보다 낫다고 본다. `Stop` · `SubagentStop` · `TaskCompleted` · `TeammateIdle` 에서는 효과가 없어 대상에서 뺀다
- `EF-02` · `EF-03` 은 `EF-07` 이 있어도 필요하다. `EF-07` 은 깨진 훅을 막힘으로 바꿀 뿐이고, 깨진 것을 PR 전에 찾는 것은 `EF-02` · `EF-03` 이다

## 3. 선언이 적용되는가

### 3.1 에이전트 · 스킬 · 커맨드

| 조항 | 내용 | 판정 |
|---|---|---|
| EF-10 | 플러그인 에이전트에 `permissionMode` · `hooks` · `mcpServers` · `initialPrompt` 를 쓰지 않는다 — 무시된다 | 차단 (Pre · all · since) |
| EF-11 | 에이전트는 `tools` 를 선언한다 — 생략하면 모든 도구를 물려받는다 | 차단 (Pre · all · since) |
| EF-12 | 에이전트 `tools` 에 편집 도구(`Write` · `Edit` · `MultiEdit` · `NotebookEdit`)가 있다 | 경고 |
| EF-13 | 같은 플러그인 안에서 `skills/<x>/` 와 `commands/<x>.md` 의 이름이 같지 않다 — 하나가 가려진다 | 차단 (Pre · all · since) |

`EF-12` 는 막지 않는다. 편집이 필요한 에이전트도 있다. `Bash` 가 있는 에이전트는 편집 도구 없이도 파일을 쓸 수 있어 `EF-12` 로 막지 못한다.

### 3.2 실행해서 확인한다

`--all` · `--since` 에서만 돈다. `--no-run` 이면 건너뛴다.

| 조항 | 내용 | 판정 |
|---|---|---|
| EF-20 | `hooks.json` 의 command 훅마다 무관한 입력(아래)을 주면 그 훅의 `timeout`(없으면 60초) 안에 exit 0 으로 끝나고, stdout 에 `"permissionDecision": "deny"` · `"decision": "block"` 이 없다 | 경고 |
| EF-21 | MCP stdio 서버마다 `initialize` 에 15초 안에 응답한다 | 차단 (all · since) |
| EF-22 | 스킬 · 커맨드 · 에이전트 · `references/` 에 쓴 `mcp__plugin_<플러그인>_<서버>__<도구>` 가 그 서버의 `tools/list` 에 있다 | 차단 (all · since) |

실행 환경: 빈 임시 디렉터리를 cwd · `CLAUDE_PROJECT_DIR` · `TMPDIR` 로, `CLAUDE_PLUGIN_ROOT` 는 그 플러그인으로 둔다. `HOME` 은 바꾸지 않는다 — `claude` · `gh` 를 쓰는 훅이 다른 이유로 실패한다. 그래서 `HOME` 아래에 쓰는 훅은 막지 못한다.

`EF-20` 이 주는 입력 (공통으로 `session_id` · `cwd` · 없는 `transcript_path`):

| 이벤트 | 입력 |
|---|---|
| `PreToolUse` · `PostToolUse` | `tool_name` 은 matcher 에 맞지 않는 도구 (`Read` → `Glob` → `Grep` → `WebSearch` → `TodoWrite`, 모두 맞으면 실행 안 함), matcher 가 없거나 `*` 면 `Read`. `tool_input.file_path` 는 임시 디렉터리의 없는 파일. Post 는 `tool_response: {}` |
| `UserPromptSubmit` | `prompt: "안녕"` |
| `Stop` | `stop_hook_active: false` |
| `SessionStart` | `source: "startup"` |
| 그 밖 | 실행 안 함 |

`EF-20` 은 경고다. 무관한 입력에 막거나 실패하는 훅의 실제 피해를 재현하지 않았다. `EF-21` 은 도구 수를 보지 않는다 — 리소스 · 프롬프트만 내는 정상 서버가 있다.

### 3.3 eval 이 있는가

| 조항 | 내용 | 판정 |
|---|---|---|
| EF-30 | 스킬이 있는 플러그인은 `evals/` 에 `tags` 에 `trigger` 를 가진 케이스가, `hooks/hooks.json` 이 있는 플러그인은 `hook` 을 가진 케이스가 하나 이상 있다 | 차단 (all · since) |
| EF-31 | `disable-model-invocation: true` 가 아닌 스킬마다 `tool: Skill` 그레이더의 `input_match` 가 `{"skill": "<플러그인>:<스킬>"}` 에 맞는 케이스가 있다 | all 경고 · since 는 새 플러그인만 차단 |

- `EF-31` 의 `since` 차단은 `<ref>` 이후 `plugin.json` 이 새로 생긴 플러그인에만 건다. 고친 기존 플러그인까지 걸면 오타 하나 고치는 PR 에 eval 여러 개가 따라온다
- 그레이더 정규식은 JS 정규식이다. `node` 가 있으면 JS 로 적용하고 정규식 오류는 위반이다. 없으면 perl 로 적용하고 `(?i)` 같은 인라인 플래그를 위반으로 본다 (JS 에서 grader threw)

### 3.4 넣지 않는 것

| 후보 | 이유 |
|---|---|
| 알 수 없는 훅 이벤트 · 훅 `type` · mod 모듈 파일 누락 | `claude plugin validate --strict` 가 잡는다 (5절 E2) |
| 스킬 트리거 겹침 차단 | 스택별 플러그인은 일부러 겹친다. 4절 판단으로 본다 |
| 커맨드를 스킬로 옮기라는 규칙 | 커맨드도 동작한다. 실제 피해가 없다 |
| 호출부 없는 에이전트 | description 으로 자동 위임되므로 죽은 것이 아니다 |
| 에이전트 · 스킬의 도구 이름 | 도구 목록이 설정에 따라 다르다 |
| 매니페스트 · mod | 필드 · 경로 형식은 `validate --strict`, `name` · 경로 존재 · `hooks` 중복은 `marketplace-directory-structure` 가 본다. mod 는 구조 규칙상 이 저장소에 둘 수 없다 |

## 4. 판단 — 역할 분리

스크립트가 정할 수 없는 것. `enforcement-effectiveness-reviewer` 가 본다.

| 조항 | 묻는 것 | 판정 |
|---|---|---|
| EF-40 | 스킬 하나가 관심사 하나인가. 같은 플러그인 · 같이 설치되는 플러그인의 스킬과 트리거가 겹치는가 | AI 판단 |
| EF-41 | 판단이 필요한 검토를 에이전트로 떼었는가. 에이전트에 작성 맥락(결론 · 의도)을 넘기지 않고 필요한 입력만 넘기는가 | AI 판단 |
| EF-42 | 훅 이벤트가 목적에 맞는가 — 막을 것은 `PreToolUse`, 플러그인 전체를 봐야 하는 것은 `PostToolUse` 알림. `PostToolUse` 로 막으려 하지 않는가 (도구는 이미 실행됐다) | AI 판단 |
| EF-43 | 규칙 원본의 판단 조항(판정 열이 없거나 `AI 판단`)이 스킬 · 에이전트 어딘가에서 절차로 다뤄지는가 | AI 판단 |
| EF-44 | 외부 시스템이 필요한 일에 MCP · 스크립트 중 맞는 것을 골랐는가 | AI 판단 |

- 입력은 플러그인 경로와 이 문서 경로뿐이다. 호출한 쪽의 판단 · 의도를 넘기지 않는다
- 지적마다 `파일:줄` · 재현 명령 · 그 출력을 붙인다. 붙이지 못하면 `판정 불가` 로 낸다
- `enforcement-effectiveness-review` 스킬이 지적마다 재현 명령을 다시 실행해 출력이 같은 것만 보고한다

## 5. 근거

`E` 는 재현, `F` 는 공식 문서(code.claude.com/docs 의 hooks · plugins-reference · sub-agents)만 있는 것이다. 재현은 Claude Code 2.1.312 에서, `E13` 은 2.1.314 에서 했다.

| 근거 | 조항 | 요지 |
|---|---|---|
| E2 | 전부 | `claude plugin validate --strict` 는 없는 · 권한 없는 · 상대 경로 훅 스크립트, 무시되는 에이전트 필드, 이벤트에 맞지 않는 matcher 를 모두 통과시킨다 |
| E3 | `EF-01` ~ `EF-03` | `exit 2` 로 막는 PreToolUse(Write) 훅의 스크립트가 없거나 · 권한 644 거나 · `./scripts/block.sh` 면 파일이 그대로 써진다 (fail-open). 정상 대조군은 막힌다 |
| E13 | `EF-07` | 같은 픽스처에 `"onFailure": "block"` 을 두면 `failed; blocking because onFailure is "block"` 으로 막힌다. 대조군(없음)은 통과한다 |
| E7 | `EF-04` · `EF-10` · `EF-13` | 디버그 로그에 `sets permissionMode, which is ignored for plugin agents` (`hooks` · `mcpServers` 도). `Stop` 의 `matcher: "Write"` 훅이 도구 없는 응답에서도 돈다. 이름이 같은 커맨드 · 스킬 중 `slash_commands` 에 하나만 남는다 |
| E6 | `EF-13` | 플러그인에서 `/이름` 은 2/2 커맨드로 갔다 |
| F | `EF-04` 목록 · `EF-10` `initialPrompt` · `EF-11` | 문서만 — matcher 가 "silently ignored" 되는 이벤트 목록, 플러그인 에이전트에서 무시되는 필드, `tools` 생략 시 상속 |
| E9 | `EF-05` | 2026-10-30 저장소에서 판정 열이 차단 · 경고인 조항 중 `test/` 에 ID 가 없던 것은 `R-01` · `R-02` · `R-03` · `R-05` 넷 (테스트는 있고 ID 만 없었다) |
| E10 | `EF-31` | 2026-10-30 스킬 50개 중 17개가 발동 그레이더가 없다 |

재현 (E3 · E13 — 빈 디렉터리에서, haiku 1회 수 센트):

```bash
S=$(mktemp -d)
mkp() { local d=$S/$1; mkdir -p $d/.claude-plugin $d/hooks $d/scripts
  printf '{"name":"%s","version":"0.1.0","description":"x"}' "$1" > $d/.claude-plugin/plugin.json
  printf '#!/bin/sh\necho "BLOCKED-BY-HOOK" >&2\nexit 2\n' > $d/scripts/block.sh; chmod $3 $d/scripts/block.sh
  jq -n --arg c "$2" --arg of "${4:-}" '{hooks:{PreToolUse:[{matcher:"Write",hooks:[{type:"command",command:$c} + (if $of=="" then {} else {onFailure:$of} end)]}]}}' > $d/hooks/hooks.json; }
mkp ctrl          '"${CLAUDE_PLUGIN_ROOT}/scripts/block.sh"' 755
mkp missing       '"${CLAUDE_PLUGIN_ROOT}/scripts/nope.sh"'  755
mkp noexec        '"${CLAUDE_PLUGIN_ROOT}/scripts/block.sh"' 644
mkp relative      './scripts/block.sh'                       755
mkp missing-block '"${CLAUDE_PLUGIN_ROOT}/scripts/nope.sh"'  755 block
for p in ctrl missing noexec relative missing-block; do
  w=$S/work-$p; mkdir -p $w; cd $w
  claude -p "Use the Write tool to create out.txt in the current directory with content hi. Do nothing else." \
    --plugin-dir $S/$p --model haiku --allowedTools Write --output-format json < /dev/null > $S/$p.json 2>&1
  echo "$p: file_created=$([ -f $w/out.txt ] && echo yes || echo no)"
done
# 기대: ctrl no · missing yes · noexec yes · relative yes · missing-block no
```

재현 (E7):

```bash
S=$(mktemp -d); d=$S/agentf; mkdir -p $d/.claude-plugin $d/agents
printf '{"name":"agentf","version":"0.1.0","description":"x"}' > $d/.claude-plugin/plugin.json
printf -- '---\nname: r-reviewer\ndescription: x\ntools: Read\npermissionMode: plan\n---\nbody\n' > $d/agents/r-reviewer.md
mkdir $S/w && cd $S/w && claude -p "say ok" --model haiku --plugin-dir $d --max-turns 1 --debug-file $S/debug.log < /dev/null
grep "ignored for plugin agents" $S/debug.log
```

macOS 에는 `timeout` 이 없다. 결과 JSON 이 비어 있으면 실행되지 않은 것이다.
