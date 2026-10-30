#!/usr/bin/env bash
# scripts/validate-enforcement-effectiveness.sh 의 회귀 테스트.
# 형식은 plugin-authoring, 위치는 marketplace-directory-structure 가 본다. 여기서는 실행에서의 효력만 본다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="${EF_SCRIPT:-$PLUGIN_ROOT/scripts/validate-enforcement-effectiveness.sh}"   # 변이 테스트가 바꾼다
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ef-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export EF_MCP_TIMEOUT=2

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
on() { [ "$TC_ON" = 1 ]; }
fail_tc() { on || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { on || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
run_stdin() { on || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { on || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { on || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { on || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { on || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# 픽스처 밖(이 저장소)을 커밋 · 체크아웃하지 않도록 -C 가 $TMP 아래일 때만 돈다
GIT() {
  case "$1:${2:-}" in -C:"$TMP"/*) ;; *) echo "GIT: 픽스처 밖 경로 '${2:-}' — 실행하지 않는다" >&2; return 1 ;; esac
  git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"
}

# --- 픽스처: 모든 조항을 지키는 플러그인 ------------------------------------
# 스킬 · 커맨드 · 에이전트 · 훅(Pre · Post · Stop) · MCP 서버 · 규칙 원본 · TC · trigger / hook eval. git 저장소로 만든다.
P=""; Q=""; R=""; W=""; MAIN=""
make_plugin() { # → 플러그인 경로. 루트는 ${P%/internal-plugins/*}
  local r d
  r="$(mktemp -d "$TMP/r.XXXXXX")"
  d="$r/internal-plugins/order-sync"
  mkdir -p "$d/.claude-plugin" "$d/skills/order-create" "$d/commands" "$d/agents" "$d/hooks" "$d/scripts" \
           "$d/references" "$d/test" "$d/evals/blocked/graders" "$d/evals/fired/graders"
  cat > "$d/.claude-plugin/plugin.json" <<'EOF'
{ "name": "order-sync", "version": "0.1.0", "description": "주문",
  "mcpServers": { "orders": { "command": "${CLAUDE_PLUGIN_ROOT}/scripts/mcp.sh" } } }
EOF
  printf -- '---\nname: order-create\ndescription: 주문을 만들 때 사용한다.\n---\n\n`mcp__plugin_order-sync_orders__order_get` 을 쓴다.\n' > "$d/skills/order-create/SKILL.md"
  printf -- '---\ndescription: 주문을 검증한다\n---\n\n본문\n' > "$d/commands/order-validate.md"
  printf -- '---\nname: order-reviewer\ndescription: 주문을 검토한다\ntools: Read, Grep\n---\n\n본문\n' > "$d/agents/order-reviewer.md"
  printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$d/scripts/check.sh"
  cat > "$d/scripts/mcp.sh" <<'EOF'
#!/usr/bin/env bash
while IFS= read -r l; do
  id="$(printf '%s' "$l" | jq -r '.id // empty')"
  case "$(printf '%s' "$l" | jq -r '.method // empty')" in
    initialize) printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"o","version":"0"}}}\n' "$id" ;;
    tools/list) printf '{"jsonrpc":"2.0","id":%s,"result":{"tools":[{"name":"order_get","inputSchema":{"type":"object"}}]}}\n' "$id" ;;
  esac
done
EOF
  chmod 755 "$d/scripts/check.sh" "$d/scripts/mcp.sh"
  set_hooks "$d" '{ "hooks": {
    "PreToolUse":  [ { "matcher": "Write", "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\"", "onFailure": "block" } ] } ],
    "PostToolUse": [ { "matcher": "Write|Edit", "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\"" } ] } ],
    "Stop":        [ { "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\"" } ] } ] } }'
  printf '# 규칙\n\n| 조항 | 내용 | 판정 |\n|---|---|---|\n| OS-01 | 주문 | 차단 |\n' > "$d/references/rules.md"
  printf '#!/usr/bin/env bash\n# tc OS-01\n' > "$d/test/order.test.sh"
  printf -- '---\ndescription: 막힌다\ntags: [hook]\n---\n\n쓴다\n' > "$d/evals/blocked/prompt.md"
  printf -- '---\ntype: regex\ntarget: trace\npattern: "OS-01"\n---\n' > "$d/evals/blocked/graders/hook-fired.md"
  printf -- '---\ndescription: 뜬다\ntags: [trigger]\n---\n\n주문 만들어\n' > "$d/evals/fired/prompt.md"
  printf -- "---\ntype: tool_used\ntool: Skill\ninput_match: '\"skill\"\\\\s*:\\\\s*\"(?:[\\\\w-]+:)?order-create\"'\n---\n" > "$d/evals/fired/graders/skill-fired.md"
  { GIT -C "$r" init -q; GIT -C "$r" add -A; GIT -C "$r" commit -qm base; } >/dev/null 2>&1
  printf '%s' "$d"
}
root_of() { printf '%s' "${1%/internal-plugins/*}"; }
set_hooks() { printf '%s\n' "$2" > "$1/hooks/hooks.json"; }
one_hook() { # $1=플러그인 $2=이벤트 $3=hook 객체 JSON $4=그룹 추가 키(JSON, 기본 {})
  jq -n --arg e "$2" --argjson h "$3" --argjson g "${4:-null}" '{hooks: {($e): [(($g // {}) + {hooks: [$h]})]}}' > "$1/hooks/hooks.json"
}
agent_fm() { printf -- '---\n%s\n---\n\n본문\n' "$2" > "$1/agents/order-reviewer.md"; }
CHECK='"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh"'
PRE() { jq -nc --arg p "$1" --arg c "$2" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p,content:$c}}'; }
PRE_EDIT() { jq -nc --arg p "$1" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p,old_string:"a",new_string:"b"}}'; }
POST() { jq -nc --arg p "$1" '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$p}}'; }

echo "== A. 기준 =="

tc TC-E01 "이 저장소 전체가 --all --no-run 을 통과한다"
run --all --no-run "$REPO_ROOT"; expect_code 0

tc TC-E02 "모든 조항을 지킨 플러그인은 조용히 통과한다"
on && P="$(make_plugin)"; run "$P"; expect_code 0; expect_no_out

tc TC-E03 "실행 검사까지 해도 조용히 통과한다 (--all)"
on && P="$(make_plugin)"; run --all "$(root_of "$P")"; expect_code 0; expect_no_out

echo "== B. 강제 사슬 (EF-01 ~ EF-07) =="

tc TC-E10 "훅 command 가 상대 경로면 막는다 (EF-01)"
on && { P="$(make_plugin)"; one_hook "$P" PreToolUse '{"type":"command","command":"./scripts/check.sh","onFailure":"block"}' '{"matcher":"Write"}'; }
run "$P"; expect_code 2; expect_out "(EF-01)"; expect_out "./scripts/check.sh"

tc TC-E11 "훅 args 안의 상대 경로를 막는다 (EF-01 경계)"
on && { P="$(make_plugin)"; one_hook "$P" PostToolUse '{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\"","args":["scripts/conf.json"]}'; }
run "$P"; expect_code 2; expect_out "scripts/conf.json"; expect_out "(EF-01)"

tc TC-E12 "MCP 서버 command 가 상대 경로면 막는다 (EF-01)"
on && { P="$(make_plugin)"; jq '.mcpServers.orders.command = "scripts/mcp.sh"' "$P/.claude-plugin/plugin.json" > "$TMP/pj" && mv "$TMP/pj" "$P/.claude-plugin/plugin.json"; }
run "$P"; expect_code 2; expect_out "mcpServers.orders"; expect_out "(EF-01)"

tc TC-E13 "env · 인터프리터 · 시스템 명령 · 리다이렉트 · CLAUDE_PROJECT_DIR 는 통과한다 (EF-01 과잉 차단 방지)"
on && { P="$(make_plugin)"; set_hooks "$P" '{ "hooks": { "PostToolUse": [ { "hooks": [
  { "type": "command", "command": "/usr/bin/env bash \"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\" 2>/dev/null" },
  { "type": "command", "command": "jq -n . >/dev/null" },
  { "type": "command", "command": "\"${CLAUDE_PROJECT_DIR}/tools/x.sh\" --flag=a/b" } ] } ] } }'; }
run "$P"; expect_code 0; expect_not "EF-01"

tc TC-E14 "훅이 가리키는 스크립트가 없으면 막는다 (EF-02)"
on && { P="$(make_plugin)"; one_hook "$P" PostToolUse '{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/scripts/nope.sh\""}'; }
run "$P"; expect_code 2; expect_out "(EF-02)"

tc TC-E15 "MCP 서버 스크립트가 없으면 막는다 (EF-02)"
on && { P="$(make_plugin)"; rm "$P/scripts/mcp.sh"; }
run "$P"; expect_code 2; expect_out "mcpServers.orders"; expect_out "(EF-02)"

tc TC-E16 "직접 실행하는 스크립트에 실행 권한이 없으면 막는다 (EF-03)"
on && { P="$(make_plugin)"; chmod 644 "$P/scripts/check.sh"; }
run "$P"; expect_code 2; expect_out "실행 권한이 없습니다"; expect_out "(EF-03)"

tc TC-E17 "인터프리터 뒤의 파일은 실행 권한을 보지 않는다 (EF-03 과잉 차단 방지)"
on && { P="$(make_plugin)"; chmod 644 "$P/scripts/check.sh"
  one_hook "$P" PostToolUse '{"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\""}'; }
run "$P"; expect_code 0; expect_not "EF-03"

tc TC-E18 "작업 트리는 755 인데 git 인덱스가 644 면 막는다 (EF-03 경계)"
on && { P="$(make_plugin)"; GIT -C "$P" update-index --chmod=-x scripts/check.sh; }
run "$P"; expect_code 2; expect_out "인덱스 모드가 100644"

tc TC-E19 "인덱스는 755 인데 작업 트리가 644 면 막는다 (EF-03 경계)"
on && { P="$(make_plugin)"; chmod 644 "$P/scripts/check.sh"; }
run "$P"; expect_code 2; expect_out "실행 권한이 없습니다"

tc TC-E20 "git 이 추적하지 않는 새 스크립트는 작업 트리 권한만 본다 (EF-03 경계)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/new.sh"; chmod 755 "$P/scripts/new.sh"
  one_hook "$P" PostToolUse '{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/scripts/new.sh\""}'; }
run "$P"; expect_code 0; expect_not "EF-03"

tc TC-E21 "git 저장소가 아니어도 작업 트리 권한을 본다 (EF-03 경계)"
on && { P="$(make_plugin)"; rm -rf "$(root_of "$P")/.git"; chmod 644 "$P/scripts/check.sh"; }
run "$P"; expect_code 2; expect_out "(EF-03)"

tc TC-E22 "Stop 에 matcher 를 쓰면 막는다 (EF-04)"
on && { P="$(make_plugin)"; one_hook "$P" Stop "{\"type\":\"command\",\"command\":$(jq -n --arg c "$CHECK" '$c')}" '{"matcher":"Write"}'; }
run "$P"; expect_code 2; expect_out "Stop 는 matcher 를 받지 않습니다"; expect_out "(EF-04)"

tc TC-E23 "UserPromptSubmit 의 빈 matcher 도 막는다 (EF-04 경계)"
on && { P="$(make_plugin)"; one_hook "$P" UserPromptSubmit "{\"type\":\"command\",\"command\":$(jq -n --arg c "$CHECK" '$c'),\"onFailure\":\"block\"}" '{"matcher":""}'; }
run "$P"; expect_code 2; expect_out "UserPromptSubmit 는 matcher 를 받지 않습니다"; expect_out "(EF-04)"

tc TC-E24 "규칙 원본의 차단 조항 ID 가 test 에 없으면 막는다 (EF-05)"
on && { P="$(make_plugin)"; printf '#!/usr/bin/env bash\n' > "$P/test/order.test.sh"; }
run "$P"; expect_code 2; expect_out "'OS-01'"; expect_out "(EF-05)"

tc TC-E25 "ID 가 scripts 에만 있어도 막는다 — test 만 본다 (EF-05)"
on && { P="$(make_plugin)"; printf '#!/usr/bin/env bash\n' > "$P/test/order.test.sh"; printf '# OS-01\n' >> "$P/scripts/check.sh"; }
run "$P"; expect_code 2; expect_out "(EF-05)"

tc TC-E26 "'위반 시 차단' · '**경고**' 셀도 대상이다 — 포함 판정 (EF-05)"
on && { P="$(make_plugin)"; printf '\n| 조항 | 내용 | **검증** |\n|---|---|---|\n| `OS-02` | a | 위반 시 차단 |\n| OS-03 | b | **경고** |\n' >> "$P/references/rules.md"; }
run "$P"; expect_code 2; expect_out "'OS-02'"; expect_out "'OS-03'"

tc TC-E27 "판정 열이 없는 표 · AI 판단 조항은 보지 않는다 (EF-05 과잉 차단 방지)"
on && { P="$(make_plugin)"; printf '\n| 조항 | 묻는 것 |\n|---|---|\n| OS-40 | 차단할까 |\n\n| 조항 | 내용 | 판정 |\n|---|---|---|\n| OS-41 | c | AI 판단 |\n' >> "$P/references/rules.md"; }
run "$P"; expect_code 0; expect_not "OS-40"; expect_not "OS-41"

tc TC-E28 "차단 조항이 있는데 검증기도 훅도 없으면 막는다 (EF-06)"
on && { P="$(make_plugin)"; rm -rf "$P/hooks" "$P/evals/blocked"; }
run "$P"; expect_code 2; expect_out "(EF-06)"

tc TC-E29 "scripts/validate-*.sh 가 있으면 훅이 없어도 된다 (EF-06)"
on && { P="$(make_plugin)"; rm -rf "$P/hooks" "$P/evals/blocked"; printf '#!/bin/sh\n' > "$P/scripts/validate-order.sh"; }
run "$P"; expect_code 0; expect_not "EF-06"

tc TC-E30 "onFailure 가 없는 PreToolUse 훅은 경고만 한다 — 플러그인 · --all (EF-07)"
on && { P="$(make_plugin)"; one_hook "$P" PreToolUse "{\"type\":\"command\",\"command\":$(jq -n --arg c "$CHECK" '$c')}" '{"matcher":"Write"}'; }
run "$P"; expect_code 0; expect_out "(EF-07)"
run --all --no-run "$(root_of "$P")"; expect_code 0; expect_out "(EF-07)"

tc TC-E31 "--since 에서는 onFailure 가 없으면 막는다 (EF-07)"
on && { P="$(make_plugin)"; one_hook "$P" UserPromptSubmit "{\"type\":\"command\",\"command\":$(jq -n --arg c "$CHECK" '$c')}"; }
run --since HEAD --no-run "$(root_of "$P")"; expect_code 2; expect_out "UserPromptSubmit"; expect_out "(EF-07)"

tc TC-E32 "PostToolUse · Stop 훅에는 onFailure 를 요구하지 않는다 (EF-07 과잉 차단 방지)"
on && P="$(make_plugin)"; run --since HEAD --no-run "$(root_of "$P")"; expect_code 0; expect_not "EF-07"

echo "== C. 선언이 적용되는가 (EF-10 ~ EF-13) =="

for k in "permissionMode: plan" "hooks:\n  Stop: []" "mcpServers: [x]" "initialPrompt: hi"; do
  key="${k%%:*}"
  tc "TC-E40-$key" "에이전트의 $key 는 무시되므로 막는다 (EF-10)"
  on && { P="$(make_plugin)"; agent_fm "$P" "$(printf "name: order-reviewer\ndescription: 검토\ntools: Read\n$k")"; }
  run "$P"; expect_code 2; expect_out "'$key' 는 플러그인 에이전트에서 무시됩니다"; expect_out "(EF-10)"
done

tc TC-E41 "본문에 permissionMode 라는 단어가 있어도 프런트매터가 아니면 보지 않는다 (EF-10 과잉 차단 방지)"
on && { P="$(make_plugin)"; printf -- '---\nname: order-reviewer\ndescription: 검토\ntools: Read\n---\n\npermissionMode: plan 은 쓰지 않는다\n' > "$P/agents/order-reviewer.md"; }
run "$P"; expect_code 0; expect_not "EF-10"

tc TC-E42 "에이전트에 tools 가 없으면 막는다 (EF-11)"
on && { P="$(make_plugin)"; agent_fm "$P" "name: order-reviewer
description: 검토"; }
run "$P"; expect_code 2; expect_out "tools 가 없습니다"; expect_out "(EF-11)"

tc TC-E43 "tools 에 편집 도구가 있으면 경고만 한다 — 쉼표 · 블록 목록 (EF-12)"
on && { P="$(make_plugin)"; agent_fm "$P" "name: order-reviewer
description: 검토
tools: Read, Write"; }
run "$P"; expect_code 0; expect_out "편집 도구 'Write'"
on && agent_fm "$P" "name: order-reviewer
description: 검토
tools:
  - Read
  - Edit"
run "$P"; expect_code 0; expect_out "편집 도구 'Edit' 가 있습니다 — 검토 · 검색 에이전트라면 빼세요 (EF-12)"

tc TC-E44 "같은 이름의 스킬과 커맨드를 막는다 (EF-13)"
on && { P="$(make_plugin)"; printf -- '---\ndescription: x\n---\n' > "$P/commands/order-create.md"; }
run "$P"; expect_code 2; expect_out "(EF-13)"

echo "== D. 실행 검사 (EF-20 ~ EF-22) =="

tc TC-E50 "무관한 입력에 exit 2 하는 훅을 경고한다 (EF-20)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\ncat >/dev/null; echo no >&2; exit 2\n' > "$P/scripts/check.sh"; }
run --all "$(root_of "$P")"; expect_code 0; expect_out "exit 2 입니다"; expect_out "(EF-20)"

tc TC-E51 "timeout 안에 끝나지 않는 훅을 경고한다 (EF-20)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\nsleep 5\n' > "$P/scripts/slow.sh"; chmod 755 "$P/scripts/slow.sh"
  one_hook "$P" PostToolUse '{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/scripts/slow.sh\"","timeout":1}'; }
run --all "$(root_of "$P")"; expect_code 0; expect_out "timeout 1초 안에 끝나지 않습니다"; expect_out "(EF-20)"

tc TC-E52 "stdout 으로 deny 를 내는 훅을 경고한다 (EF-20)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\ncat >/dev/null\necho %s\n' "'{\"hookSpecificOutput\":{\"permissionDecision\": \"deny\"}}'" > "$P/scripts/check.sh"; }
run --all "$(root_of "$P")"; expect_code 0; expect_out "deny · block 합니다"; expect_out "(EF-20)"

tc TC-E53 "matcher 가 Read 를 받으면 다른 도구로 바꿔 넣는다 (EF-20)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\n[ "$(jq -r .tool_name)" = Read ] && exit 2\nexit 0\n' > "$P/scripts/check.sh"
  one_hook "$P" PreToolUse "{\"type\":\"command\",\"command\":$(jq -n --arg c "$CHECK" '$c'),\"onFailure\":\"block\"}" '{"matcher":"Read|Write"}'; }
run --all "$(root_of "$P")"; expect_code 0; expect_not "EF-20"

tc TC-E54 "matcher 가 시험 도구를 모두 받거나 입력이 없는 이벤트는 '실행 안 함' 으로 적는다 (EF-20)"
on && { P="$(make_plugin)"; set_hooks "$P" '{ "hooks": {
  "PreToolUse": [ { "matcher": ".*", "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\"", "onFailure": "block" } ] } ],
  "SubagentStop": [ { "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/check.sh\"" } ] } ] } }'; }
run --all "$(root_of "$P")"; expect_code 0; expect_out "모두 받아 실행 안 함"; expect_out "SubagentStop: 시험 입력이 없는 이벤트라 실행 안 함"

tc TC-E55 "--no-run 이면 실행 검사를 건너뛴다 (EF-20 · EF-21)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\nexit 2\n' > "$P/scripts/check.sh"; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/mcp.sh"; }
run --all --no-run "$(root_of "$P")"; expect_code 0; expect_not "EF-20"; expect_not "EF-21"

tc TC-E56 "플러그인 하나만 볼 때는 실행하지 않는다 (EF-20)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\nexit 2\n' > "$P/scripts/check.sh"; }
run "$P"; expect_code 0; expect_not "EF-20"

tc TC-E57 "initialize 에 응답하지 않고 끝나는 MCP 서버를 막는다 (EF-21)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/mcp.sh"; }
run --all "$(root_of "$P")"; expect_code 2; expect_out "initialize 응답이 없습니다"; expect_out "(EF-21)"

tc TC-E58 "제한 시간 안에 응답하지 않는 MCP 서버를 막는다 (EF-21)"
on && { P="$(make_plugin)"; printf '#!/bin/sh\nsleep 10\n' > "$P/scripts/mcp.sh"; }
run --all "$(root_of "$P")"; expect_code 2; expect_out "2초 안에 응답이 없습니다"

tc TC-E59 "tools/list 에 없는 MCP 도구 이름을 막는다 (EF-22)"
on && { P="$(make_plugin)"; printf '\n`mcp__plugin_order-sync_orders__order_cancel` 도 쓴다.\n' >> "$P/skills/order-create/SKILL.md"; }
run --all "$(root_of "$P")"; expect_code 2; expect_out "'mcp__plugin_order-sync_orders__order_cancel'"; expect_out "(EF-22)"

echo "== E. eval (EF-30 · EF-31) =="

tc TC-E60 "스킬이 있는데 trigger 케이스가 없으면 막는다 (EF-30)"
on && { P="$(make_plugin)"; rm -rf "$P/evals/fired"; }
run "$P"; expect_code 2; expect_out "tags: [trigger] 케이스가 없습니다"; expect_out "(EF-30)"

tc TC-E61 "훅이 있는데 hook 케이스가 없으면 막는다 (EF-30)"
on && { P="$(make_plugin)"; rm -rf "$P/evals/blocked"; }
run "$P"; expect_code 2; expect_out "tags: [hook] 케이스가 없습니다"; expect_out "(EF-30)"

tc TC-E62 "블록 목록 tags 와 묶음 디렉터리 안의 케이스도 읽는다 (EF-30 경계)"
on && { P="$(make_plugin)"; rm -rf "$P/evals/blocked"; mkdir -p "$P/evals/group/blocked"; printf -- '---\ndescription: x\ntags:\n  - hook\n---\n' > "$P/evals/group/blocked/prompt.md"; }
run "$P"; expect_code 0; expect_not "EF-30"

tc TC-E63 "스킬에 발동 그레이더가 없으면 경고만 한다 — 플러그인 · --all (EF-31)"
on && { P="$(make_plugin)"; mkdir -p "$P/skills/order-cancel"; printf -- '---\nname: order-cancel\ndescription: 주문을 취소할 때 사용한다.\n---\n' > "$P/skills/order-cancel/SKILL.md"; }
run "$P"; expect_code 0; expect_out "스킬 'order-cancel' 에 발동 그레이더"; expect_out "(EF-31)"; expect_not "'order-create'"

tc TC-E64 "disable-model-invocation: true 스킬은 보지 않는다 (EF-31 과잉 차단 방지)"
on && { P="$(make_plugin)"; mkdir -p "$P/skills/order-cancel"; printf -- '---\nname: order-cancel\ndescription: 주문을 취소할 때 사용한다.\ndisable-model-invocation: true\n---\n' > "$P/skills/order-cancel/SKILL.md"; }
run "$P"; expect_code 0; expect_not "EF-31"

tc TC-E65 "input_match 없는 tool: Skill 그레이더는 모든 스킬에 맞는다 (EF-31)"
on && { P="$(make_plugin)"; mkdir -p "$P/skills/order-cancel"; printf -- '---\nname: order-cancel\ndescription: 주문을 취소할 때 사용한다.\n---\n' > "$P/skills/order-cancel/SKILL.md"
  printf -- '---\ntype: tool_used\ntool: Skill\n---\n' > "$P/evals/fired/graders/any.md"; }
run "$P"; expect_code 0; expect_not "EF-31"

tc TC-E66 "끝 따옴표까지 쓴 정규식은 접두사가 같은 다른 스킬에 맞지 않는다 (EF-31 경계)"
on && { P="$(make_plugin)"; mkdir -p "$P/skills/order-create-bulk"; printf -- '---\nname: order-create-bulk\ndescription: 주문을 한꺼번에 만들 때 사용한다.\n---\n' > "$P/skills/order-create-bulk/SKILL.md"; }
run "$P"; expect_code 0; expect_out "'order-create-bulk'"

tc TC-E67 "JS 에서 깨지는 인라인 플래그 정규식은 위반이다 (EF-31)"
on && { P="$(make_plugin)"; printf -- "---\ntype: tool_used\ntool: Skill\ninput_match: '(?i)order-create'\n---\n" > "$P/evals/fired/graders/skill-fired.md"; }
run "$P"; expect_code 0; expect_out "JS 정규식으로 읽히지 않습니다"; expect_out "(EF-31)"

tc TC-E68 "--since 에서 새 플러그인은 발동 그레이더가 없으면 막는다 (EF-31)"
on && { P="$(make_plugin)"; R="$(root_of "$P")"; GIT -C "$R" mv internal-plugins/order-sync internal-plugins/order-new 2>/dev/null
  P="$R/internal-plugins/order-new"; jq '.name = "order-new"' "$P/.claude-plugin/plugin.json" > "$TMP/pj" && mv "$TMP/pj" "$P/.claude-plugin/plugin.json"; rm "$P/evals/fired/graders/skill-fired.md"; }
run --since HEAD --no-run "$R"; expect_code 2; expect_out "스킬 'order-create' 에 발동 그레이더"

tc TC-E69 "--since 에서 고친 기존 플러그인은 경고만 한다 (EF-31)"
on && { P="$(make_plugin)"; rm "$P/evals/fired/graders/skill-fired.md"; }
run --since HEAD --no-run "$(root_of "$P")"; expect_code 0; expect_out "(EF-31)"

echo "== F. --since =="

tc TC-E70 "바뀌지 않은 플러그인은 보지 않는다"
on && { P="$(make_plugin)"; R="$(root_of "$P")"; agent_fm "$P" "name: order-reviewer
description: 검토"; GIT -C "$R" commit -qam broken; }
run --since HEAD --no-run "$R"; expect_code 0
run --all --no-run "$R"; expect_code 2; expect_out "(EF-11)"

tc TC-E71 "merge-base 와 비교한다 — 기준 쪽에서만 바뀐 플러그인은 보지 않는다"
on && { P="$(make_plugin)"; R="$(root_of "$P")"; GIT -C "$R" branch -q work
  agent_fm "$P" "name: order-reviewer
description: 검토"; GIT -C "$R" commit -qam "main moved"; GIT -C "$R" checkout -q work; MAIN="$(GIT -C "$R" rev-parse --abbrev-ref '@{-1}')"; }
run --since "$MAIN" --no-run "$R"; expect_code 0

tc TC-E72 "추적되지 않는 새 파일도 바뀐 것으로 본다"
on && { P="$(make_plugin)"; printf -- '---\nname: order-auditor\ndescription: x\n---\n' > "$P/agents/order-auditor.md"; }
run --since HEAD --no-run "$(root_of "$P")"; expect_code 2; expect_out "(EF-11)"

tc TC-E73 "없는 ref 는 실행 오류다"
on && P="$(make_plugin)"; run --since nope --no-run "$(root_of "$P")"; expect_code 1

echo "== G. 훅 모드 =="

tc TC-E80 "Pre: 무시되는 필드를 가진 에이전트를 쓰려 하면 막는다 (EF-10)"
on && P="$(make_plugin)"
run_stdin "$(PRE "$P/agents/x-reviewer.md" "$(printf -- '---\nname: x-reviewer\ndescription: x\ntools: Read\npermissionMode: plan\n---\n')")"
expect_code 2; expect_out "(EF-10)"

tc TC-E81 "Pre: tools 없는 에이전트를 막는다 (EF-11)"
run_stdin "$(PRE "$P/agents/x-reviewer.md" "$(printf -- '---\nname: x-reviewer\ndescription: x\n---\n')")"
expect_code 2; expect_out "(EF-11)"

tc TC-E82 "Pre: 맞는 에이전트는 조용히 통과한다 · 편집 도구 경고는 내지 않는다 (EF-12)"
run_stdin "$(PRE "$P/agents/x-reviewer.md" "$(printf -- '---\nname: x-reviewer\ndescription: x\ntools: Read, Write\n---\n')")"
expect_code 0; expect_no_out

tc TC-E83 "Pre: Edit 는 보지 않는다"
run_stdin "$(PRE_EDIT "$P/agents/order-reviewer.md")"; expect_code 0; expect_no_out

tc TC-E84 "Pre: hooks.json 의 상대 경로 · Stop matcher 를 막는다 (EF-01 · EF-04)"
run_stdin "$(PRE "$P/hooks/hooks.json" '{"hooks":{"Stop":[{"matcher":"x","hooks":[{"type":"command","command":"./run.sh"}]}]}}')"
expect_code 2; expect_out "(EF-01)"; expect_out "(EF-04)"

tc TC-E85 "Pre: hooks.json 이 아직 없는 스크립트를 가리켜도 막지 않는다 — 파일 둘이 맞아야 하는 조항 (EF-02)"
run_stdin "$(PRE "$P/hooks/hooks.json" '{"hooks":{"PostToolUse":[{"hooks":[{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}/scripts/later.sh\""}]}]}}')"
expect_code 0; expect_no_out

tc TC-E86 "Pre: plugin.json 의 mcpServers 상대 경로를 막는다 (EF-01)"
run_stdin "$(PRE "$P/.claude-plugin/plugin.json" '{"name":"order-sync","mcpServers":{"o":{"command":"node","args":["dist/server.js"]}}}')"
expect_code 2; expect_out "dist/server.js"

tc TC-E87 "Pre: 스킬이 있는 이름으로 커맨드를 · 커맨드가 있는 이름으로 스킬을 만들면 막는다 (EF-13)"
run_stdin "$(PRE "$P/commands/order-create.md" "$(printf -- '---\ndescription: x\n---\n')")"
expect_code 2; expect_out "(EF-13)"
run_stdin "$(PRE "$P/skills/order-validate/SKILL.md" "$(printf -- '---\nname: order-validate\ndescription: x 할 때 사용한다\n---\n')")"
expect_code 2; expect_out "(EF-13)"

tc TC-E88 "Post: 위반을 additionalContext 로 알리고 막지 않는다"
on && agent_fm "$P" "name: order-reviewer
description: 검토"
run_stdin "$(POST "$P/agents/order-reviewer.md")"; expect_code 0; expect_out '"additionalContext"'; expect_out "(EF-11)"
on && printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null || fail_tc "JSON 형식이 아닙니다"

tc TC-E89 "Post: 정합하면 출력이 없다"
on && P="$(make_plugin)"; run_stdin "$(POST "$P/README.md")"; expect_code 0; expect_no_out
run_stdin "$(POST "$P/agents/order-reviewer.md")"; expect_code 0; expect_no_out

tc TC-E90 "플러그인 밖 경로 · 빈 stdin · 경로 없는 입력은 무시한다"
run_stdin "$(PRE "$TMP/agents/x.md" "$(printf -- '---\nname: x\n---\n')")"; expect_code 0; expect_no_out
run_stdin ""; expect_code 0; expect_no_out
run_stdin '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{}}'; expect_code 0; expect_no_out

echo "== H. CLI =="

tc TC-E95 "--all 이 플러그인을 하나도 못 찾으면 실행 오류다"
on && mkdir -p "$TMP/empty"; run --all "$TMP/empty"; expect_code 1

tc TC-E96 "없는 디렉터리는 실행 오류다"
run "$TMP/nope"; expect_code 1

tc TC-E97 "여러 경로를 받고, 위반 출력에 규칙 원본 경로를 적는다"
on && { P="$(make_plugin)"; Q="$(make_plugin)"; agent_fm "$Q" "name: order-reviewer
description: 검토"; }
run "$P" "$Q"; expect_code 2; expect_out "(EF-11)"; expect_out "references/enforcement-effectiveness-rules.md"

tc TC-E98 "루트가 .claude/worktrees/ 안이어도 검사한다"
on && { P="$(make_plugin)"; W="$TMP/wt/.claude/worktrees/1-x"; mkdir -p "$W"; mv "$(root_of "$P")/internal-plugins" "$W/"
  agent_fm "$W/internal-plugins/order-sync" "name: order-reviewer
description: 검토"; }
run --all --no-run "$W"; expect_code 2; expect_out "(EF-11)"

echo "== I. 구성요소를 하나씩 뺀 플러그인 =="

tc TC-E99a "plugin.json 만 있는 플러그인은 통과한다"
on && { P="$(make_plugin)"; find "$P" -mindepth 1 -maxdepth 1 ! -name .claude-plugin -exec rm -rf {} +
  printf '{ "name": "order-sync", "version": "0.1.0", "description": "주문" }' > "$P/.claude-plugin/plugin.json"; }
run "$P"; expect_code 0; expect_no_out

tc TC-E99b "훅 · hook 케이스가 없으면 훅 조항을 보지 않는다 (EF-01 · EF-07 · EF-30)"
on && { P="$(make_plugin)"; rm -rf "$P/hooks" "$P/evals/blocked"; printf '#!/bin/sh\n' > "$P/scripts/validate-order.sh"; }
run --since HEAD "$(root_of "$P")"; expect_code 0; expect_no_out

tc TC-E99c "스킬 · trigger 케이스가 없으면 스킬 조항을 보지 않는다 (EF-13 · EF-30 · EF-31)"
on && { P="$(make_plugin)"; rm -rf "$P/skills" "$P/evals/fired"; }
run "$P"; expect_code 0; expect_no_out

tc TC-E99d "에이전트가 없으면 에이전트 조항을 보지 않는다 (EF-10 · EF-11)"
on && { P="$(make_plugin)"; rm -rf "$P/agents"; }
run "$P"; expect_code 0; expect_no_out

tc TC-E99e "MCP 서버가 없으면 MCP 조항을 보지 않는다 (EF-21 · EF-22)"
on && { P="$(make_plugin)"; jq 'del(.mcpServers)' "$P/.claude-plugin/plugin.json" > "$TMP/pj" && mv "$TMP/pj" "$P/.claude-plugin/plugin.json"; }
run --all "$(root_of "$P")"; expect_code 0; expect_no_out

tc TC-E99f "규칙 원본 · test 가 없으면 조항 연결을 보지 않는다 (EF-05 · EF-06)"
on && { P="$(make_plugin)"; rm -rf "$P/references" "$P/test"; }
run "$P"; expect_code 0; expect_no_out

tc TC-E99g ".mcp.json 의 서버도 본다 (EF-01)"
on && { P="$(make_plugin)"; printf '{"mcpServers":{"x":{"command":"bin/x"}}}' > "$P/.mcp.json"; }
run "$P"; expect_code 2; expect_out "mcpServers.x"

flush_tc
echo
echo "통과 $PASS / 실패 $FAIL$( [ "$SKIP" -gt 0 ] && echo " / 건너뜀 $SKIP")"
[ "$FAIL" = 0 ]
