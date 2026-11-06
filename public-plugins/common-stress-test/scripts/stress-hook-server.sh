#!/usr/bin/env bash
# 훅 판정을 stdio MCP 도구로 낸다 — 디렉터리가 command 훅을 받지 않아 hooks.json 이 mcp_tool 로 부른다.
#
#   stress_target_validate  PreToolUse(Bash)        ST-01 위반 · 실행 오류면 deny
#   stress_script_validate  PostToolUse(Write|Edit) ST-02 ~ ST-06 알림을 그대로 넘긴다
#
# 도구 인자는 훅 입력의 tool_name · hook_event_name · cwd 와 JSON 문자열 tool_input 이다.
set -uo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_DIR" ]; then
  SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
  PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
fi
export CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"

reply() { jq -cn --argjson id "$1" --argjson r "$2" '{jsonrpc:"2.0",id:$id,result:$r}'; }
text_result() { jq -cn --arg t "$1" '{content:[{type:"text",text:$t}]}'; }
deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
}

TOOLS='[
 {"name":"stress_target_validate","description":"ST-01: block load tools aimed at hosts outside the allow list","inputSchema":{"type":"object","properties":{"tool_name":{"type":"string"},"hook_event_name":{"type":"string"},"cwd":{"type":"string"},"tool_input":{"type":"string"}}}},
 {"name":"stress_script_validate","description":"ST-02 to ST-06: report measurement design of a saved load script","inputSchema":{"type":"object","properties":{"tool_name":{"type":"string"},"hook_event_name":{"type":"string"},"cwd":{"type":"string"},"tool_input":{"type":"string"}}}}
]'

# 도구 인자 → 기존 훅 스크립트의 stdin
hook_input() {
  printf '%s' "$1" | jq -c '{tool_name, hook_event_name, cwd, tool_input: ((.tool_input // "{}") | (fromjson? // {}))}'
}

call_tool() {
  local name="$1" input out rc
  input=$(hook_input "$2")
  case "$name" in
    stress_target_validate)
      # 통과는 출력 없이 0 이라 stderr 를 합쳐 받아도 차단 사유만 남는다
      out=$(printf '%s' "$input" | "$PLUGIN_DIR/scripts/stress-target-validate.sh" 2>&1); rc=$?
      case "$rc" in
        0) ;;
        2) deny "$out" ;;
        *) deny "stress-target-validate 실행 오류(종료 $rc)로 막는다: $out" ;;
      esac ;;
    stress_script_validate)
      out=$(printf '%s' "$input" | "$PLUGIN_DIR/scripts/stress-script-validate.sh" 2>/dev/null); rc=$?
      [ "$rc" = 0 ] && printf '%s' "$out" ;;
  esac
}

while IFS= read -r line; do
  [ -n "$line" ] || continue
  id=$(printf '%s' "$line" | jq -c '.id // empty' 2>/dev/null)
  method=$(printf '%s' "$line" | jq -r '.method // empty' 2>/dev/null)
  [ -n "$id" ] || continue
  case "$method" in
    initialize)
      ver=$(printf '%s' "$line" | jq -r '.params.protocolVersion // "2025-06-18"')
      reply "$id" "$(jq -cn --arg v "$ver" '{protocolVersion:$v,capabilities:{tools:{}},serverInfo:{name:"stress-hook",version:"1"}}')" ;;
    ping) reply "$id" '{}' ;;
    tools/list) reply "$id" "$(jq -cn --argjson t "$TOOLS" '{tools:$t}')" ;;
    tools/call)
      name=$(printf '%s' "$line" | jq -r '.params.name // empty')
      args=$(printf '%s' "$line" | jq -c '.params.arguments // {}')
      reply "$id" "$(text_result "$(call_tool "$name" "$args")")" ;;
    *) jq -cn --argjson id "$id" '{jsonrpc:"2.0",id:$id,error:{code:-32601,message:"method not found"}}' ;;
  esac
done
