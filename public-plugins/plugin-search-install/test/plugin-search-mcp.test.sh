#!/usr/bin/env bash
# plugin-search-mcp.sh 회귀 테스트 — stdio JSON-RPC 대화. 사용: test/plugin-search-mcp.test.sh [TC 접두사]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
M="$PLUGIN/scripts/plugin-search-mcp.sh"
FILTER="${1:-}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0

tc() { # $1=ID $2=설명 $3...=명령 (0 이면 통과)
  local id="$1" desc="$2"; shift 2
  case "$id" in "$FILTER"*) ;; *) return ;; esac
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %-7s %s\n' "$id" "$desc"
  else FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %-7s %s\n' "$id" "$desc"; fi
}

# ---- 픽스처: 카탈로그 주입 · 스텁 claude ------------------------------------
mk() { # $1=이름 $2=설명 $3=설치 $4=태그 $5=분류
  jq -cn --arg n "$1" --arg d "$2" --argjson i "$3" --arg t "$4" --arg c "${5:-public}" '
    {id: ($n + "@m"), name: $n, marketplace: "m", description: $d, version: "1.0.0", category: $c,
     tags: ($t | split(",") | map(select(length > 0))), domains: [], technologies: ($t | split(",") | map(select(. == "spring"))),
     tagNotes: [], tagInfo: [], keywords: [], author: null, homepage: null, sourceType: "path", dependencies: [],
     installed: $i, enabled: (if $i then true else null end), scopes: (if $i then ["user"] else [] end), installedVersion: null,
     installedElsewhere: [], installCount: null, componentsKnown: true,
     components: {skills: [], commands: [], agents: [], hooks: [], mcp: [], lsp: []}, path: null}'
}
{ mk alpha-naming "코드 이름 규칙" false development
  mk beta-coverage "테스트 커버리지 게이트" true development,spring
  mk inner-tool "내부 도구 naming" false development internal
} | jq -s . > "$WORK/cat.json"
mkdir -p "$WORK/bin" "$WORK/proj/.claude"
cat > "$WORK/bin/claude" <<'EOF'
#!/usr/bin/env bash
case "$*" in "plugin install "*) echo "$PWD :: $*" >> "$STUB_CALLS"; echo '{"ok":true}' ;; *) exit 1 ;; esac
EOF
chmod +x "$WORK/bin/claude"
echo '{"enabledPlugins":{"alpha-naming@m":true}}' > "$WORK/proj/.claude/settings.json"
export PLUGIN_SEARCH_CATALOG="$WORK/cat.json" PLUGIN_SEARCH_MARKETPLACE=m PLUGIN_SEARCH_CLAUDE="$WORK/bin/claude" \
       PLUGIN_SEARCH_CACHE_DIR="$WORK/cache" STUB_CALLS="$WORK/calls" CLAUDE_PROJECT_DIR="$WORK/proj"

# 메시지를 줄마다 보내고 응답을 받는다
talk() { printf '%s\n' "$@" | "$M"; }
call() { # $1=id $2=도구 $3=인자 JSON
  printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}' "$1" "$2" "$3"
}
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
resp() { talk "$INIT" "$@" | sed -n 2p; }                       # 초기화 다음 응답 하나
text() { resp "$@" | jq -r '.result.content[0].text'; }         # 도구 결과의 텍스트
okjq() { local f="$1"; shift; "$@" | jq -e "$f"; }

echo "== 수명 주기"
tc TC-M01 "initialize — 요청한 프로토콜 버전 · 서버 이름 · tools 능력" okjq '.result.protocolVersion == "2025-06-18" and .result.serverInfo.name == "plugin-search" and .result.capabilities.tools != null' talk "$INIT"
tc TC-M02 "모르는 프로토콜 버전이면 서버가 아는 최신으로" okjq '.result.protocolVersion == "2025-06-18"' talk '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"1999-01-01"}}'
tc TC-M03 "알림(notifications/initialized)에는 답하지 않는다" bash -c '[ -z "$(echo "$1" | "$0")" ]' "$M" '{"jsonrpc":"2.0","method":"notifications/initialized"}'
tc TC-M04 "ping 은 빈 결과" okjq '.result == {}' resp '{"jsonrpc":"2.0","id":2,"method":"ping"}'
tc TC-M05 "문자열 id 를 그대로 돌려준다" okjq '.id == "abc"' resp '{"jsonrpc":"2.0","id":"abc","method":"ping"}'
tc TC-M06 "stdout 의 모든 줄이 JSON-RPC 응답이다" bash -c 'printf "%s\n" "$1" "$2" "$3" | "$0" | jq -e -s "all(.[]; .jsonrpc == \"2.0\")"' "$M" "$INIT" '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' "$(call 3 search_plugins '{"query":"naming"}')"
tc TC-M07 "stdin 이 끝나면 0 으로 끝난다" bash -c 'echo "$1" | "$0" >/dev/null' "$M" "$INIT"

echo "== 오류"
tc TC-M11 "JSON 이 아니면 -32700 (id null)" okjq '.id == null and .error.code == -32700' talk 'not json'
tc TC-M12 "모르는 메서드는 -32601" okjq '.error.code == -32601' resp '{"jsonrpc":"2.0","id":2,"method":"resources/list"}'
tc TC-M13 "모르는 도구는 -32602" okjq '.error.code == -32602' resp "$(call 2 nope '{}')"
tc TC-M14 "필수 인자가 없으면 -32602" okjq '.error.code == -32602 and (.error.message | test("plugins"))' resp "$(call 2 install_plugins '{}')"
tc TC-M15 "엔진 오류(잘못된 정규식)는 isError 결과로" okjq '.result.isError == true and (.result.content[0].text | test("정규식"))' resp "$(call 2 search_plugins '{"query":"/[x/"}')"

echo "== 도구"
tc TC-M21 "tools/list 는 도구 6개, 모두 object 입력 스키마" okjq '(.result.tools | length) == 6 and all(.result.tools[]; .inputSchema.type == "object")' resp '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
tc TC-M22 "조회 도구는 readOnlyHint" okjq '[.result.tools[] | select(.annotations.readOnlyHint) | .name] | length == 5' resp '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
tc TC-M23 "search_plugins — 질의 문법 그대로" okjq '.results[0].id == "alpha-naming@m"' text "$(call 2 search_plugins '{"query":"naming"}')"
tc TC-M24 "search_plugins — internal 은 나오지 않는다" okjq 'all(.results[]; .id != "inner-tool@m")' text "$(call 2 search_plugins '{"query":"naming"}')"
tc TC-M25 "search_plugins — technology · installed 필터" okjq '[.results[].id] == ["beta-coverage@m"]' text "$(call 2 search_plugins '{"technology":"spring","installed":true}')"
tc TC-M26 "list_related_plugins" okjq '.mode == "plugin" and (.results | type) == "array"' text "$(call 2 list_related_plugins '{"target":"alpha-naming"}')"
tc TC-M27 "list_project_plugins — 기본은 CLAUDE_PROJECT_DIR" okjq 'any(.results[]; .id == "alpha-naming@m" and .group == "declared")' text "$(call 2 list_project_plugins '{}')"
tc TC-M28 "get_plugin" okjq '.id == "beta-coverage@m"' text "$(call 2 get_plugin '{"name":"beta-coverage"}')"
tc TC-M29 "list_plugin_facets technology" okjq '.technology[0].value == "spring"' text "$(call 2 list_plugin_facets '{"field":"technology"}')"
rm -f "$WORK/calls"
tc TC-M30 "install_plugins 는 기본 dry-run — 설치하지 않는다" bash -c 'out="$(printf "%s\n" "$1" "$2" | "$0" | sed -n 2p | jq -r ".result.content[0].text")"; jq -e ".mode == \"dry-run\" and .results[0].status == \"planned\"" <<<"$out" && [ ! -e "$3" ]' "$M" "$INIT" "$(call 2 install_plugins '{"plugins":["alpha-naming"]}')" "$WORK/calls"
tc TC-M31 "dry_run=false 면 프로젝트 디렉터리에서 project 범위로 설치" bash -c 'printf "%s\n" "$1" "$2" | "$0" >/dev/null; grep -qx "$4 :: plugin install alpha-naming@m --scope project --json" "$3"' "$M" "$INIT" "$(call 2 install_plugins '{"plugins":["alpha-naming"],"dry_run":false}')" "$WORK/calls" "$WORK/proj"
tc TC-M32 "대상 밖(internal) 설치는 isError, 아무것도 설치하지 않는다" bash -c 'rm -f "$3"; printf "%s\n" "$1" "$2" | "$0" | sed -n 2p | jq -e ".result.isError" && [ ! -e "$3" ]' "$M" "$INIT" "$(call 2 install_plugins '{"plugins":["inner-tool"],"dry_run":false}')" "$WORK/calls"
tc TC-M33 "인자에 따옴표 · 공백 · \$() 가 있어도 명령으로 실행하지 않는다" okjq '.results == [] or (.results | type) == "array"' text "$(call 2 search_plugins '{"query":"a \"b $(touch /tmp/psi-mcp-pwned) `id`"}')"
tc TC-M34 "주입 시도로 파일이 만들어지지 않았다" bash -c '[ ! -e /tmp/psi-mcp-pwned ]'

echo
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]
