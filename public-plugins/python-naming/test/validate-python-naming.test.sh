#!/usr/bin/env bash
# scripts/validate-python-naming.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/validate-python-naming.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/python-naming-tc.XXXXXX")"
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
py() { # $1=파일명 $2=내용 → 경로
  mkdir -p "$SRC"; printf '%b' "$2" > "$SRC/$1"; printf '%s' "$SRC/$1"
}
CLEAN='"""주문 서비스."""\nfrom typing import TypeVar\n\nMAX_RETRY_COUNT = 3\nT = TypeVar("T")\n\n\nclass OrderNotFoundError(LookupError):\n    pass\n\n\nclass OrderService:\n    def __init__(self, repository):\n        self._repository = repository\n\n    async def cancel_order(self, order_id: int, *args, **kwargs) -> None:\n        is_paid = self._repository.is_paid(order_id)\n\n    @classmethod\n    def create(cls, id_=None):\n        return cls(None)\n'
payload_write() { # $1=경로 $2=내용
  jq -n --arg p "$1" --arg c "$(printf '%b' "$2")" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}'
}
payload_edit() { # $1=경로 $2=old $3=new [$4=replace_all]
  jq -n --arg p "$1" --arg o "$(printf '%b' "$2")" --arg n "$(printf '%b' "$3")" --argjson a "${4:-false}" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n, replace_all: $a}}'
}

echo "python-naming 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-P01 "이 저장소 전체가 통과한다"
run --all "$REPO_ROOT"; expect_code 0

tc TC-P02 "규칙을 지킨 파일은 조용히 통과한다"
f="$(py order_service.py "$CLEAN")"; run "$f"; expect_code 0; expect_no_out

tc TC-P03 "하이픈이 있는 모듈 파일 이름을 막고 snake_case 를 제안한다 (PY-01)"
f="$(py order-service.py 'x = 1\n')"; run "$f"; expect_code 2; expect_out "PY-01"; expect_out "'order_service.py'"

tc TC-P04 "대문자가 있는 모듈 파일 이름을 막는다 (PY-01)"
f="$(py OrderService.py 'x = 1\n')"; run "$f"; expect_code 2; expect_out "PY-01"; expect_out "'order_service.py'"

tc TC-P05 "__init__.py · __main__.py · 앞 밑줄 모듈은 통과한다 (PY-01 과잉 차단 방지)"
rm -rf "$SRC"; py __init__.py 'x = 1\n' >/dev/null; py __main__.py 'x = 1\n' >/dev/null; py _internal2.py 'x = 1\n' >/dev/null
run "$SRC"; expect_code 0; expect_no_out

tc TC-P06 "snake_case 클래스를 막고 CapWords 를 제안한다 (PY-02)"
f="$(py a.py 'class order_service:\n    pass\n\n\nclass orderPort(Base):\n    pass\n')"; run "$f"; expect_code 2
expect_out "PY-02"; expect_out "'OrderService'"; expect_out "'OrderPort'"

tc TC-P07 "앞 밑줄 · 약어 대문자 클래스는 통과한다 (PY-02 과잉 차단 방지)"
f="$(py a.py 'class _Private:\n    pass\n\n\nclass HTTPServer2:\n    pass\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-P08 "CapWords · mixedCase 함수를 막고 snake_case 를 제안한다 (PY-03)"
f="$(py a.py 'def CreateOrder():\n    pass\n\n\nclass A:\n    async def fetchAll(self):\n        pass\n\n    def getHTTPResponse(self):\n        pass\n')"; run "$f"; expect_code 2
expect_out "PY-03"; expect_out "'create_order'"; expect_out "'fetch_all'"; expect_out "'get_http_response'"

tc TC-P09 "앞 밑줄 · dunder 함수는 통과한다 (PY-03 과잉 차단 방지)"
f="$(py a.py 'class A:\n    def __init__(self):\n        pass\n\n    def __eq__(self, other):\n        pass\n\n    def _helper(self):\n        pass\n\n    def __mangled(self):\n        pass\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-P10 "unittest · NodeVisitor · http.server 의 정해진 이름은 통과한다 (PY-03 과잉 차단 방지)"
f="$(py a.py 'class T(unittest.TestCase):\n    def setUp(self):\n        pass\n\n    @classmethod\n    def tearDownClass(cls):\n        pass\n\n    async def asyncSetUp(self):\n        pass\n\n\nclass V(ast.NodeVisitor):\n    def visit_FunctionDef(self, node):\n        pass\n\n\nclass H(BaseHTTPRequestHandler):\n    def do_GET(self):\n        pass\n')"
run "$f"; expect_code 0; expect_no_out

tc TC-P11 "@override 가 붙은 메서드는 부모의 이름을 따르므로 통과한다 (PY-03 과잉 차단 방지)"
f="$(py a.py 'class W(QWidget):\n    @override\n    def paintEvent(self, event):\n        pass\n\n    @typing.override\n    @some_decorator(\n        1,\n    )\n    def keyPressEvent(self, event):\n        pass\n')"
run "$f"; expect_code 0; expect_no_out

tc TC-P12 "mixedCase 매개변수는 경고한다 — 여러 줄 시그니처도 본다 (PY-04)"
f="$(py a.py 'def find(orderId, *, pageSize: int = 10):\n    pass\n\n\ndef fetch(\n    self,\n    userName,\n):\n    pass\n')"; run "$f"; expect_code 0
expect_out "⚠️"; expect_out "PY-04"; expect_out "'order_id'"; expect_out "'page_size'"; expect_out "'user_name'"

tc TC-P13 "self · cls · 대문자만 · 기본값 · 타입 안의 쉼표는 경고하지 않는다 (PY-04 과잉 차단 방지)"
f="$(py a.py 'def fit(self, X, y, weights: Dict[str, int] = None, key=lambda a, b: a, *args, **kwargs):\n    pass\n\n\ndef make(cls, /, value=(1, 2)):\n    pass\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-P14 "mixedCase 대입 대상은 경고한다 (PY-05)"
f="$(py a.py 'userName = 1\nfirstName, lastName = 1, 2\ntotalCount: int = 0\n\n\nclass A:\n    itemCount: int\n\n    def __init__(self):\n        self.orderId = 1\n')"; run "$f"; expect_code 0
expect_out "PY-05"; expect_out "'user_name'"; expect_out "'last_name'"; expect_out "'total_count'"; expect_out "'item_count'"; expect_out "'order_id'"

tc TC-P15 "상수 · CapWords 별칭 · 호출 인자 · 다른 객체 속성은 경고하지 않는다 (PY-05 과잉 차단 방지)"
f="$(py a.py 'MAX_RETRY_COUNT = 3\nUserId = NewType("UserId", int)\nresult = call(\n    keyArg=1,\n    other=dict(innerKey=2),\n)\nrequest.userId = 1\nif a == b:\n    pass\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-P16 "Error 로 끝나지 않는 예외 클래스는 경고한다 (PY-06)"
f="$(py a.py 'class InvalidOrder(ValueError):\n    pass\n\n\nclass PaymentFailedException(Exception):\n    pass\n\n\nclass Retry(app.errors.BaseException):\n    pass\n')"; run "$f"; expect_code 0
expect_out "PY-06"; expect_out "'InvalidOrderError'"; expect_out "'PaymentFailedError'"; expect_out "'RetryError'"

tc TC-P17 "Error 로 끝나는 예외 · 예외가 아닌 클래스는 경고하지 않는다 (PY-06 과잉 차단 방지)"
f="$(py a.py 'class OrderNotFoundError(DomainError):\n    pass\n\n\nclass Order(Base, metaclass=ErrorMeta):\n    pass\n\n\nclass Deprecated(UserWarning):\n    pass\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-P18 "주석 · 문자열 · docstring 안의 단어는 코드로 읽지 않는다"
f="$(py a.py '"""모듈 설명.\n\nclass not_real:\n    def AlsoNot(self): pass\n"""\n# def BadName(): pass\nlabel = "class bad_name"\nsql = '"'"'def Bad(): pass'"'"'\n\n\ndef ok():\n    """def Inner(): pass"""\n    doc = """\nuserName = 1\n"""\n')"; run "$f"; expect_code 0; expect_no_out

tc TC-P19 "# noqa · # noqa: N8xx 는 그 줄을 건너뛰고, N8 코드가 없는 noqa 는 건너뛰지 않는다"
f="$(py a.py 'def legacyOne():  # noqa\n    pass\n\n\ndef legacyTwo():  # noqa: N802\n    pass\n\n\ndef legacyThree():  # noqa: E501\n    pass\n')"; run "$f"; expect_code 2
expect_out "'legacy_three'"; expect_not "legacyOne"; expect_not "legacyTwo"

tc TC-P20 "디렉터리를 주면 하위 *.py 를 보고 venv · migrations · alembic/versions 는 건너뛴다"
rm -rf "$TMP/proj"; mkdir -p "$TMP/proj/app" "$TMP/proj/.venv/lib" "$TMP/proj/venv/lib/site-packages/pkg" "$TMP/proj/app/migrations" "$TMP/proj/alembic/versions" "$TMP/proj/dist"
printf 'class bad_one:\n    pass\n' > "$TMP/proj/app/models.py"
printf 'class bad_two:\n    pass\n' > "$TMP/proj/.venv/lib/bad_two.py"
printf 'class bad_three:\n    pass\n' > "$TMP/proj/venv/lib/site-packages/pkg/bad_three.py"
printf 'x = 1\n' > "$TMP/proj/app/migrations/0001_initial.py"
printf 'x = 1\n' > "$TMP/proj/alembic/versions/3512b954651e_add_account.py"
printf 'class bad_four:\n    pass\n' > "$TMP/proj/dist/bad_four.py"
run "$TMP/proj"; expect_code 2; expect_out "bad_one"; expect_not "bad_two"; expect_not "bad_three"; expect_not "0001"; expect_not "3512"; expect_not "bad_four"

tc TC-P21 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
rm -rf "$TMP/r"; mkdir -p "$TMP/r/.claude/worktrees/w/src"
printf 'class bad_five:\n    pass\n' > "$TMP/r/.claude/worktrees/w/src/models.py"
run --all "$TMP/r/.claude/worktrees/w"; expect_code 2; expect_out "bad_five"

tc TC-P22 "--all 은 루트의 .claude/worktrees 를 건너뛴다"
run --all "$TMP/r"; expect_code 0

# --- B. 훅 -------------------------------------------------------------------
tc TC-P30 "Write 로 위반 파일을 새로 만들면 막는다 — 모듈 파일 이름 · 클래스 · 함수"
rm -rf "$SRC"; mkdir -p "$SRC"
run_stdin "$(payload_write "$SRC/app/orderService.py" 'class order_service:\n    def CreateOrder(self): pass\n')"; expect_code 2
expect_out "PY-01"; expect_out "PY-02"; expect_out "PY-03"; expect_out "'OrderService'"; expect_out "'create_order'"

tc TC-P31 "Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다"
run_stdin "$(payload_write "$SRC/order_service.py" "$CLEAN")"; expect_code 0; expect_no_out

tc TC-P32 "레거시 파일의 다른 줄을 Edit 하면 기존 위반(파일 이름 포함)으로 막지 않는다"
f="$(py legacyModule.py 'class legacy_dto:\n    def Get(self):\n        return 1\n')"
run_stdin "$(payload_edit "$f" 'return 1' 'return 2')"; expect_code 0; expect_no_out

tc TC-P33 "Edit 가 새 위반을 만들면 그것만 보고한다"
run_stdin "$(payload_edit "$f" '        return 1' '        return 1\n\n    def Put(self):\n        return 2')"; expect_code 2
expect_out "'put'"; expect_not "'get'"; expect_not "PY-01"; expect_not "PY-02"

tc TC-P34 "이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교)"
f="$(py g.py 'class G:\n    def Run(self):\n        pass\n')"
run_stdin "$(payload_edit "$f" '    def Run(self):\n        pass' '    def Run(self):\n        pass\n\n    def Run(self):\n        pass')"; expect_code 2; expect_out "'run'"

tc TC-P35 "Edit 로 위반을 고치면 통과한다"
run_stdin "$(payload_edit "$f" 'def Run(self)' 'def run(self)')"; expect_code 0

tc TC-P36 "replace_all 을 적용한 결과를 본다"
f="$(py h.py 'def total():\n    return 1\n\n\nx = total()\n')"
run_stdin "$(payload_edit "$f" 'total' 'GrandTotal' true)"; expect_code 2; expect_out "'grand_total'"

tc TC-P37 "한글이 섞인 파일도 치환 위치가 맞다"
f="$(py i.py '# 주문 서비스 — 한글 주석\n"""한글 docstring."""\n\n\ndef total():\n    pass\n')"
run_stdin "$(payload_edit "$f" 'def total():' 'def TotalSum():')"; expect_code 2; expect_out "'total_sum'"

tc TC-P38 "경고만 있으면 additionalContext 로 알리고 통과한다"
run_stdin "$(payload_write "$SRC/errors.py" 'class InvalidOrder(ValueError):\n    pass\n\n\ndef find(orderId):\n    pass\n')"; expect_code 0
expect_out '"additionalContext"'; expect_out "PY-06"; expect_out "PY-04"

tc TC-P39 "*.py 가 아니면 보지 않는다"
run_stdin "$(payload_write "$SRC/notes.md" 'class bad_name: pass')"; expect_code 0; expect_no_out

tc TC-P40 "가상환경 · 마이그레이션 아래 파일은 보지 않는다"
run_stdin "$(payload_write "$TMP/p/.venv/lib/python3.12/site-packages/BadPkg.py" 'class bad_gen:\n    pass\n')"; expect_code 0; expect_no_out
run_stdin "$(payload_write "$TMP/p/app/migrations/0002_auto.py" 'x = 1\n')"; expect_code 0; expect_no_out

tc TC-P41 "PostToolUse 는 보지 않는다"
run_stdin '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/x/BadName.py","content":"class bad_name: pass"}}'
expect_code 0; expect_no_out

tc TC-P42 "빈 입력 · 경로 없는 입력은 통과한다"
run_stdin ''; expect_code 0
run_stdin '{"hook_event_name":"PreToolUse","tool_input":{}}'; expect_code 0

tc TC-P43 "프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로)"
mkdir -p "$TMP/build/proj"
run_stdin_in "$TMP/build/proj" "$(jq -n --arg p "$TMP/build/proj/app/svc.py" --arg c "$(printf '%b' 'class order_x:\n    pass\n')" \
  '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $p, content: $c}}')"
expect_code 2; expect_out "PY-02"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
