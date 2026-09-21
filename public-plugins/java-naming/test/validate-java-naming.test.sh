#!/usr/bin/env bash
# scripts/validate-java-naming.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-java-naming.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/java-naming-tc.XXXXXX")"
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
java() { # $1=파일명 $2=내용 → 경로
  mkdir -p "$SRC"; printf '%b' "$2" > "$SRC/$1"; printf '%s' "$SRC/$1"
}
CLEAN='package com.example.order;\n\nimport java.util.List;\n\npublic class OrderService {\n    private static final int MAX_RETRY_COUNT = 3;\n    private static final long serialVersionUID = 1L;\n    private final OrderRepository orderRepository;\n\n    public OrderService(OrderRepository orderRepository) {\n        this.orderRepository = orderRepository;\n    }\n\n    public List<Order> findOrders(long userId) {\n        return orderRepository.findAll();\n    }\n}\n'
payload_write() { # $1=경로 $2=내용
  jq -n --arg p "$1" --arg c "$(printf '%b' "$2")" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}
payload_edit() { # $1=경로 $2=old $3=new [$4=replace_all]
  jq -n --arg p "$1" --arg o "$(printf '%b' "$2")" --arg n "$(printf '%b' "$3")" --argjson a "${4:-false}" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n, replace_all: $a}}'
}

echo "java-naming 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-J01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-J02 "규칙을 지킨 파일은 조용히 통과한다"
f="$(java OrderService.java "$CLEAN")"; run "$f"; expect_code 0; expect_no_out

tc TC-J03 "패키지에 대문자가 있으면 막고 소문자를 제안한다 (JN-01)"
f="$(java A.java 'package com.Example.order;\npublic class A {}\n')"; run "$f"; expect_code 2; expect_out "JN-01"; expect_out "'com.example.order'"

tc TC-J04 "패키지의 밑줄은 경고만 한다 (JN-01)"
f="$(java A.java 'package com.example.order_cancel;\npublic class A {}\n')"; run "$f"; expect_code 0; expect_out "⚠️"; expect_out "JN-01"

tc TC-J05 "snake_case 클래스를 막고 UpperCamelCase 를 제안한다 (JN-02)"
f="$(java order_dto.java 'package a;\npublic class order_dto {}\n')"; run "$f"; expect_code 2; expect_out "JN-02"; expect_out "'OrderDto'"

tc TC-J06 "인터페이스 · enum · record · 어노테이션도 본다 (JN-02)"
f="$(java B.java 'package a;\ninterface orderPort {}\nenum status { OPEN }\nrecord point(int x) {}\n@interface myMarker {}\n')"; run "$f"; expect_code 2
expect_out "'orderPort'"; expect_out "'status'"; expect_out "'point'"; expect_out "'myMarker'"

tc TC-J07 "public 최상위 타입이 파일 이름과 다르면 막는다 (JN-03)"
f="$(java Foo.java 'package a;\npublic class Bar {}\n')"; run "$f"; expect_code 2; expect_out "JN-03"; expect_out "Bar.java"

tc TC-J08 "public 이 아닌 최상위 타입은 파일 이름과 달라도 된다 (JN-03 과잉 차단 방지)"
f="$(java Foo.java 'package a;\nclass Helper {}\n')"; run "$f"; expect_code 0

tc TC-J09 "중첩 public 타입은 파일 이름과 비교하지 않는다"
f="$(java Outer.java 'package a;\npublic class Outer {\n    public static class Inner {}\n}\n')"; run "$f"; expect_code 0

tc TC-J10 "static final int 가 lowerCamelCase 면 막고 UPPER_SNAKE_CASE 를 제안한다 (JN-04)"
f="$(java C.java 'package a;\npublic class C {\n    private static final int maxRetryCount = 3;\n}\n')"; run "$f"; expect_code 2; expect_out "JN-04"; expect_out "'MAX_RETRY_COUNT'"

tc TC-J11 "static final String 도 상수로 본다 (JN-04)"
f="$(java C.java 'package a;\npublic class C {\n    public static final String defaultName = "x";\n}\n')"; run "$f"; expect_code 2; expect_out "'DEFAULT_NAME'"

tc TC-J12 "static final Logger · 컬렉션은 판정하지 않는다 (JN-04 과잉 차단 방지)"
f="$(java C.java 'package a;\npublic class C {\n    private static final Logger log = LoggerFactory.getLogger(C.class);\n    private static final List<String> names = List.of();\n}\n')"; run "$f"; expect_code 0

tc TC-J13 "serialVersionUID 는 예외다"
f="$(java C.java 'package a;\npublic class C {\n    private static final long serialVersionUID = 1L;\n}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-J14 "snake_case 필드를 막는다 (JN-05)"
f="$(java D.java 'package a;\npublic class D {\n    private String user_name;\n    protected int ItemCount;\n}\n')"; run "$f"; expect_code 2; expect_out "'userName'"; expect_out "'itemCount'"

tc TC-J15 "대문자로 시작하는 메서드를 막는다 (JN-05)"
f="$(java D.java 'package a;\npublic class D {\n    public String GetName() { return null; }\n}\n')"; run "$f"; expect_code 2; expect_out "JN-05"; expect_out "'getName'"

tc TC-J16 "테스트 메서드의 밑줄은 허용한다 (JN-05 과잉 차단 방지)"
f="$(java DTest.java 'package a;\npublic class DTest {\n    @Test\n    public void cancel_whenPaid_throws() {}\n}\n')"; run "$f"; expect_code 0

tc TC-J17 "생성자는 메서드로 보지 않는다"
f="$(java Order.java 'package a;\npublic class Order {\n    public Order(String id) {}\n    private Order() {}\n}\n')"; run "$f"; expect_code 0

tc TC-J18 "같은 줄의 어노테이션 · 제네릭 반환 타입 뒤의 이름을 본다 (JN-05)"
f="$(java E.java 'package a;\npublic class E {\n    @Override public String To_string() { return null; }\n    public <T> Map<String, List<T>> Group_by() { return null; }\n}\n')"; run "$f"; expect_code 2
expect_out "'To_string'"; expect_out "'Group_by'"

tc TC-J19 "주석 · 문자열 안의 단어는 코드로 읽지 않는다"
f="$(java F.java 'package a;\n/* class not_real\n   interface also_not */\npublic class F {\n    // private int Bad_name;\n    private String label = "class bad_name";\n}\n')"; run "$f"; expect_code 0

tc TC-J20 "약어가 대문자로 이어지면 경고만 한다 (JN-06)"
f="$(java HTTPClientAdapter.java 'package a;\npublic class HTTPClientAdapter {}\n')"; run "$f"; expect_code 0; expect_out "JN-06"; expect_out "⚠️"

tc TC-J21 "디렉터리를 주면 하위 *.java 를 보고 build/ 는 건너뛴다"
rm -rf "$TMP/proj"; mkdir -p "$TMP/proj/src/a" "$TMP/proj/build/gen"
printf 'package a;\npublic class bad_one {}\n' > "$TMP/proj/src/a/bad_one.java"
printf 'package a;\npublic class gen_two {}\n' > "$TMP/proj/build/gen/gen_two.java"
run "$TMP/proj"; expect_code 2; expect_out "bad_one"; expect_not "gen_two"

tc TC-J22 "package-info.java 는 보지 않는다"
rm -rf "$TMP/pi"; mkdir -p "$TMP/pi"; printf 'package com.Example;\n' > "$TMP/pi/package-info.java"
run "$TMP/pi"; expect_code 0

tc TC-J23 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
rm -rf "$TMP/r"; mkdir -p "$TMP/r/.claude/worktrees/w/src"
printf 'package a;\npublic class bad_three {}\n' > "$TMP/r/.claude/worktrees/w/src/bad_three.java"
run --all "$TMP/r/.claude/worktrees/w"; expect_code 2; expect_out "bad_three"

tc TC-J24 "--all 은 루트의 .claude/worktrees 를 건너뛴다"
run --all "$TMP/r"; expect_code 0

# --- B. 훅 -------------------------------------------------------------------
tc TC-J30 "Write 로 위반 파일을 새로 만들면 막는다"
rm -rf "$SRC"; mkdir -p "$SRC"
run_stdin "$(payload_write "$SRC/order_dto.java" 'package a;\npublic class order_dto {}\n')"; expect_code 2; expect_out "JN-02"; expect_out "'OrderDto'"

tc TC-J31 "Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다"
run_stdin "$(payload_write "$SRC/OrderService.java" "$CLEAN")"; expect_code 0; expect_no_out

tc TC-J32 "레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다"
f="$(java legacy_dto.java 'package a;\npublic class legacy_dto {\n    private String User_name;\n    public String get() { return User_name; }\n}\n')"
run_stdin "$(payload_edit "$f" 'return User_name;' 'return User_name.trim();')"; expect_code 0; expect_no_out

tc TC-J33 "Edit 가 새 위반을 만들면 그것만 보고한다"
run_stdin "$(payload_edit "$f" '    private String User_name;' '    private String User_name;\n    private int Item_count;')"; expect_code 2
expect_out "'Item_count'"; expect_not "'User_name'"

tc TC-J34 "이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교)"
f="$(java G.java 'package a;\npublic class G {\n    public void Run() {}\n}\n')"
run_stdin "$(payload_edit "$f" '    public void Run() {}' '    public void Run() {}\n    public void Run() {}')"; expect_code 2; expect_out "'Run'"

tc TC-J35 "Edit 로 위반을 고치면 통과한다"
run_stdin "$(payload_edit "$f" 'public void Run()' 'public void run()')"; expect_code 0

tc TC-J36 "replace_all 을 적용한 결과를 본다"
f="$(java H.java 'package a;\npublic class H {\n    private int count;\n    public int total() { return count; }\n}\n')"
run_stdin "$(payload_edit "$f" 'count' 'Count_x' true)"; expect_code 2; expect_out "'Count_x'"

tc TC-J37 "한글이 섞인 파일도 치환 위치가 맞다"
f="$(java I.java 'package a;\n// 주문 서비스 — 한글 주석\npublic class I {\n    // 필드\n    private int total;\n}\n')"
run_stdin "$(payload_edit "$f" 'private int total;' 'private int Total_sum;')"; expect_code 2; expect_out "'Total_sum'"

tc TC-J38 "경고만 있으면 additionalContext 로 알리고 통과한다"
run_stdin "$(payload_write "$SRC/XMLHTTPParser.java" 'package a;\npublic class XMLHTTPParser {}\n')"; expect_code 0
expect_out '"additionalContext"'; expect_out "JN-06"

tc TC-J39 "*.java 가 아니면 보지 않는다"
run_stdin "$(payload_write "$SRC/notes.md" 'public class bad_name {}')"; expect_code 0; expect_no_out

tc TC-J40 "build/ 아래 생성 코드는 보지 않는다"
run_stdin "$(payload_write "$TMP/p/build/generated/bad_gen.java" 'package a;\npublic class bad_gen {}\n')"; expect_code 0; expect_no_out

tc TC-J41 "PostToolUse 는 보지 않는다"
run_stdin '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/x/bad_name.java","content":"public class bad_name {}"}}'
expect_code 0; expect_no_out

tc TC-J42 "빈 입력 · 경로 없는 입력은 통과한다"
run_stdin ''; expect_code 0
run_stdin '{"hook_event_name":"PreToolUse","tool_input":{}}'; expect_code 0

tc TC-J43 "프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로)"
mkdir -p "$TMP/build/proj"
run_stdin_in "$TMP/build/proj" "$(jq -n --arg p "$TMP/build/proj/src/a/bad_x.java" --arg c "$(printf '%b' 'package a;\npublic class bad_x {}\n')" \
  '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}')"
expect_code 2; expect_out "JN-02"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
