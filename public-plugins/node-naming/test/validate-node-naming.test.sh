#!/usr/bin/env bash
# scripts/validate-node-naming.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-node-naming.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/node-naming-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

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
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
run_stdin() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" 2>&1)"; CODE=$?; }
# 프로젝트 디렉터리를 지정해 훅을 부른다
run_stdin_in() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# --- 픽스처 ------------------------------------------------------------------
SRC="$TMP/src"
put() { # $1=상대 경로 $2=내용 → 경로
  mkdir -p "$(dirname "$SRC/$1")"; printf '%b' "$2" > "$SRC/$1"; printf '%s' "$SRC/$1"
}
CLEAN_JS='const MAX_RETRY_COUNT = 3;\nconst dbHost = process.env.ORDER_DB_HOST;\n\nclass OrderService {\n  constructor(orderRepository) {\n    this.orderRepository = orderRepository;\n  }\n}\n\nfunction findOrders(userId) {\n  return [];\n}\n\nmodule.exports = { OrderService, findOrders, MAX_RETRY_COUNT, dbHost };\n'
CLEAN_PKG='{\n  "name": "@acme/order-service",\n  "version": "1.0.0",\n  "scripts": {\n    "build": "tsc",\n    "test:unit": "jest",\n    "build-prod": "tsc -p prod"\n  }\n}\n'
payload_write() { # $1=경로 $2=내용
  jq -n --arg p "$1" --arg c "$(printf '%b' "$2")" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}
payload_edit() { # $1=경로 $2=old $3=new [$4=replace_all]
  jq -n --arg p "$1" --arg o "$(printf '%b' "$2")" --arg n "$(printf '%b' "$3")" --argjson a "${4:-false}" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n, replace_all: $a}}'
}

echo "node-naming 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-N01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-N02 "규칙을 지킨 JS · package.json 은 조용히 통과한다"
f="$(put order-service.js "$CLEAN_JS")"; g="$(put package.json "$CLEAN_PKG")"; run "$f" "$g"; expect_code 0; expect_no_out

tc TC-N03 "package.json name 에 대문자가 있으면 막고 소문자 이름을 제안한다 (ND-01)"
f="$(put p3/package.json '{\n  "name": "My_Order_Service",\n  "version": "1.0.0"\n}\n')"; run "$f"; expect_code 2
expect_out "ND-01"; expect_out "대문자"; expect_out "'my-order-service'"; expect_out "package.json:2:"

tc TC-N04 "name 이 . 이나 _ 로 시작하면 막는다 (ND-01)"
f="$(put p4/package.json '{"name": ".hidden"}')"; run "$f"; expect_code 2; expect_out "ND-01"
f="$(put p4/package.json '{"name": "_private"}')"; run "$f"; expect_code 2; expect_out "'private'"

tc TC-N05 "name 에 URL 에 그대로 쓸 수 없는 문자가 있으면 막는다 (ND-01)"
f="$(put p5/package.json '{"name": "order service"}')"; run "$f"; expect_code 2; expect_out "URL"; expect_out "'order-service'"
f="$(put p5/package.json '{"name": "order~svc!"}')"; run "$f"; expect_code 2; expect_out "URL"
f="$(put p5/package.json '{"name": "@acme/a/b"}')"; run "$f"; expect_code 2; expect_out "@scope/name"

tc TC-N06 "name 이 214자를 넘으면 막는다 (ND-01)"
long="$(printf 'a%.0s' $(seq 1 215))"
f="$(put p6/package.json "{\"name\": \"$long\"}")"; run "$f"; expect_code 2; expect_out "214"

tc TC-N07 "스코프 이름 · 최상위가 아닌 name · 깨진 JSON 은 막지 않는다 (ND-01 과잉 차단 방지)"
f="$(put p7/package.json '{"name": "@acme-corp/order.service_v2", "config": {"name": "Not_Top"}, "workspaces": ["Pkg_A"]}')"; run "$f"; expect_code 0; expect_no_out
f="$(put p7/package.json '{"name": "Bad_Name", ')"; run "$f"; expect_code 0; expect_no_out
f="$(put p7/package.json '{"version": "1.0.0"}')"; run "$f"; expect_code 0; expect_no_out

tc TC-N08 "scripts 키의 camelCase · 밑줄은 경고만 한다 (ND-02)"
f="$(put p8/package.json '{\n  "name": "a",\n  "scripts": {\n    "buildProd": "x",\n    "lint_fix": "y"\n  }\n}\n')"; run "$f"; expect_code 0
expect_out "⚠️"; expect_out "ND-02"; expect_out "'build-prod'"; expect_out "'lint-fix'"; expect_out "package.json:4:"

tc TC-N09 "scripts 키의 : · - 구분과 prepublishOnly 는 통과한다 (ND-02 과잉 차단 방지)"
f="$(put p9/package.json '{"name": "a", "scripts": {"test:unit": "x", "test:e2e:watch": "y", "build-prod": "z", "prepublishOnly": "w", "postinstall": "v"}}')"
run "$f"; expect_code 0; expect_no_out

tc TC-N10 "process.env 의 camelCase 이름을 막고 UPPER_SNAKE_CASE 를 제안한다 (ND-03)"
f="$(put config.js 'const dbHost = process.env.dbHost;\n')"; run "$f"; expect_code 2; expect_out "ND-03"; expect_out "'DB_HOST'"

tc TC-N11 "process.env[\"…\"] · process.env['…'] 도 본다 (ND-03)"
f="$(put config.js "const a = process.env['apiKey'];\nconst b = process.env[\"db-url\"];\n")"; run "$f"; expect_code 2
expect_out "'API_KEY'"; expect_out "'DB_URL'"

tc TC-N12 "npm_* · 프록시 변수 · 대문자 이름 · 메서드 호출은 통과한다 (ND-03 과잉 차단 방지)"
f="$(put config.js "const v = process.env.npm_package_version;\nconst p = process.env.http_proxy || process.env['no_proxy'];\nconst e = process.env.NODE_ENV;\nconst k = process.env[\"ORDER_DB_URL\"];\nif (process.env.hasOwnProperty('X')) {}\n")"
run "$f"; expect_code 0; expect_no_out

tc TC-N13 "TS 파일은 환경 변수만 본다 — 식별자 · 파일 이름은 보지 않는다 (ND-03)"
f="$(put orderService.ts 'class order_service {}\nconst user_name = process.env.apiKey;\n')"; run "$f"; expect_code 2
expect_out "'API_KEY'"; expect_not "ND-04"; expect_not "ND-05"; expect_not "ND-06"
f="$(put Clean.tsx 'let user_name = process.env.API_KEY;\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-N14 "snake_case · camelCase 클래스를 막고 PascalCase 를 제안한다 (ND-04)"
f="$(put a.js 'class order_service {}\nexport default class orderRepo extends Base {}\n')"; run "$f"; expect_code 2
expect_out "ND-04"; expect_out "'OrderService'"; expect_out "'OrderRepo'"

tc TC-N15 "PascalCase · 이름 없는 클래스 · className 은 막지 않는다 (ND-04 과잉 차단 방지)"
f="$(put a.js 'class HTTPClient {}\nconst Local = class extends Base {};\nconst el = { className: x };\nobj.class = 1;\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-N16 "let · const · var · function 의 snake_case 를 막고 camelCase 를 제안한다 (ND-05)"
f="$(put a.js 'let user_name = 1;\nconst order_list = [];\nvar Item_Count = 0;\nfunction load_user() {}\nasync function* read_lines() {}\nexport const _cache_map = new Map();\n')"; run "$f"; expect_code 2
expect_out "ND-05"; expect_out "'userName'"; expect_out "'orderList'"; expect_out "'itemCount'"; expect_out "'loadUser'"; expect_out "'readLines'"; expect_out "'_cacheMap'"

tc TC-N17 "상수 · PascalCase · 앞 밑줄 · __dirname · 구조 분해는 막지 않는다 (ND-05 과잉 차단 방지)"
f="$(put a.js 'const MAX_RETRY_COUNT = 3;\nconst OrderCard = () => null;\nlet _private = 1;\nconst __dirname = x;\nconst { user_name, order_id: orderId } = row;\nconst [first_item] = list;\nfunction functionName() {}\n')"
run "$f"; expect_code 0; expect_no_out

tc TC-N18 "주석 · 문자열 · 템플릿 문자열의 글자는 코드로 읽지 않고, \${…} 안은 읽는다"
f="$(put a.js '/* class not_real\n   let also_not = 1 */\n// const bad_one = process.env.lower;\nconst s = "class bad_name let x_y process.env.foo";\nconst t = `let in_tpl ${process.env.tplVar} class tpl_cls`;\nconst q = '"'"'process.env["quoted"]'"'"';\n')"
run "$f"; expect_code 2; expect_out "'TPL_VAR'"; expect_not "not_real"; expect_not "also_not"; expect_not "bad_one"; expect_not "bad_name"; expect_not "in_tpl"; expect_not "tpl_cls"; expect_not "QUOTED"; expect_not "'LOWER'"

tc TC-N19 "정규식 리터럴 안의 따옴표가 뒤 코드를 가리지 않는다"
f="$(put a.js "const re = /[\"'/]+/g; let user_name = 1;\n")"; run "$f"; expect_code 2; expect_out "'userName'"

tc TC-N20 "밑줄이 섞인 JS 파일 이름은 경고만 한다 (ND-06)"
f="$(put order_service.mjs 'const a = 1;\n')"; run "$f"; expect_code 0; expect_out "⚠️"; expect_out "ND-06"; expect_out "'order-service.mjs'"
f="$(put Order_Card.js 'const a = 1;\n')"; run "$f"; expect_code 0; expect_out "ND-06"

tc TC-N21 "kebab-case · export 이름을 딴 camelCase · PascalCase · 점 접미사 · dotfile · _app · [id] 는 통과한다 (ND-06 과잉 차단 방지)"
rm -rf "$SRC"
for n in order-service.js webpack.config.js order-service.test.cjs .eslintrc.cjs _app.js '[id].js' '[...slug].jsx' OrderCard.jsx OrderCard.js useOrderQuery.js orderService.test.js index.mjs Gruntfile.js; do put "names/$n" 'const a = 1;\n' >/dev/null; done
run "$SRC/names"; expect_code 0; expect_no_out

tc TC-N22 "디렉터리를 주면 하위 파일을 보고 node_modules · dist · *.min.js 는 건너뛴다"
rm -rf "$TMP/proj"; mkdir -p "$TMP/proj/src" "$TMP/proj/node_modules/x" "$TMP/proj/dist"
printf 'let bad_one = 1;\n' > "$TMP/proj/src/app.js"
printf '{"name": "Bad_Dep"}' > "$TMP/proj/node_modules/x/package.json"
printf 'let gen_two = 1;\n' > "$TMP/proj/dist/app.js"
printf 'let min_three = 1;\n' > "$TMP/proj/src/vendor-lib.min.js"
run "$TMP/proj"; expect_code 2; expect_out "bad_one"; expect_not "Bad_Dep"; expect_not "gen_two"; expect_not "min_three"

tc TC-N23 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
rm -rf "$TMP/r"; mkdir -p "$TMP/r/.claude/worktrees/w/src"
printf 'let bad_three = 1;\n' > "$TMP/r/.claude/worktrees/w/src/app.js"
run --all "$TMP/r/.claude/worktrees/w"; expect_code 2; expect_out "bad_three"

tc TC-N24 "--all 은 루트의 .claude/worktrees 를 건너뛴다"
run --all "$TMP/r"; expect_code 0

# --- B. 훅 -------------------------------------------------------------------
tc TC-N30 "Write 로 name 이 틀린 package.json 을 새로 만들면 막는다"
rm -rf "$SRC"; mkdir -p "$SRC"
run_stdin "$(payload_write "$SRC/package.json" '{"name": "My_Order_Service", "version": "1.0.0"}')"; expect_code 2; expect_out "ND-01"; expect_out "'my-order-service'"

tc TC-N31 "Write 로 camelCase 환경 변수를 쓰는 JS 를 새로 만들면 막는다"
run_stdin "$(payload_write "$SRC/src/config.js" 'const dbHost = process.env.dbHost;\n')"; expect_code 2; expect_out "ND-03"; expect_out "'DB_HOST'"

tc TC-N32 "Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다"
run_stdin "$(payload_write "$SRC/order-service.js" "$CLEAN_JS")"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$SRC/package.json" "$CLEAN_PKG")"; expect_code 0; expect_no_out

tc TC-N33 "레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다"
f="$(put legacy.js 'let user_name = process.env.dbHost;\nfunction get() { return user_name; }\n')"
run_stdin "$(payload_edit "$f" 'return user_name;' 'return user_name.trim();')"; expect_code 0; expect_no_out

tc TC-N34 "Edit 가 새 위반을 만들면 그것만 보고한다"
run_stdin "$(payload_edit "$f" 'let user_name = process.env.dbHost;' 'let user_name = process.env.dbHost;\nlet item_count = 0;')"; expect_code 2
expect_out "'item_count'"; expect_not "'user_name'"; expect_not "'dbHost'"

tc TC-N35 "이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교)"
f="$(put g.js 'const a = process.env.apiKey;\n')"
run_stdin "$(payload_edit "$f" 'const a = process.env.apiKey;' 'const a = process.env.apiKey;\nconst b = process.env.apiKey;')"; expect_code 2; expect_out "'apiKey'"

tc TC-N36 "Edit 로 위반을 고치면 통과한다"
run_stdin "$(payload_edit "$f" 'process.env.apiKey' 'process.env.API_KEY')"; expect_code 0

tc TC-N37 "replace_all 을 적용한 결과를 본다"
f="$(put h.js 'let count = 0;\nfunction total() { return count; }\n')"
run_stdin "$(payload_edit "$f" 'count' 'count_x' true)"; expect_code 2; expect_out "'count_x'"

tc TC-N38 "한글이 섞인 파일도 치환 위치가 맞다"
f="$(put i.js '// 주문 서비스 — 한글 주석\nconst label = "주문";\n// 합계\nlet total = 0;\n')"
run_stdin "$(payload_edit "$f" 'let total = 0;' 'let total_sum = 0;')"; expect_code 2; expect_out "'totalSum'"

tc TC-N39 "경고만 있으면 additionalContext 로 알리고 통과한다"
run_stdin "$(payload_write "$SRC/order_service.js" 'const a = 1;\n')"; expect_code 0
expect_out '"additionalContext"'; expect_out "ND-06"
run_stdin "$(payload_write "$SRC/w/package.json" '{"name": "a", "scripts": {"buildProd": "x"}}')"; expect_code 0
expect_out '"additionalContext"'; expect_out "ND-02"

tc TC-N40 "대상 확장자가 아니면 보지 않는다"
run_stdin "$(payload_write "$SRC/notes.md" 'let bad_name = process.env.foo;')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$SRC/tsconfig.json" '{"name": "Bad_Name"}')"; expect_code 0; expect_no_out

tc TC-N41 "node_modules · dist 아래는 보지 않는다"
run_stdin "$(payload_write "$TMP/p/node_modules/x/package.json" '{"name": "Bad_Name"}')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$TMP/p/dist/app.js" 'let bad_gen = 1;\n')"; expect_code 0; expect_no_out

tc TC-N42 "편집 뒤 package.json 이 깨져 있으면 판정하지 않는다"
f="$(put p42/package.json '{"name": "ok"}')"
run_stdin "$(payload_edit "$f" '"ok"}' '"Bad_Name",')"; expect_code 0; expect_no_out

tc TC-N43 "PostToolUse 는 보지 않는다"
run_stdin '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/x/a.js","content":"let bad_name = 1;"}}'
expect_code 0; expect_no_out

tc TC-N44 "빈 입력 · 경로 없는 입력은 통과한다"
run_stdin ''; expect_code 0
run_stdin '{"hook_event_name":"PreToolUse","tool_input":{}}'; expect_code 0

tc TC-N45 "프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로)"
mkdir -p "$TMP/build/proj"
run_stdin_in "$TMP/build/proj" "$(jq -n --arg p "$TMP/build/proj/src/bad.js" --arg c "$(printf '%b' 'const user_name = 1;\n')" \
  '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}')"
expect_code 2; expect_out "ND-05"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
