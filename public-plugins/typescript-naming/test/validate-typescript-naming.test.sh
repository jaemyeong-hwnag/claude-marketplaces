#!/usr/bin/env bash
# scripts/validate-typescript-naming.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-typescript-naming.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/typescript-naming-tc.XXXXXX")"
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
SRC="$TMP/src"
tsf() { # $1=파일명 $2=내용 → 경로
  mkdir -p "$SRC"; printf '%b' "$2" > "$SRC/$1"; printf '%s' "$SRC/$1"
}
CLEAN='import type { Order } from "./order";\n\nconst MAX_RETRY_COUNT = 3;\n\nexport interface OrderProps {\n  orderId: string;\n}\n\nexport enum OrderStatus { Paid, Canceled }\n\nexport class OrderService<TOrder extends Order> {\n  private readonly cancelCount = 0;\n  constructor(private readonly orderRepository: OrderRepository) {}\n\n  async cancelOrder(orderId: string): Promise<void> {\n    const canceledAt = new Date();\n  }\n}\n\nexport function findOrders<T>(userId: string): T[] {\n  return [];\n}\n'
payload_write() { # $1=경로 $2=내용
  jq -n --arg p "$1" --arg c "$(printf '%b' "$2")" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}
payload_edit() { # $1=경로 $2=old $3=new [$4=replace_all]
  jq -n --arg p "$1" --arg o "$(printf '%b' "$2")" --arg n "$(printf '%b' "$3")" --argjson a "${4:-false}" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n, replace_all: $a}}'
}

echo "typescript-naming 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-T01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-T02 "규칙을 지킨 파일은 조용히 통과한다"
f="$(tsf order-service.ts "$CLEAN")"; run "$f"; expect_code 0; expect_no_out

tc TC-T03 "snake_case 클래스를 막고 PascalCase 를 제안한다 (TS-01)"
f="$(tsf a.ts 'export class order_service {}\n')"; run "$f"; expect_code 2; expect_out "TS-01"; expect_out "'OrderService'"

tc TC-T04 "abstract class · interface · type · enum · namespace · declare · export default 도 본다 (TS-01)"
f="$(tsf b.ts 'export abstract class baseRepo {}\ninterface orderPort {}\nexport type order_id = string;\nconst enum status { Open }\nnamespace my_ns {}\ndeclare class ext_lib {}\nexport default class main_view extends Base {}\ntype pair<T> = [T, T];\n')"
run "$f"; expect_code 2
expect_out "'baseRepo'"; expect_out "'orderPort'"; expect_out "'order_id'"; expect_out "'status'"; expect_out "'my_ns'"
expect_out "'ext_lib'"; expect_out "'main_view'"; expect_out "'pair'"; expect_out "'OrderId'"

tc TC-T05 "type · class 를 이름으로 쓰거나 선언이 아닌 곳은 보지 않는다 (TS-01 과잉 차단 방지)"
f="$(tsf c.ts 'import type { foo_bar } from "./x";\nimport { type baz_qux } from "./y";\nconst type = 1;\nlet kind = type as number;\nif (node.type === 1) {}\nexport default class {}\nconst Klass = class extends Base {};\nexport type { Foo };\n')"
run "$f"; expect_code 0; expect_no_out

tc TC-T06 "interface 의 I 접두사는 경고만 한다 (TS-02)"
f="$(tsf d.ts 'export interface IUser { name: string }\n')"; run "$f"; expect_code 0; expect_out "⚠️"; expect_out "TS-02"; expect_out "'User'"

tc TC-T07 "I 로 시작하는 일반 이름은 경고하지 않는다 (TS-02 과잉 경고 방지)"
f="$(tsf e.ts 'interface IPAddress {}\ninterface Icon {}\ninterface Item {}\nclass IUserImpl {}\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-T08 "소문자 snake_case 변수를 막고 camelCase 를 제안한다 (TS-03)"
f="$(tsf f.ts 'const user_name = "x";\nlet order_count = 0;\nvar is_open = false;\nfor (const item_id of ids) {}\n')"; run "$f"; expect_code 2
expect_out "'userName'"; expect_out "'orderCount'"; expect_out "'isOpen'"; expect_out "'itemId'"

tc TC-T09 "function · async function · export default function · generator 도 본다 (TS-03)"
f="$(tsf g.ts 'function get_user() {}\nexport async function fetch_orders() {}\nexport default function main_page() {}\nfunction* id_gen() {}\n')"; run "$f"; expect_code 2
expect_out "'getUser'"; expect_out "'fetchOrders'"; expect_out "'mainPage'"; expect_out "'idGen'"

tc TC-T10 "UPPER_SNAKE · PascalCase · 앞뒤 밑줄 · 구조 분해 · declare 는 통과한다 (TS-03 과잉 차단 방지)"
f="$(tsf h.ts 'const API_BASE_URL = "x";\nexport const UserSchema = z.object({});\nconst UserCard = () => null;\nconst _unused = 1;\nconst __dirname = "x";\nconst { user_id, order_no } = body;\nconst [first_item] = items;\ndeclare const build_time: string;\nexport declare function ext_fn(): void;\nconst enum Mode { Fast }\n')"
run "$f"; expect_code 0; expect_no_out

tc TC-T11 "대문자로 시작하는 snake 이름은 PascalCase 를 제안한다 (TS-03)"
f="$(tsf i.ts 'const User_Card = () => null;\n')"; run "$f"; expect_code 2; expect_out "'UserCard'"

tc TC-T12 "camelCase · snake_case enum 멤버는 경고만 한다 (TS-04)"
f="$(tsf j.ts 'enum Color { Red, lightBlue, dark_green = 3 }\nenum Mode {\n  fast_mode = 1,\n  Slow\n}\n')"; run "$f"; expect_code 0; expect_out "TS-04"
expect_out "'LightBlue'"; expect_out "'DarkGreen'"; expect_out "'FastMode'"; expect_not "'Red'"; expect_not "'Slow'"

tc TC-T13 "PascalCase · UPPER_SNAKE · 따옴표 멤버 · 초기값은 경고하지 않는다 (TS-04 과잉 경고 방지)"
f="$(tsf k.ts 'export enum Status {\n  Paid = "paid",\n  IN_PROGRESS = "in_progress",\n  "kebab-name" = 3,\n  Flag = 1 << 2,\n}\nconst e = { lower_key: 1 };\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-T14 "소문자로 시작하는 타입 매개변수는 경고만 한다 (TS-05)"
f="$(tsf l.ts 'function map<key, value>(k: key): value {}\nclass Box<t> {}\ninterface Repo<entity> {}\ntype Pair<first, Second> = [first, Second];\n')"; run "$f"; expect_code 0; expect_out "TS-05"
expect_out "'TKey'"; expect_out "'TValue'"; expect_out "'T'"; expect_out "'TEntity'"; expect_out "'TFirst'"; expect_not "'TSecond'"

tc TC-T15 "T · TKey · PascalCase · 기본값 · 제약 · const 는 경고하지 않는다 (TS-05 과잉 경고 방지)"
f="$(tsf m.ts 'function f<const T, TKey extends keyof T = keyof T>() {}\nclass Store<State, Action = () => void> {}\ninterface Page<Item extends Record<string, unknown>> {}\ntype Fn<in out T> = (x: T) => T;\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-T16 "snake_case class 멤버는 경고만 한다 — 필드 · readonly · 메서드 · 생성자 매개변수 프로퍼티 (TS-06)"
f="$(tsf n.ts 'export class UserDto {\n  public user_id: string;\n  readonly created_at: Date;\n  private static get_instance(): UserDto {}\n  constructor(\n    private readonly http_client: HttpClient,\n  ) {}\n}\n')"; run "$f"; expect_code 0; expect_out "TS-06"
expect_out "'userId'"; expect_out "'createdAt'"; expect_out "'getInstance'"; expect_out "'httpClient'"

tc TC-T17 "interface · type 프로퍼티 · 제어자 없는 멤버 · 상수 · 메서드 본문은 보지 않는다 (TS-06 과잉 경고 방지)"
f="$(tsf o.ts 'interface Payload {\n  readonly user_id: string;\n}\ntype Row = {\n  readonly created_at: Date;\n};\nclass Cache {\n  static readonly MAX_SIZE = 10;\n  private _store = new Map();\n  plain_field = 1;\n  load() {\n    return { private_key: 1 };\n  }\n}\n')"
run "$f"; expect_code 0; expect_no_out

tc TC-T18 "주석 · 문자열 · 여러 줄 템플릿 리터럴 안의 단어는 코드로 읽지 않는다"
f="$(tsf p.ts '/* class not_real {}\n   const also_not = 1 */\n// const bad_name = 1;\nconst label = "class bad_one {}";\nconst quote = \047let bad_two = 1\047;\nconst sql = `\n  const bad_three = 1;\n  ${value}\n`;\nconst after_tpl = 1;\n')"
run "$f"; expect_code 2; expect_out "'after_tpl'"; expect_not "not_real"; expect_not "also_not"; expect_not "bad_name"; expect_not "bad_one"; expect_not "bad_two"; expect_not "bad_three"

tc TC-T19 "tsx 의 컴포넌트 · JSX 본문 글은 과잉 차단하지 않는다"
f="$(tsf Card.tsx 'interface CardProps { title: string }\nexport function UserCard({ title }: CardProps) {\n  return (\n    <div className="card">\n      This class is great and the type of it = good\n      {title}\n    </div>\n  );\n}\nexport const List = <T,>(props: { items: T[] }) => <ul />;\n')"
run "$f"; expect_code 0; expect_no_out

tc TC-T20 "디렉터리를 주면 하위 파일을 보고 dist/ · build/ · *.d.ts 는 건너뛴다"
rm -rf "$TMP/proj"; mkdir -p "$TMP/proj/src" "$TMP/proj/dist" "$TMP/proj/build"
printf 'const bad_one = 1;\n' > "$TMP/proj/src/one.ts"
printf 'const gen_two = 1;\n' > "$TMP/proj/dist/two.ts"
printf 'const gen_three = 1;\n' > "$TMP/proj/build/three.ts"
printf 'declare class ext_four {}\nexport const gen_five: number;\n' > "$TMP/proj/src/types.d.ts"
run "$TMP/proj"; expect_code 2; expect_out "bad_one"; expect_not "gen_two"; expect_not "gen_three"; expect_not "ext_four"; expect_not "gen_five"

tc TC-T21 "*.mts · *.cts 도 본다"
rm -rf "$TMP/m"; mkdir -p "$TMP/m"
printf 'export const esm_value = 1;\n' > "$TMP/m/a.mts"; printf 'const cjs_value = 1;\n' > "$TMP/m/b.cts"
run "$TMP/m"; expect_code 2; expect_out "'esmValue'"; expect_out "'cjsValue'"

tc TC-T22 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
rm -rf "$TMP/r"; mkdir -p "$TMP/r/.claude/worktrees/w/src"
printf 'const bad_three = 1;\n' > "$TMP/r/.claude/worktrees/w/src/a.ts"
run --all "$TMP/r/.claude/worktrees/w"; expect_code 2; expect_out "bad_three"

tc TC-T23 "--all 은 루트의 .claude/worktrees 를 건너뛴다"
run --all "$TMP/r"; expect_code 0

# --- B. 훅 -------------------------------------------------------------------
tc TC-T30 "Write 로 위반 파일을 새로 만들면 막는다"
rm -rf "$SRC"; mkdir -p "$SRC"
run_stdin "$(payload_write "$SRC/order-service.ts" 'export class order_service {}\nconst user_name = "x";\n')"; expect_code 2
expect_out "TS-01"; expect_out "'OrderService'"; expect_out "TS-03"; expect_out "'userName'"

tc TC-T31 "Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다"
run_stdin "$(payload_write "$SRC/order-service.ts" "$CLEAN")"; expect_code 0; expect_no_out

tc TC-T32 "레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다"
f="$(tsf legacy.ts 'const legacy_name = 1;\nexport function get_value() {\n  return legacy_name;\n}\n')"
run_stdin "$(payload_edit "$f" 'return legacy_name;' 'return legacy_name + 1;')"; expect_code 0; expect_no_out

tc TC-T33 "Edit 가 새 위반을 만들면 그것만 보고한다"
run_stdin "$(payload_edit "$f" 'const legacy_name = 1;' 'const legacy_name = 1;\nconst item_count = 2;')"; expect_code 2
expect_out "'itemCount'"; expect_not "'legacyName'"

tc TC-T34 "이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교)"
f="$(tsf dup.ts 'function run_task() {}\n')"
run_stdin "$(payload_edit "$f" 'function run_task() {}' 'function run_task() {}\nfunction run_task() {}')"; expect_code 2; expect_out "'runTask'"

tc TC-T35 "Edit 로 위반을 고치면 통과한다"
run_stdin "$(payload_edit "$f" 'function run_task()' 'function runTask()')"; expect_code 0

tc TC-T36 "replace_all 을 적용한 결과를 본다"
f="$(tsf ra.ts 'const count = 1;\nexport const total = count + 1;\n')"
run_stdin "$(payload_edit "$f" 'count' 'count_x' true)"; expect_code 2; expect_out "'countX'"

tc TC-T37 "한글이 섞인 파일도 치환 위치가 맞다"
f="$(tsf ko.ts '// 주문 서비스 — 한글 주석\nconst label = "주문";\n// 합계\nconst total = 1;\n')"
run_stdin "$(payload_edit "$f" 'const total = 1;' 'const total_sum = 1;')"; expect_code 2; expect_out "'totalSum'"

tc TC-T38 "경고만 있으면 additionalContext 로 알리고 통과한다"
run_stdin "$(payload_write "$SRC/user.ts" 'export interface IUser { name: string }\n')"; expect_code 0
expect_out '"additionalContext"'; expect_out "TS-02"

tc TC-T39 "TS 파일이 아니거나 *.d.ts 면 보지 않는다"
run_stdin "$(payload_write "$SRC/notes.md" 'const bad_name = 1;')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$SRC/app.js" 'const bad_name = 1;')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$SRC/types.d.ts" 'declare class bad_name {}')"; expect_code 0; expect_no_out

tc TC-T40 "dist/ · node_modules/ · generated/ 아래는 보지 않는다"
run_stdin "$(payload_write "$TMP/p/dist/bad.ts" 'const bad_gen = 1;\n')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$TMP/p/node_modules/x/bad.ts" 'const bad_gen = 1;\n')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$TMP/p/src/generated/bad.ts" 'const bad_gen = 1;\n')"; expect_code 0; expect_no_out

tc TC-T41 "PostToolUse 는 보지 않는다"
run_stdin '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/x/bad.ts","content":"const bad_name = 1;"}}'
expect_code 0; expect_no_out

tc TC-T42 "빈 입력 · 경로 없는 입력은 통과한다"
run_stdin ''; expect_code 0
run_stdin '{"hook_event_name":"PreToolUse","tool_input":{}}'; expect_code 0

tc TC-T43 "프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로)"
mkdir -p "$TMP/build/proj"
run_stdin_in "$TMP/build/proj" "$(jq -n --arg p "$TMP/build/proj/src/a.ts" --arg c "$(printf '%b' 'export class order_x {}\n')" \
  '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}')"
expect_code 2; expect_out "TS-01"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
