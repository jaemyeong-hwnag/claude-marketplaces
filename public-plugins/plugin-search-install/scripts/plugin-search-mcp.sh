#!/usr/bin/env bash
# plugin-search-mcp — plugin-search-install 엔진을 MCP 도구로 내놓는 로컬 stdio 서버.
# 한 줄에 JSON-RPC 메시지 하나를 읽고 쓴다. stdout 에는 응답만 쓴다.
#
#   plugin.json 의 mcpServers 로 Claude Code 가 띄운다. 직접 붙이려면:
#   claude mcp add plugin-search -- <이 파일 경로>
#
# 환경  CLAUDE_PROJECT_DIR (없으면 현재 디렉터리) — 프로젝트 조회 · project 범위 설치의 기준
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$HERE/plugin-search-install.sh"
VERSION="$(jq -r '.version // "0"' "$HERE/../.claude-plugin/plugin.json" 2>/dev/null || echo 0)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROTOCOLS='["2025-06-18", "2025-03-26", "2024-11-05"]'

command -v jq >/dev/null 2>&1 || { echo "plugin-search-mcp: jq 가 필요합니다" >&2; exit 1; }

# jq 1.6 의 -e 는 입력이 비어 있으면 성공한다 — 출력이 정확히 true 인지 본다
jq_true() { local out; out="$(jq "$@" 2>/dev/null)" && [ "$out" = true ]; }
send() { printf '%s\n' "$1"; }
reply() { send "$(jq -cn --argjson id "$1" --argjson r "$2" '{jsonrpc: "2.0", id: $id, result: $r}')"; }
fail() { send "$(jq -cn --argjson id "$1" --argjson c "$2" --arg m "$3" '{jsonrpc: "2.0", id: $id, error: {code: $c, message: $m}}')"; }

read -r -d '' TOOLS <<'JSON'
[
  { "name": "search_plugins",
    "description": "이 마켓의 public 플러그인을 기능으로 검색한다. query 문법: 단어 · 필드:값(name · tag · domain · tech · kw · desc · skill · cmd · agent · hook · mcp) · -제외 · a|b · /정규식/ · has:종류 · is:installed · dep:이름. 동의어 · 한글 조사 · 오타를 허용한다.",
    "inputSchema": { "type": "object", "properties": {
      "query": { "type": "string", "description": "검색어 (예: \"테스트 커버리지\", \"naming has:hook -java\")" },
      "tags": { "type": "array", "items": { "type": "string" }, "description": "이 태그 중 하나가 있는 것만" },
      "domain": { "type": "string", "description": "domain 태그 (tags.json kind=domain)" },
      "technology": { "type": "string", "description": "technology 태그 (tags.json kind=technology)" },
      "has": { "type": "array", "items": { "enum": ["skill", "command", "agent", "hook", "mcp", "lsp"] }, "description": "이 구성요소를 모두 가진 것만" },
      "installed": { "type": "boolean", "description": "true 면 설치된 것만, false 면 안 된 것만" },
      "any": { "type": "boolean", "description": "단어를 OR 로 (기본 AND)" },
      "exact": { "type": "boolean", "description": "동의어 · 부분 일치 · 오타 허용을 끈다" },
      "sort": { "enum": ["score", "name", "installs"] },
      "limit": { "type": "integer", "minimum": 0, "description": "기본 20, 0 이면 전부" } } },
    "annotations": { "readOnlyHint": true } },
  { "name": "list_related_plugins",
    "description": "플러그인 이름 또는 기능어와 연관된 이 마켓의 public 플러그인을 이유와 함께 낸다 — 의존 · 역의존 · 공유 태그 · 키워드 · 이름 단어 · 구성요소 · 설명.",
    "inputSchema": { "type": "object", "required": ["target"], "properties": {
      "target": { "type": "string", "description": "플러그인 이름(또는 이름@마켓) 또는 기능어" },
      "by": { "type": "array", "items": { "enum": ["dependency", "dependent", "tag", "keyword", "name", "component", "description", "category"] }, "description": "볼 관계 (기본 전부)" },
      "limit": { "type": "integer", "minimum": 0 } } },
    "annotations": { "readOnlyHint": true } },
  { "name": "list_project_plugins",
    "description": "프로젝트에 필요한 이 마켓의 public 플러그인 — 프로젝트 설정에 선언된 것(상태 ok · missing · disabled · off), 그 의존, 파일 신호(언어 · 프레임워크 · CI …)로 추천하는 것.",
    "inputSchema": { "type": "object", "properties": {
      "directory": { "type": "string", "description": "프로젝트 디렉터리 (기본: 현재 프로젝트)" },
      "only": { "enum": ["declared", "missing", "recommended"] } } },
    "annotations": { "readOnlyHint": true } },
  { "name": "get_plugin",
    "description": "이 마켓의 public 플러그인 하나의 상세 — 설명 · 버전 · 태그 · 스킬 · 커맨드 · 에이전트 · 훅 · MCP · 의존 · 역의존 · 설치 상태.",
    "inputSchema": { "type": "object", "required": ["name"], "properties": {
      "name": { "type": "string" } } },
    "annotations": { "readOnlyHint": true } },
  { "name": "list_plugin_facets",
    "description": "이 마켓의 public 플러그인을 관점별로 센다 — tag · domain · technology(설명 포함) · keyword · 구성요소 종류 · 설치 여부. 무엇으로 검색할지 모를 때 먼저 본다.",
    "inputSchema": { "type": "object", "properties": {
      "field": { "enum": ["all", "tag", "domain", "technology", "keyword", "has", "installed"] } } },
    "annotations": { "readOnlyHint": true } },
  { "name": "install_plugins",
    "description": "고른 플러그인을 설치한다. 기본은 계획만 낸다(dry_run=true) — 사용자가 고른 뒤 dry_run=false 로 다시 부른다. 이 마켓의 public 이 아니거나 모호하면 아무것도 설치하지 않는다. 설치 뒤에는 Claude Code 를 다시 시작해야 로드된다.",
    "inputSchema": { "type": "object", "required": ["plugins"], "properties": {
      "plugins": { "type": "array", "items": { "type": "string" }, "minItems": 1, "description": "이름 또는 이름@마켓" },
      "scope": { "enum": ["project", "user", "local"], "description": "기본 project" },
      "dry_run": { "type": "boolean", "description": "기본 true" } } },
    "annotations": { "readOnlyHint": false, "destructiveHint": false } }
]
JSON

# 도구 인자 → 엔진 명령줄 (\x1f 로 구분)
engine_args() { # $1=도구 이름 $2=인자 JSON
  jq -j --arg t "$1" --arg dir "$PROJECT_DIR" '
    def s: tostring | gsub("\u001f"; " ");
    def many($k; $flag): if (.[$k] | type) == "array" and (.[$k] | length) > 0 then $flag, (.[$k] | map(s) | join(",")) else empty end;
    def one($k; $flag): if .[$k] != null and (.[$k] | tostring) != "" then $flag, (.[$k] | s) else empty end;
    def yes($k; $flag): if .[$k] == true then $flag else empty end;
    ( if $t == "search_plugins" then
        "search", (if (.query // "") != "" then (.query | s) else empty end),
        many("tags"; "--tag"), one("domain"; "--domain"), one("technology"; "--technology"), many("has"; "--has"),
        (if .installed == true then "--installed" elif .installed == false then "--not-installed" else empty end),
        yes("any"; "--any"), yes("exact"; "--exact"), one("sort"; "--sort"), one("limit"; "--limit")
      elif $t == "list_related_plugins" then "related", (.target | s), many("by"; "--by"), one("limit"; "--limit")
      elif $t == "list_project_plugins" then "project", (.directory // $dir | s), one("only"; "--only")
      elif $t == "get_plugin" then "show", (.name | s)
      elif $t == "list_plugin_facets" then "facets", (.field // "all" | s)
      elif $t == "install_plugins" then
        "install", (.plugins[] | s), "--scope", (.scope // "project" | s), (if .dry_run == false then empty else "--dry-run" end)
      else empty end ), "--format", "json"
    | . + "\u001f"' <<<"$2"
}

# 모델에게 줄 결과 — 판단에 필요한 칸만
summarize() { # $1=도구 이름, stdin=엔진 JSON
  jq -c --arg t "$1" '
    def item: {rank, id, installed, score, why, description, tags}
      + (if .group then {group, status} else {} end)
      + (if (.componentCounts // null) then {components: (.componentCounts | with_entries(select(.value > 0)))} else {} end);
    if $t == "search_plugins" then {total, relaxed, terms, excluded, filters, results: [.results[] | item]}
    elif $t == "list_related_plugins" then {mode, target, seeds, ambiguous, total, results: [.results[] | item]}
    elif $t == "list_project_plugins" then {root, marketplace, signals: [.signals[] | {id, label: .["label"], evidence}],
      summary, outOfScope, settingsErrors, results: [.results[] | item]}
    else . end'
}

call_tool() { # $1=도구 이름 $2=인자 JSON → result JSON
  local name="$1" argv=() a out code
  while IFS= read -r -d $'\037' a; do argv+=("$a"); done < <(engine_args "$name" "$2")
  out="$(cd "$PROJECT_DIR" 2>/dev/null && "$ENGINE" ${argv+"${argv[@]}"} 2>"$TMP/err")"; code=$?
  if [ $code -eq 2 ] || [ -z "$out" ]; then
    jq -cn --arg m "$(sed 's/^plugin-search-install: //' "$TMP/err" | head -5)" '{content: [{type: "text", text: (if $m == "" then "엔진이 결과를 내지 않았습니다" else $m end)}], isError: true}'
    return
  fi
  jq -cn --arg text "$(printf '%s' "$out" | summarize "$name")" '{content: [{type: "text", text: $text}], isError: false}'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

while IFS= read -r line || [ -n "$line" ]; do
  [ -n "${line//[[:space:]]/}" ] || continue
  if ! jq_true 'type == "object"' <<<"$line"; then fail null -32700 "Parse error"; continue; fi
  id="$(jq -c 'if has("id") and .id != null then .id else empty end' <<<"$line")"
  method="$(jq -r '.method // ""' <<<"$line")"
  [ -n "$id" ] || continue                       # 알림 · 응답에는 답하지 않는다
  case "$method" in
    initialize)
      reply "$id" "$(jq -cn --argjson p "$PROTOCOLS" --arg v "$VERSION" --arg want "$(jq -r '.params.protocolVersion // ""' <<<"$line")" '
        {protocolVersion: (if ($p | index($want)) != null then $want else $p[0] end),
         capabilities: {tools: {listChanged: false}},
         serverInfo: {name: "plugin-search", version: $v},
         instructions: "이 마켓의 public 플러그인을 조회 · 설치한다. 설치는 install_plugins 를 dry_run 으로 먼저 부르고 사용자가 고른 뒤 실행한다."}')" ;;
    ping) reply "$id" '{}' ;;
    tools/list) reply "$id" "$(jq -c '{tools: .}' <<<"$TOOLS")" ;;
    tools/call)
      tname="$(jq -r '.params.name // ""' <<<"$line")"
      targs="$(jq -c '.params.arguments // {} | if type == "object" then . else {} end' <<<"$line")"
      if ! jq_true --arg n "$tname" 'any(.[]; .name == $n)' <<<"$TOOLS"; then
        fail "$id" -32602 "Unknown tool: $tname"; continue
      fi
      missing="$(jq -r --arg n "$tname" --argjson a "$targs" '.[] | select(.name == $n) | (.inputSchema.required // [])[] | select($a[.] == null)' <<<"$TOOLS" | head -1)"
      if [ -n "$missing" ]; then fail "$id" -32602 "Missing argument: $missing"; continue; fi
      reply "$id" "$(call_tool "$tname" "$targs")" ;;
    *) fail "$id" -32601 "Method not found: $method" ;;
  esac
done
exit 0
