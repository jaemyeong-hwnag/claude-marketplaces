#!/usr/bin/env bash
# scripts/validate-kotlin-naming.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-kotlin-naming.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/kotlin-naming-tc.XXXXXX")"
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
kt() { # $1=파일명 $2=내용 → 경로
  mkdir -p "$SRC"; printf '%b' "$2" > "$SRC/$1"; printf '%s' "$SRC/$1"
}
CLEAN='package com.example.order\n\nimport kotlinx.coroutines.flow.Flow\n\nclass OrderService(\n    private val orderRepository: OrderRepository,\n) {\n    private val _state = MutableStateFlow(0)\n    val state: StateFlow<Int> = _state\n\n    fun findOrders(userId: Long): Flow<List<Order>> = orderRepository.findAll(userId)\n\n    suspend fun cancelOrder(orderId: Long) {\n        val order = orderRepository.find(orderId)\n        var retryCount = 0\n    }\n\n    companion object {\n        const val MAX_RETRY_COUNT = 3\n    }\n}\n'
payload_write() { # $1=경로 $2=내용
  jq -n --arg p "$1" --arg c "$(printf '%b' "$2")" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}
payload_edit() { # $1=경로 $2=old $3=new [$4=replace_all]
  jq -n --arg p "$1" --arg o "$(printf '%b' "$2")" --arg n "$(printf '%b' "$3")" --argjson a "${4:-false}" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n, replace_all: $a}}'
}

echo "kotlin-naming 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-K01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-K02 "규칙을 지킨 파일은 조용히 통과한다"
f="$(kt OrderService.kt "$CLEAN")"; run "$f"; expect_code 0; expect_no_out

tc TC-K03 "패키지 조각이 대문자로 시작하면 막고 소문자를 제안한다 (KN-01)"
f="$(kt A.kt 'package com.Example.order\nclass A\n')"; run "$f"; expect_code 2; expect_out "KN-01"; expect_out "'com.example.order'"

tc TC-K25 "패키지 조각의 camelCase 는 허용한다 — 공식 컨벤션 (KN-01 과잉 차단 방지)"
f="$(kt A.kt 'package com.example.orderHistory\nclass A\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-K04 "패키지의 밑줄은 경고만 한다 (KN-01)"
f="$(kt A.kt 'package com.example.order_cancel\nclass A\n')"; run "$f"; expect_code 0; expect_out "⚠️"; expect_out "KN-01"; expect_out "'com.example.ordercancel'"

tc TC-K05 "snake_case data class 를 막고 UpperCamelCase 를 제안한다 (KN-02)"
f="$(kt order_dto.kt 'package a\ndata class order_dto(val id: Long)\n')"; run "$f"; expect_code 2; expect_out "KN-02"; expect_out "'OrderDto'"

tc TC-K06 "interface · object · enum · annotation · sealed · value class · fun interface · typealias 도 본다 (KN-02)"
f="$(kt B.kt 'package a\ninterface orderPort\nobject order_registry\nenum class status { OPEN }\nannotation class myMarker\nsealed class payState\n@JvmInline value class orderId(val v: Long)\nfun interface order_handler { fun handle() }\ntypealias orderMap = Map<Long, Order>\nclass Outer {\n    companion object factory_x\n}\n')"
run "$f"; expect_code 2
for n in orderPort order_registry status myMarker payState orderId order_handler orderMap factory_x; do expect_out "'$n'"; done

tc TC-K07 "이름 없는 companion object · object 식 · ::class 는 타입 선언으로 보지 않는다 (KN-02 과잉 차단 방지)"
f="$(kt C.kt 'package a\nclass C {\n    companion object {\n        val runner = object : Runnable { override fun run() {} }\n    }\n    val type = C::class.java\n    val other = this::class\n}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-K08 "최상위 선언이 클래스 하나뿐인데 파일 이름이 다르면 막는다 (KN-03)"
f="$(kt Order.kt 'package a\n\ndata class OrderSummary(\n    val id: Long,\n    val total: Long,\n) {\n    fun isEmpty() = total == 0L\n    class Nested\n}\n')"; run "$f"; expect_code 2; expect_out "KN-03"; expect_out "OrderSummary.kt"

tc TC-K09 "최상위 선언이 여럿이면 파일 이름과 비교하지 않고, 소문자 파일 이름은 경고만 한다 (KN-03)"
f="$(kt Models.kt 'package a\nclass OrderA\nclass OrderB\n')"; run "$f"; expect_code 0; expect_no_out
f="$(kt OrderExtensions.kt 'package a\nclass Order\nfun Order.total() = 0\n')"; run "$f"; expect_code 0; expect_no_out
f="$(kt string_ext.kt 'package a\nfun String.toSlug() = this\n')"; run "$f"; expect_code 0; expect_out "⚠️"; expect_out "KN-03"; expect_out "'StringExt.kt'"

tc TC-K10 "멀티플랫폼 접미사(Platform.jvm.kt)는 떼고 비교한다 (KN-03 과잉 차단 방지)"
f="$(kt Platform.jvm.kt 'package a\nactual class Platform\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-K11 "const val 이 lowerCamelCase 면 막고 SCREAMING_SNAKE_CASE 를 제안한다 (KN-04)"
f="$(kt D.kt 'package a\nconst val maxRetryCount = 3\nobject Config {\n    private const val default_name = "x"\n}\n')"; run "$f"; expect_code 2
expect_out "KN-04"; expect_out "'MAX_RETRY_COUNT'"; expect_out "'DEFAULT_NAME'"; expect_not "KN-06"

tc TC-K12 "SCREAMING_SNAKE_CASE const val · serialVersionUID 는 통과한다 (KN-04 과잉 차단 방지)"
f="$(kt D.kt 'package a\nconst val MAX_RETRY_COUNT = 3\nclass D {\n    companion object {\n        private const val serialVersionUID = 1L\n        const val V2 = 2\n    }\n}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-K13 "대문자 · snake_case 함수와 확장 함수를 막는다 (KN-05)"
f="$(kt E.kt 'package a\nclass E {\n    fun Get_name() = 1\n    fun GetName(): String = ""\n    fun String.to_slug(): String = this\n    fun <T> List<T>.Second(): T = this[1]\n}\n')"; run "$f"; expect_code 2
expect_out "KN-05"; expect_out "'getName'"; expect_out "'toSlug'"; expect_out "'second'"

tc TC-K14 "백틱 이름 · 테스트 경로의 밑줄은 허용한다 (KN-05 과잉 차단 방지)"
rm -rf "$TMP/t"; mkdir -p "$TMP/t/src/test/kotlin" "$TMP/t/src/androidTest/kotlin" "$TMP/t/src/main/kotlin"
printf 'package a\nclass OrderTest {\n    @Test\n    fun cancel_whenPaid_throws() {}\n    @Test\n    fun `cancels paid order`() {}\n}\n' > "$TMP/t/src/test/kotlin/OrderTest.kt"
printf 'package a\nclass OrderScreenTest {\n    fun given_order_then_shown() {}\n}\n' > "$TMP/t/src/androidTest/kotlin/OrderScreenTest.kt"
printf 'package a\nclass Fixtures {\n    fun `build order`() = 1\n}\n' > "$TMP/t/src/main/kotlin/Fixtures.kt"
run "$TMP/t"; expect_code 0; expect_no_out

tc TC-K15 "테스트 경로가 아니면 함수 이름의 밑줄을 막는다 (KN-05)"
f="$(kt F.kt 'package a\nclass F {\n    fun cancel_order() {}\n}\n')"; run "$f"; expect_code 2; expect_out "'cancelOrder'"

tc TC-K16 "@Composable 함수는 대문자로 시작해도 된다 — 같은 줄 · 위 어노테이션 줄 (KN-05 과잉 차단 방지)"
f="$(kt OrderScreen.kt 'package a\n\n@Composable\n@Preview(showBackground = true)\nfun OrderScreen() {}\n\n@Composable fun OrderRow(content: @Composable () -> Unit) {}\n\n@androidx.compose.runtime.Composable\nprivate fun OrderList() {}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-K17 "반환 타입이 이름과 같은 팩터리 함수는 허용하고, 다르면 막는다 (KN-05)"
f="$(kt Order.kt 'package a\ninterface Order\nfun Order(id: Long): Order = OrderImpl(id)\nfun Order(\n    id: Long,\n    name: String,\n): Order {\n    return OrderImpl(id)\n}\nfun <T> Box(v: T): Box<T> = TODO()\n')"; run "$f"; expect_code 0; expect_no_out
f="$(kt G.kt 'package a\nfun MakeOrder(id: Long): Order = TODO()\n')"; run "$f"; expect_code 2; expect_out "'makeOrder'"

tc TC-K18 "snake_case val · var 를 막는다 — 생성자 프로퍼티 · 지역 변수 · 확장 프로퍼티 (KN-06)"
f="$(kt H.kt 'package a\nclass H(val user_name: String) {\n    fun run() {\n        var retry_count = 0\n    }\n}\nval String.first_char: Char get() = this[0]\nprivate val _backing_value = 1\n')"; run "$f"; expect_code 2
expect_out "KN-06"; expect_out "'userName'"; expect_out "'retryCount'"; expect_out "'firstChar'"; expect_out "'_backingValue'"

tc TC-K19 "백킹 프로퍼티 · SCREAMING_SNAKE_CASE · UpperCamelCase val · 구조 분해는 통과한다 (KN-06 과잉 차단 방지)"
f="$(kt I.kt 'package a\nval DEFAULT_TIMEOUT = 30\nval EmptyOrder = Order()\nclass I {\n    private val _state = 0\n    val state get() = _state\n    fun run() {\n        val (first_a, second_b) = pair\n        val x by lazy { foo.bar_baz }\n    }\n}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-K20 "주석 · 중첩 블록 주석 · 문자열 · raw string 안의 단어는 코드로 읽지 않는다"
f="$(kt J.kt 'package a\n/* class not_real /* nested fun Bad_one() */ interface also_not */\nclass J {\n    // val bad_name = 1\n    val label = "class bad_name fun Bad_fun"\n    val raw = """\n        class raw_bad\n        val bad_raw = 1\n    """\n    val ch = '"'"'"'"'"'\n    val tpl = "${label} val in_str"\n}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-K21 "약어가 대문자 4개 이상 이어지면 경고만 하고, IOStream 은 허용한다 (KN-07)"
f="$(kt Clients.kt 'package a\nclass HTTPClientAdapter\nclass IOStream\n')"; run "$f"; expect_code 0; expect_out "KN-07"; expect_out "⚠️"; expect_out "HTTPClientAdapter"; expect_not "'IOStream'"

tc TC-K22 "디렉터리를 주면 하위 *.kt 를 보고 build/ · *.kts 는 건너뛴다"
rm -rf "$TMP/proj"; mkdir -p "$TMP/proj/src/a" "$TMP/proj/build/gen"
printf 'package a\nclass bad_one\n' > "$TMP/proj/src/a/bad_one.kt"
printf 'package a\nclass gen_two\n' > "$TMP/proj/build/gen/gen_two.kt"
printf 'val bad_script = 1\n' > "$TMP/proj/build.gradle.kts"
run "$TMP/proj"; expect_code 2; expect_out "bad_one"; expect_not "gen_two"; expect_not "bad_script"

tc TC-K23 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
rm -rf "$TMP/r"; mkdir -p "$TMP/r/.claude/worktrees/w/src"
printf 'package a\nclass bad_three\n' > "$TMP/r/.claude/worktrees/w/src/bad_three.kt"
run --all "$TMP/r/.claude/worktrees/w"; expect_code 2; expect_out "bad_three"

tc TC-K24 "--all 은 루트의 .claude/worktrees 를 건너뛴다"
run --all "$TMP/r"; expect_code 0

# --- B. 훅 -------------------------------------------------------------------
tc TC-K30 "Write 로 위반 파일을 새로 만들면 막는다"
rm -rf "$SRC"; mkdir -p "$SRC"
run_stdin "$(payload_write "$SRC/order_dto.kt" 'package com.example.order\ndata class order_dto(val id: Long)\n')"; expect_code 2; expect_out "KN-02"; expect_out "'OrderDto'"

tc TC-K31 "Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다"
run_stdin "$(payload_write "$SRC/OrderService.kt" "$CLEAN")"; expect_code 0; expect_no_out

tc TC-K32 "레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다"
f="$(kt legacy_dto.kt 'package a\nclass legacy_dto {\n    val user_name = ""\n    fun get() = user_name\n}\n')"
run_stdin "$(payload_edit "$f" 'fun get() = user_name' 'fun get() = user_name.trim()')"; expect_code 0; expect_no_out

tc TC-K33 "Edit 가 새 위반을 만들면 그것만 보고한다"
run_stdin "$(payload_edit "$f" '    val user_name = ""' '    val user_name = ""\n    val item_count = 0')"; expect_code 2
expect_out "'itemCount'"; expect_not "'userName'"

tc TC-K34 "이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교)"
f="$(kt G.kt 'package a\nclass G {\n    fun Run_it() {}\n}\n')"
run_stdin "$(payload_edit "$f" '    fun Run_it() {}' '    fun Run_it() {}\n    fun Run_it() {}')"; expect_code 2; expect_out "'runIt'"

tc TC-K35 "Edit 로 위반을 고치면 통과한다"
run_stdin "$(payload_edit "$f" 'fun Run_it()' 'fun runIt()')"; expect_code 0

tc TC-K36 "replace_all 을 적용한 결과를 본다"
f="$(kt H.kt 'package a\nclass H {\n    val count = 0\n    fun total() = count\n}\n')"
run_stdin "$(payload_edit "$f" 'count' 'count_x' true)"; expect_code 2; expect_out "'countX'"

tc TC-K37 "한글이 섞인 파일도 치환 위치가 맞다"
f="$(kt I.kt 'package a\n// 주문 서비스 — 한글 주석\nclass I {\n    // 필드\n    val total = 0\n}\n')"
run_stdin "$(payload_edit "$f" 'val total = 0' 'val total_sum = 0')"; expect_code 2; expect_out "'totalSum'"

tc TC-K38 "경고만 있으면 additionalContext 로 알리고 통과한다"
run_stdin "$(payload_write "$SRC/XMLHTTPParser.kt" 'package a\nclass XMLHTTPParser\n')"; expect_code 0
expect_out '"additionalContext"'; expect_out "KN-07"

tc TC-K39 "*.kt 가 아니면 보지 않는다 (*.kts 포함)"
run_stdin "$(payload_write "$SRC/notes.md" 'class bad_name')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$SRC/build.gradle.kts" 'val bad_name = 1')"; expect_code 0; expect_no_out

tc TC-K40 "build/ 아래 생성 코드는 보지 않는다"
run_stdin "$(payload_write "$TMP/p/build/generated/bad_gen.kt" 'package a\nclass bad_gen\n')"; expect_code 0; expect_no_out

tc TC-K41 "PostToolUse 는 보지 않는다"
run_stdin '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/x/bad_name.kt","content":"class bad_name"}}'
expect_code 0; expect_no_out

tc TC-K42 "빈 입력 · 경로 없는 입력은 통과한다"
run_stdin ''; expect_code 0
run_stdin '{"hook_event_name":"PreToolUse","tool_input":{}}'; expect_code 0

tc TC-K43 "프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로)"
mkdir -p "$TMP/build/proj"
run_stdin_in "$TMP/build/proj" "$(jq -n --arg p "$TMP/build/proj/src/main/kotlin/a/Order.kt" --arg c "$(printf '%b' 'package a\nclass order_x\n')" \
  '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}')"
expect_code 2; expect_out "KN-02"

tc TC-K44 "프로젝트가 test/ 폴더 아래 있어도 main 소스에 테스트 밑줄 허용을 주지 않는다"
mkdir -p "$TMP/test/proj"
run_stdin_in "$TMP/test/proj" "$(jq -n --arg p "$TMP/test/proj/src/main/kotlin/a/Svc.kt" --arg c "$(printf '%b' 'package a\nfun create_order() {}\n')" \
  '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}')"
expect_code 2; expect_out "KN-05"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
