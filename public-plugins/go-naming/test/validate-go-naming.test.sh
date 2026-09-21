#!/usr/bin/env bash
# scripts/validate-go-naming.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-go-naming.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/go-naming-tc.XXXXXX")"
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
gofile() { # $1=파일명 $2=내용 → 경로
  mkdir -p "$SRC"; printf '%b' "$2" > "$SRC/$1"; printf '%s' "$SRC/$1"
}
CLEAN='package order\n\nimport (\n\t"context"\n\t"net/http"\n)\n\nconst maxRetryCount = 3\n\nvar (\n\tdefaultTimeout = 30\n\t_ = http.StatusOK\n)\n\n// OrderService 는 주문을 다룬다.\ntype OrderService struct {\n\tclient  *http.Client\n\tbaseURL string\n\tuserID  int64 `json:"user_id"`\n}\n\nfunc NewOrderService(client *http.Client) *OrderService {\n\treturn &OrderService{client: client}\n}\n\nfunc (s *OrderService) Owner() string { return "" }\n\nfunc (s *OrderService) FindOrders(ctx context.Context, user_id int64) error {\n\tretry_count := 0\n\t_ = retry_count\n\treturn nil\n}\n'
payload_write() { # $1=경로 $2=내용
  jq -n --arg p "$1" --arg c "$(printf '%b' "$2")" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}
payload_edit() { # $1=경로 $2=old $3=new [$4=replace_all]
  jq -n --arg p "$1" --arg o "$(printf '%b' "$2")" --arg n "$(printf '%b' "$3")" --argjson a "${4:-false}" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n, replace_all: $a}}'
}

echo "go-naming 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-G01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-G02 "규칙을 지킨 파일은 조용히 통과한다 (지역 변수 · 매개변수의 밑줄은 보지 않는다)"
f="$(gofile order_service.go "$CLEAN")"; run "$f"; expect_code 0; expect_no_out

tc TC-G03 "패키지에 밑줄이 있으면 막고 한 단어를 제안한다 (GO-01)"
f="$(gofile a.go 'package order_service\n')"; run "$f"; expect_code 2; expect_out "GO-01"; expect_out "'orderservice'"

tc TC-G04 "패키지에 대문자가 있으면 막는다 (GO-01)"
f="$(gofile a.go 'package orderService\n')"; run "$f"; expect_code 2; expect_out "GO-01"; expect_out "'orderservice'"

tc TC-G05 "외부 테스트 패키지의 _test 접미사 · main 은 허용한다 (GO-01 과잉 차단 방지)"
f="$(gofile a_test.go 'package order_test\n')"; run "$f"; expect_code 0; expect_no_out
f="$(gofile main.go 'package main\n\nfunc main() {}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G06 "함수 이름의 밑줄을 막고 공개 여부를 유지한 MixedCaps 를 제안한다 (GO-02)"
f="$(gofile a.go 'package a\n\nfunc Create_order() {}\nfunc send_mail() {}\n')"; run "$f"; expect_code 2
expect_out "GO-02"; expect_out "'CreateOrder'"; expect_out "'sendMail'"

tc TC-G07 "메서드 · 타입 · 구조체 필드(중첩 · 여러 이름)의 밑줄을 막는다 (GO-02)"
f="$(gofile a.go 'package a\n\ntype Order_item struct {\n\tItem_name string\n\tA, B_c   int\n\tInner    struct {\n\t\tDeep_field int\n\t}\n}\n\nfunc (o *Order_item) Total_price() int { return 0 }\n')"; run "$f"; expect_code 2
expect_out "'OrderItem'"; expect_out "'ItemName'"; expect_out "'BC'"; expect_out "'DeepField'"; expect_out "'TotalPrice'"

tc TC-G08 "최상위 var · const 와 괄호 블록 안을 본다 — UPPER_SNAKE 는 MixedCaps 로 제안한다 (GO-02)"
f="$(gofile a.go 'package a\n\nconst MAX_SIZE = 10\nvar user_name, okName = "", ""\n\nconst (\n\tStatusOpen = iota\n\tstatus_closed\n)\n\nvar (\n\tretry_limit = 3\n)\n\ntype (\n\tOrder_id int64\n)\n')"; run "$f"; expect_code 2
expect_out "'MaxSize'"; expect_out "'userName'"; expect_out "'statusClosed'"; expect_out "'retryLimit'"; expect_out "'OrderID'"; expect_not "'okName'"

tc TC-G09 "빈 식별자 · 임베딩 · import 별칭 · 여러 줄 식 · 태그는 이름으로 보지 않는다 (GO-02 과잉 차단 방지)"
f="$(gofile a.go 'package a\n\nimport (\n\tstr_util "strings"\n)\n\nvar _ = 1\n\nvar (\n\tcfg = map[string]int{\n\t\tsome_key: 1,\n\t}\n\tx = build(\n\t\tfirst_arg,\n\t)\n)\n\ntype Order struct {\n\t*Embedded_base\n\tpkg.Other_type\n\tName string `json:"order_name"`\n}\n\nfunc _() {}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G10 "_test.go 의 Test · Benchmark · Example · Fuzz 함수 밑줄은 허용한다 (GO-02 과잉 차단 방지)"
f="$(gofile order_test.go 'package order\n\nfunc TestCancel_whenPaid(t *testing.T) {}\nfunc BenchmarkFind_all(b *testing.B) {}\nfunc ExampleOrder_Cancel() {}\nfunc FuzzParse_input(f *testing.F) {}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G11 "_test.go 가 아니면 Test 함수의 밑줄도 막는다 (GO-02)"
f="$(gofile order.go 'package order\n\nfunc TestCancel_whenPaid() {}\n')"; run "$f"; expect_code 2; expect_out "'TestCancelWhenPaid'"

tc TC-G12 "이니셜리즘이 Title 케이스면 경고한다 (GO-03)"
f="$(gofile a.go 'package a\n\nvar userId int\n\ntype HttpClient struct {\n\tApiUrl string\n}\n')"; run "$f"; expect_code 0; expect_out "⚠️"
expect_out "GO-03"; expect_out "'userID'"; expect_out "'HTTPClient'"; expect_out "'APIURL'"

tc TC-G13 "뒤에 소문자가 오는 단어 · 소문자 이니셜리즘은 경고하지 않는다 (GO-03 과잉 경고 방지)"
f="$(gofile a.go 'package a\n\ntype Identity struct {\n\tIds    []int\n\turlPath string\n\tIdle   bool\n\tHTTPServer string\n}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G14 "매개변수 없는 GetX() 메서드를 경고한다 (GO-04)"
f="$(gofile a.go 'package a\n\ntype Reader interface {\n\tGetName() string\n}\n\nfunc (o *Order) GetOwner() string { return "" }\n')"; run "$f"; expect_code 0
expect_out "GO-04"; expect_out "'Owner()'"; expect_out "'Name()'"

tc TC-G15 "매개변수가 있는 Get · 함수 GetX() 는 경고하지 않는다 (GO-04 과잉 경고 방지)"
f="$(gofile a.go 'package a\n\nfunc (o *Order) GetByID(id int) string { return "" }\nfunc GetConfig() string { return "" }\nfunc (o *Order) Get() string { return "" }\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G16 "파일 이름의 대문자 · 하이픈을 경고한다 (GO-05)"
f="$(gofile OrderService.go 'package a\n')"; run "$f"; expect_code 0; expect_out "GO-05"; expect_out "'order_service.go'"
f="$(gofile order-repo.go 'package a\n')"; run "$f"; expect_code 0; expect_out "'order_repo.go'"

tc TC-G17 "소문자 · 숫자 · 밑줄 파일 이름은 경고하지 않는다 (GO-05 과잉 경고 방지)"
f="$(gofile order_v2_linux.go 'package a\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G18 "리시버 this · self 를 경고하고 타입 약자를 제안한다 (GO-06)"
f="$(gofile a.go 'package a\n\nfunc (this *Order) Cancel() {}\nfunc (self Cart) Total() int { return 0 }\n')"; run "$f"; expect_code 0
expect_out "GO-06"; expect_out "'func (o *Order)'"; expect_out "'func (c Cart)'"

tc TC-G19 "짧은 리시버 · 이름 없는 리시버는 경고하지 않는다 (GO-06 과잉 경고 방지)"
f="$(gofile a.go 'package a\n\nfunc (o *Order) Cancel() {}\nfunc (*Order) Reset() {}\nfunc (p Pair[K, V]) Key() K { var k K; return k }\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G20 "주석 · 문자열 · 룬 · 여러 줄 raw string 안의 단어는 코드로 읽지 않는다"
f="$(gofile a.go 'package a\n\n/* func Not_real() {}\ntype also_not int */\n// var bad_name = 1\nvar label = "func bad_name() {}"\nvar r = '"'"'_'"'"'\nvar q = `\nfunc Raw_name() {}\ntype raw_type int\n`\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G21 "제네릭 함수 · 타입 이름도 본다 (GO-02)"
f="$(gofile a.go 'package a\n\nfunc Map_all[T any](xs []T) []T { return xs }\ntype Pair_of[K comparable, V any] struct{}\n')"; run "$f"; expect_code 2
expect_out "'MapAll'"; expect_out "'PairOf'"

tc TC-G22 "함수 안의 type 선언은 보고, 지역 var 는 보지 않는다"
f="$(gofile a.go 'package a\n\nfunc run() {\n\ttype local_t int\n\tvar inner_var = 1\n\t_ = inner_var\n}\n')"; run "$f"; expect_code 2
expect_out "'localT'"; expect_not "inner_var"

tc TC-G23 "생성 파일(// Code generated ... DO NOT EDIT.)은 보지 않는다"
f="$(gofile api.pb.go '// Code generated by protoc-gen-go. DO NOT EDIT.\n// source: api.proto\n\npackage api_v1\n\nfunc (x *Order) GetUser_id() int64 { return 0 }\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-G24 "생성 표시가 package 뒤에 있으면 생성 파일로 보지 않는다"
f="$(gofile b.go 'package a\n\n// Code generated by hand. DO NOT EDIT.\nfunc Bad_one() {}\n')"; run "$f"; expect_code 2; expect_out "'BadOne'"

tc TC-G25 "디렉터리를 주면 하위 *.go 를 보고 vendor/ · testdata/ 는 건너뛴다"
rm -rf "$TMP/proj"; mkdir -p "$TMP/proj/internal/order" "$TMP/proj/vendor/x" "$TMP/proj/internal/order/testdata"
printf 'package order\n\nfunc Bad_one() {}\n' > "$TMP/proj/internal/order/order.go"
printf 'package x\n\nfunc Vendor_two() {}\n' > "$TMP/proj/vendor/x/x.go"
printf 'package td\n\nfunc Fixture_three() {}\n' > "$TMP/proj/internal/order/testdata/td.go"
run "$TMP/proj"; expect_code 2; expect_out "Bad_one"; expect_not "Vendor_two"; expect_not "Fixture_three"

tc TC-G26 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
rm -rf "$TMP/r"; mkdir -p "$TMP/r/.claude/worktrees/w/src"
printf 'package a\n\nfunc Bad_three() {}\n' > "$TMP/r/.claude/worktrees/w/src/a.go"
run --all "$TMP/r/.claude/worktrees/w"; expect_code 2; expect_out "Bad_three"

tc TC-G27 "--all 은 루트의 .claude/worktrees 를 건너뛴다"
run --all "$TMP/r"; expect_code 0

# --- B. 훅 -------------------------------------------------------------------
tc TC-G30 "Write 로 위반 파일을 새로 만들면 막는다"
rm -rf "$SRC"; mkdir -p "$SRC"
run_stdin "$(payload_write "$SRC/order_service.go" 'package order_service\n\nfunc Create_order() {}\n')"; expect_code 2
expect_out "GO-01"; expect_out "GO-02"; expect_out "'CreateOrder'"

tc TC-G31 "Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다"
run_stdin "$(payload_write "$SRC/order_service.go" "$CLEAN")"; expect_code 0; expect_no_out

tc TC-G32 "레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다"
f="$(gofile legacy.go 'package legacy_pkg\n\ntype Legacy_dto struct {\n\tUser_name string\n}\n\nfunc (l *Legacy_dto) Name() string { return l.User_name }\n')"
run_stdin "$(payload_edit "$f" 'return l.User_name' 'return strings.TrimSpace(l.User_name)')"; expect_code 0; expect_no_out

tc TC-G33 "Edit 가 새 위반을 만들면 그것만 보고한다"
run_stdin "$(payload_edit "$f" '\tUser_name string' '\tUser_name string\n\tItem_count int')"; expect_code 2
expect_out "'Item_count'"; expect_not "'User_name'"

tc TC-G34 "이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교)"
f="$(gofile g.go 'package g\n\nfunc (g *G) Do_it() {}\n')"
run_stdin "$(payload_edit "$f" 'func (g *G) Do_it() {}' 'func (g *G) Do_it() {}\nfunc (h *H) Do_it() {}')"; expect_code 2; expect_out "'Do_it'"

tc TC-G35 "Edit 로 위반을 고치면 통과한다"
run_stdin "$(payload_edit "$f" 'Do_it()' 'DoIt()')"; expect_code 0

tc TC-G36 "replace_all 을 적용한 결과를 본다"
f="$(gofile h.go 'package h\n\nvar count int\n\nfunc total() int { return count }\n')"
run_stdin "$(payload_edit "$f" 'count' 'item_count' true)"; expect_code 2; expect_out "'itemCount'"

tc TC-G37 "한글이 섞인 파일도 치환 위치가 맞다"
f="$(gofile i.go 'package i\n\n// 주문 서비스 — 한글 주석\ntype I struct {\n\t// 합계\n\ttotal int\n}\n')"
run_stdin "$(payload_edit "$f" '\ttotal int' '\ttotal_sum int')"; expect_code 2; expect_out "'totalSum'"

tc TC-G38 "경고만 있으면 additionalContext 로 알리고 통과한다"
run_stdin "$(payload_write "$SRC/HttpClient.go" 'package a\n\ntype HttpClient struct{}\n\nfunc (this *HttpClient) GetURL() string { return "" }\n')"; expect_code 0
expect_out '"additionalContext"'; expect_out "GO-03"; expect_out "GO-04"; expect_out "GO-05"; expect_out "GO-06"

tc TC-G39 "이미 있는 파일을 고칠 때는 파일 이름 경고를 다시 하지 않는다 (GO-05)"
f="$(gofile OrderRepo.go 'package a\n\nvar total int\n')"
run_stdin "$(payload_edit "$f" 'var total int' 'var total, count int')"; expect_code 0; expect_no_out

tc TC-G40 "*.go 가 아니면 보지 않는다"
run_stdin "$(payload_write "$SRC/notes.md" 'package bad_name\nfunc Bad_name() {}')"; expect_code 0; expect_no_out

tc TC-G41 "vendor/ 아래는 보지 않는다"
run_stdin "$(payload_write "$TMP/p/vendor/x/bad.go" 'package bad_pkg\n\nfunc Bad_gen() {}\n')"; expect_code 0; expect_no_out

tc TC-G42 "생성 표시가 있는 내용을 Write 하면 막지 않는다"
run_stdin "$(payload_write "$SRC/api.pb.go" '// Code generated by protoc-gen-go. DO NOT EDIT.\n\npackage api_v1\n\nfunc Bad_gen() {}\n')"; expect_code 0; expect_no_out

tc TC-G43 "PostToolUse 는 보지 않는다"
run_stdin '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/x/bad.go","content":"package bad_name"}}'
expect_code 0; expect_no_out

tc TC-G44 "빈 입력 · 경로 없는 입력은 통과한다"
run_stdin ''; expect_code 0
run_stdin '{"hook_event_name":"PreToolUse","tool_input":{}}'; expect_code 0

tc TC-G45 "프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로)"
mkdir -p "$TMP/build/proj"
run_stdin_in "$TMP/build/proj" "$(jq -n --arg p "$TMP/build/proj/order/order.go" --arg c "$(printf '%b' 'package order_service\n')" \
  '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}')"
expect_code 2; expect_out "GO-01"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
