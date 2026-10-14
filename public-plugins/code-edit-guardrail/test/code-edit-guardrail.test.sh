#!/usr/bin/env bash
# scripts/code-edit-guardrail.sh 의 회귀 테스트. TC 명세는 test/README.md.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/code-edit-guardrail.sh"
TMP="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/code-edit-guardrail-tc.XXXXXX")" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/state"; mkdir -p "$TMPDIR"
unset CODE_EDIT_GUARDRAIL_CONFIG

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-7s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-7s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/          /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; make_repo; else TC_ON=0; fi
}
section() { flush_tc; echo "── $1"; }
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '          ↳ %s\n' "$1"; TC_FAILED=1; }
hook() { # $1=모드 $2=입력 JSON
  [ "$TC_ON" = 1 ] || return 0
  OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="${PROJECT:-$REPO}" "$SCRIPT" "$1" 2>&1)"; CODE=$?
}
validate() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" validate "$REPO" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다"; }

# ID 로 거른 TC 도 인자를 펼치므로 make_repo 전에 값을 둔다
REPO="$TMP/repo"; PROJECT=""; EDITS="$REPO/.claude/code-edit-guardrail/tc.edits"; ACK="$REPO/.claude/code-edit-guardrail/tc.ack"
S='{"session_id":"tc"}'
ACTIVE='{"session_id":"tc","stop_hook_active":true}'
edit() { # $1=루트 기준 경로 — PostToolUse 기록
  hook track "{\"session_id\":\"tc\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$REPO/$1\"}}"
}
pre() { # $1=루트 기준 경로 $2=새 내용
  hook shared "$(jq -nc --arg f "$REPO/$1" --arg c "${2:-x}" '{session_id:"tc",tool_name:"Write",tool_input:{file_path:$f,content:$c}}')"
}
config() { [ "$TC_ON" = 1 ] || return 0; printf '%s\n' "$1" > "$REPO/.claude/code-edit-guardrail.json"; }

# --- 픽스처: 두 스택(루트 Kotlin + web/ TypeScript)과 공유자원이 있는 저장소. 설정은 모든 절을 갖는다
FULL='{
  "test": { "code": ["src/main/**", "web/src/**/*.ts", "!**/generated/**"], "tests": ["src/test/", "*.test.ts"] },
  "quality": [
    { "name": "api", "paths": ["src/**"], "command": "test ! -e api.fail || { echo api-lint-broken; exit 3; }" },
    { "name": "web", "paths": ["web/"], "command": "touch web.ran; test ! -e web.fail" }
  ],
  "shared": { "paths": ["db/migration/", "*.proto"], "content": ["DROP[[:space:]]+TABLE"] }
}'
make_repo() {
  REPO="$TMP/repo"; PROJECT=""; rm -rf "$REPO" "$TMPDIR"; mkdir -p "$TMPDIR" "$REPO/.claude"
  EDITS="$REPO/.claude/code-edit-guardrail/tc.edits"; ACK="$REPO/.claude/code-edit-guardrail/tc.ack"
  cd "$REPO" || exit 1
  git init -q . && git config user.email tc@example.com && git config user.name tc
  mkdir -p src/main/kotlin/order src/main/kotlin/generated src/test/kotlin web/src db/migration api
  echo 'class Order' > src/main/kotlin/order/Order.kt
  echo 'class Gen' > src/main/kotlin/generated/Gen.kt
  echo 'class OrderTest' > src/test/kotlin/OrderTest.kt
  echo 'export const a = 1' > web/src/cart.ts
  echo 'test' > web/src/cart.test.ts
  echo 'create table t;' > db/migration/V1.sql
  echo 'syntax = "proto3";' > api/order.proto
  printf '%s\n' "$FULL" > .claude/code-edit-guardrail.json
}

section "A. 테스트 동반 (G-01)"
tc TC-A01 "코드만 고치면 막는다"
edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 2; expect_out "G-01"; expect_out "src/main/kotlin/order/Order.kt"; expect_out "$ACK"
tc TC-A02 "코드와 테스트를 같이 고치면 통과한다"
edit src/main/kotlin/order/Order.kt; edit src/test/kotlin/OrderTest.kt; hook stop "$S"
expect_code 0; expect_not "G-01"
tc TC-A03 "테스트만 고치면 통과한다"
edit src/test/kotlin/OrderTest.kt; hook stop "$S"
expect_code 0
tc TC-A04 "! 로 뺀 생성 코드만 고치면 통과한다"
edit src/main/kotlin/generated/Gen.kt; hook stop "$S"
expect_code 0; expect_not "G-01"
tc TC-A05 "테스트 글롭이 코드 글롭을 이긴다 — web/src 의 .test.ts 는 테스트다"
edit web/src/cart.test.ts; hook stop "$S"
expect_code 0; expect_not "G-01"
tc TC-A06 "두 번째 스택(web)의 코드만 고쳐도 막는다"
edit web/src/cart.ts; hook stop "$S"
expect_code 2; expect_out "web/src/cart.ts"
tc TC-A07 "사유를 남기면 면제한다"
edit src/main/kotlin/order/Order.kt; [ "$TC_ON" = 1 ] && echo 'test: 포맷만 바꿈' > "$ACK"; hook stop "$S"
expect_code 0
tc TC-A08 "사유가 빈 test: 는 면제가 아니다"
edit src/main/kotlin/order/Order.kt; [ "$TC_ON" = 1 ] && echo 'test:  ' > "$ACK"; hook stop "$S"
expect_code 2; expect_out "G-01"
tc TC-A09 "한 번 되돌린 뒤(stop_hook_active)에는 경고만 한다"
edit src/main/kotlin/order/Order.kt; hook stop "$ACTIVE"
expect_code 0; expect_out '"systemMessage"'; expect_out "⚠️"; expect_out "G-01"
tc TC-A10 "새 요청(reset)이면 지난 편집 · 면제를 잊는다"
edit src/main/kotlin/order/Order.kt; [ "$TC_ON" = 1 ] && echo 'test: x' > "$ACK"; hook reset "$S"
[ "$TC_ON" = 1 ] && { [ -e "$EDITS" ] || [ -e "$ACK" ]; } && fail_tc "기록 · 면제가 남았다"
hook stop "$S"; expect_code 0; expect_no_out
tc TC-A11 "편집이 없는 요청은 막지 않는다"
hook stop "$S"; expect_code 0; expect_no_out
tc TC-A13 "면제 파일은 프로젝트 안에 있고 git status 에 나오지 않는다"
edit src/main/kotlin/order/Order.kt; hook stop "$S"; expect_out "$ACK"
[ "$TC_ON" = 1 ] && git -C "$REPO" status --porcelain | grep -q 'code-edit-guardrail/' && fail_tc "상태 디렉터리가 git status 에 나온다"
true
tc TC-A12 "test 절이 없으면 G-01 을 보지 않는다"
config '{"shared":{"paths":["db/migration/"]}}'; edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 0; expect_no_out

section "B. 품질 lane (G-02)"
tc TC-B01 "고친 경로의 lane 이 실패하면 출력과 함께 막는다"
[ "$TC_ON" = 1 ] && touch "$REPO/api.fail"
edit src/test/kotlin/OrderTest.kt; hook stop "$S"
expect_code 2; expect_out "G-02"; expect_out "'api'"; expect_out "종료 코드 3"; expect_out "api-lint-broken"
tc TC-B02 "고친 경로의 lane 이 통과하면 통과한다"
edit web/src/cart.ts; edit web/src/cart.test.ts; hook stop "$S"
expect_code 0
[ "$TC_ON" = 1 ] && [ ! -e "$REPO/web.ran" ] && fail_tc "web lane 이 돌지 않았다"
tc TC-B03 "경로가 안 걸린 lane 은 돌리지 않는다"
[ "$TC_ON" = 1 ] && touch "$REPO/api.fail"
edit web/src/cart.ts; edit web/src/cart.test.ts; hook stop "$S"
expect_code 0; expect_not "'api'"
tc TC-B04 "lane 명령은 프로젝트 루트에서 돈다"
config '{"quality":[{"name":"root","paths":["web/"],"command":"test -f .claude/code-edit-guardrail.json"}]}'
edit web/src/cart.ts; hook stop "$S"
expect_code 0
tc TC-B05 "G-01 과 G-02 를 한 번에 알린다"
[ "$TC_ON" = 1 ] && touch "$REPO/web.fail"
edit web/src/cart.ts; hook stop "$S"
expect_code 2; expect_out "G-01"; expect_out "'web'"
tc TC-B06 "한 번 되돌린 뒤에는 lane 실패도 경고만 한다"
[ "$TC_ON" = 1 ] && touch "$REPO/web.fail"
edit web/src/cart.test.ts; hook stop "$ACTIVE"
expect_code 0; expect_out '"systemMessage"'; expect_out "'web'"

tc TC-B07 "lane 명령이 stdin 을 읽어도 뒤 lane 이 돈다"
config '{"quality":[{"name":"reader","paths":["web/"],"command":"cat >/dev/null"},{"name":"after","paths":["web/"],"command":"touch after.ran"}]}'
edit web/src/cart.ts; hook stop "$S"
expect_code 0
[ "$TC_ON" = 1 ] && [ ! -e "$REPO/after.ran" ] && fail_tc "뒤 lane 이 돌지 않았다"
true
tc TC-B08 "여러 줄 command 는 끝까지 돈다"
config '{"quality":[{"name":"multi","paths":["web/"],"command":"true\nexit 3"}]}'
edit web/src/cart.ts; hook stop "$S"
expect_code 2; expect_out "종료 코드 3"

section "C. 공유자원 (G-03)"
tc TC-C01 "공유 디렉터리 아래 파일은 사용자 확인으로 돌린다"
pre db/migration/V1.sql "alter"
expect_code 0; expect_out '"permissionDecision": "ask"'; expect_out "G-03"; expect_out "db/migration/V1.sql"
tc TC-C02 "아직 없는 하위 디렉터리에 새 파일을 만들어도 잡는다"
pre db/migration/v2/V2.sql "x"
expect_out '"permissionDecision": "ask"'
tc TC-C03 "/ 없는 글롭(*.proto)은 어느 깊이든 잡는다"
pre api/order.proto "x"
expect_out "api/order.proto"
tc TC-C04 "내용 패턴에 걸리면 경로와 무관하게 잡는다"
pre src/main/kotlin/order/Order.kt "DROP  TABLE orders"
expect_out '"permissionDecision": "ask"'; expect_out "내용 /DROP"
tc TC-C05 "Edit 의 new_string 과 MultiEdit 의 edits 도 본다"
hook shared "$(jq -nc --arg f "$REPO/src/a.kt" '{session_id:"tc",tool_name:"MultiEdit",tool_input:{file_path:$f,edits:[{old_string:"a",new_string:"DROP TABLE x"}]}}')"
expect_out "G-03"
tc TC-C06 "공유자원이 아니면 아무것도 출력하지 않는다"
pre src/main/kotlin/order/Order.kt "class Order2"
expect_code 0; expect_no_out
tc TC-C07 "shared 절이 없으면 보지 않는다"
config '{"test":{"code":["src/"],"tests":["test/"]}}'; pre db/migration/V1.sql "DROP TABLE x"
expect_code 0; expect_no_out

section "D. 편집 기록"
tc TC-D01 "프로젝트 밖 파일은 기록하지 않는다"
hook track '{"session_id":"tc","tool_input":{"file_path":"/etc/hosts"}}'
[ "$TC_ON" = 1 ] && [ -s "$EDITS" ] && fail_tc "밖 파일이 기록됐다"
true
tc TC-D02 "심볼릭 링크로 들어온 프로젝트 경로도 알아본다"
if [ "$TC_ON" = 1 ]; then ln -s "$REPO" "$TMP/link"; PROJECT="$TMP/link"; fi
hook track "{\"session_id\":\"tc\",\"tool_input\":{\"file_path\":\"$TMP/link/src/main/kotlin/order/Order.kt\"}}"
hook stop "$S"; expect_code 2; expect_out "src/main/kotlin/order/Order.kt"
[ "$TC_ON" = 1 ] && rm -f "$TMP/link"
tc TC-D03 "설정이 없으면 기록 · 판정을 하지 않는다"
[ "$TC_ON" = 1 ] && rm -f "$REPO/.claude/code-edit-guardrail.json"
edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 0; expect_no_out
[ "$TC_ON" = 1 ] && [ -e "$EDITS" ] && fail_tc "설정 없이 기록했다"
tc TC-D04 "설정이 깨져 있으면 훅은 조용히 통과한다"
config '{ broken'; edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 0; expect_no_out
tc TC-D06 "상태 디렉터리(면제 파일)를 고친 것은 편집으로 기록하지 않는다"
hook track "{\"session_id\":\"tc\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO/.claude/code-edit-guardrail/tc.ack\"}}"
[ "$TC_ON" = 1 ] && [ -s "$EDITS" ] && fail_tc "상태 파일이 기록됐다"
true
tc TC-D07 "들어갈 수 없는 프로젝트면 훅은 막지 않고 validate 만 실패한다"
if [ "$TC_ON" = 1 ]; then
  for m in reset track shared stop; do
    OUT="$(printf '%s' "$S" | CLAUDE_PROJECT_DIR="$TMP/nope" "$SCRIPT" "$m" 2>&1)"; CODE=$?; expect_code 0; expect_no_out
  done
  OUT="$("$SCRIPT" validate "$TMP/nope" 2>&1)"; CODE=$?; expect_code 2
fi
tc TC-D05 "CODE_EDIT_GUARDRAIL_CONFIG 로 설정 경로를 바꾼다"
if [ "$TC_ON" = 1 ]; then mv "$REPO/.claude/code-edit-guardrail.json" "$REPO/guard.json"; export CODE_EDIT_GUARDRAIL_CONFIG=guard.json; fi
edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 2; expect_out "G-01"
unset CODE_EDIT_GUARDRAIL_CONFIG

section "E. 설정 검증 (validate)"
tc TC-E01 "모든 절을 지킨 설정은 통과한다 — 경고 없음"
validate; expect_code 0; expect_out "✅"; expect_out "quality 2 lane"; expect_not "C-05"
tc TC-E02 "설정 파일이 없으면 막는다 (C-01)"
[ "$TC_ON" = 1 ] && rm -f "$REPO/.claude/code-edit-guardrail.json"
validate; expect_code 2; expect_out "C-01"
tc TC-E03 "JSON 이 깨지면 막는다 (C-01)"
config '{ broken'; validate; expect_code 2; expect_out "C-01"
tc TC-E04 "알 수 없는 최상위 키를 막는다 (C-02)"
config '{"tests":{"code":["src/"],"tests":["x"]}}'; validate; expect_code 2; expect_out "C-02"; expect_out "'tests'"
tc TC-E05 "test 에 tests 가 없으면 막는다 (C-03)"
config '{"test":{"code":["src/"]}}'; validate; expect_code 2; expect_out "test.tests"
tc TC-E06 "lane name 이 kebab-case 가 아니거나 겹치면 막는다 (C-03)"
config '{"quality":[{"name":"Web","paths":["web/"],"command":"x"},{"name":"a","paths":["web/"],"command":"x"},{"name":"a","paths":["web/"],"command":"x"}]}'
validate; expect_code 2; expect_out "quality[0].name"; expect_out "'a' 이 겹친다"
tc TC-E07 "lane 에 command 가 없거나 알 수 없는 키가 있으면 막는다 (C-03)"
config '{"quality":[{"name":"web","paths":["web/"],"cmd":"x"}]}'; validate; expect_code 2; expect_out "quality[0].command"; expect_out "'cmd'"
tc TC-E08 "shared 에 paths · content 가 모두 없으면 막는다 (C-03)"
config '{"shared":{}}'; validate; expect_code 2; expect_out "paths · content 중 하나"
tc TC-E09 "올바르지 않은 정규식을 막는다 (C-04)"
config '{"shared":{"content":["DROP (TABLE"]}}'; validate; expect_code 2; expect_out "C-04"
tc TC-E10 "걸리는 파일이 없는 글롭은 경고만 한다 (C-05)"
config '{"test":{"code":["src/main/**","lib/**"],"tests":["src/test/","!x/**"]}}'
validate; expect_code 0; expect_out "C-05"; expect_out "'lib/**'"; expect_not "'!x/**'"

section "F. 글롭"
tc TC-F01 "* 는 / 를 넘지 않는다"
config '{"test":{"code":["src/*.kt"],"tests":["zzz/"]}}'; edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 0
tc TC-F02 "/ 로 시작하는 글롭은 루트 기준이다"
config '{"test":{"code":["/Order.kt"],"tests":["zzz/"]}}'; edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 0
tc TC-F03 "끝 / 는 그 디렉터리 아래 전부다 — 어느 깊이든"
config '{"test":{"code":["order/"],"tests":["zzz/"]}}'; edit src/main/kotlin/order/Order.kt; hook stop "$S"
expect_code 2
tc TC-F04 "점 · 괄호 같은 정규식 문자는 글자 그대로다"
config '{"test":{"code":["src/main/kotlin/order/Order.kt"],"tests":["zzz/"]}}'
edit src/main/kotlin/order/OrderXkt; hook stop "$S"
expect_code 0

flush_tc
echo
echo "통과 $PASS · 실패 $FAIL · 건너뜀 $SKIP"
[ "$FAIL" = 0 ]
