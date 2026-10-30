#!/usr/bin/env bash
# scripts/evidence-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/evidence-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/evidence-tc.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
export CLAUDE_PLUGIN_DATA="$TMP/data"
unset EVIDENCE_REVIEW_GATE EVIDENCE_REVIEW_MIN_LINES
W="$TMP/proj"
mkdir -p "$W" && cd "$W" || exit 1
git init -q -b main . && git commit -q --allow-empty -m init

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
  rm -rf "$CLAUDE_PLUGIN_DATA"
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" --hook 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
blocked() { expect_out '"decision": "block"'; }

edit_p() { # $1=경로 $2=old $3=new [$4=session]
  jq -n --arg f "$1" --arg o "$2" --arg n "$3" --arg s "${4:-s1}" --arg w "$W" \
    '{hook_event_name: "PostToolUse", tool_name: "Edit", session_id: $s, cwd: $w, tool_input: {file_path: $f, old_string: $o, new_string: $n}}'
}
write_p() { # $1=경로 $2=content [$3=session]
  jq -n --arg f "$1" --arg c "$2" --arg s "${3:-s1}" --arg w "$W" \
    '{hook_event_name: "PostToolUse", tool_name: "Write", session_id: $s, cwd: $w, tool_input: {file_path: $f, content: $c}}'
}
agent_p() { # $1=subagent_type [$2=session]
  jq -n --arg t "$1" --arg s "${2:-s1}" '{hook_event_name: "PostToolUse", tool_name: "Agent", session_id: $s, tool_input: {subagent_type: $t, prompt: "x"}}'
}
prompt_p() { # $1=prompt [$2=session]
  jq -n --arg p "$1" --arg s "${2:-s1}" --arg w "$W" '{hook_event_name: "UserPromptSubmit", session_id: $s, cwd: $w, prompt: $p}'
}
stop_p() { # [$1=session] [$2=stop_hook_active] [$3=last_assistant_message]
  jq -n --arg s "${1:-s1}" --argjson a "${2:-false}" --arg m "${3:-}" --arg w "$W" \
    '{hook_event_name: "Stop", session_id: $s, cwd: $w, stop_hook_active: $a, last_assistant_message: $m}'
}
L3="$(printf 'a = 1\nb = 2\nc = 3')"

echo "== A. 테스트 약화 신호 (E-20)"

tc TC-E01 "테스트 파일에 skip 표지를 더하면 알림, 같은 편집이 코드 파일이면 조용"
run_hook "$(edit_p "$W/src/a.test.ts" "it('x', () => {})" "it.skip('x', () => {})")"
expect_code 0; expect_out "E-20"; expect_out "skip · focus 표지 0 → 1"
run_hook "$(edit_p "$W/src/a.ts" "it('x', () => {})" "it.skip('x', () => {})")"
expect_not "E-20"

tc TC-E02 "단언이 줄면 알림, 그대로거나 늘면 조용"
run_hook "$(edit_p "$W/tests/test_a.py" "$(printf 'assert x == 1\nassert y == 2')" "assert x == 1")"
expect_out "단언 2 → 1"
run_hook "$(edit_p "$W/tests/test_a.py" "assert x == 1" "$(printf 'assert x == 1\nassert y == 2')")"
expect_not "E-20"
run_hook "$(edit_p "$W/src/FooTest.kt" "assertEquals(1, f())" "assertEquals(2, f())")"
expect_not "E-20"

tc TC-E03 "Write 는 HEAD 의 파일과 비교한다"
if [ "$TC_ON" = 1 ]; then mkdir -p "$W/pkg"; printf 'func TestA(t *testing.T) {\n\tif f() != 1 { t.Fatal() }\n}\n' > "$W/pkg/a_test.go"; git add pkg && git commit -qm t; fi
run_hook "$(write_p "$W/pkg/a_test.go" "$(printf 'func TestA(t *testing.T) {\n\tt.Skip(\"later\")\n}\n')")"
expect_out "skip · focus 표지 0 → 1"
run_hook "$(write_p "$W/pkg/a_test.go" "$(printf 'func TestA(t *testing.T) {\n\tif f() != 2 { t.Fatal() }\n}\n')")"
expect_not "E-20"

tc TC-E04 "테스트 파일 판정 — 경로 · 이름 규약은 잡고 비슷한 이름은 놓아준다"
for f in src/test/A.java app/__tests__/a.js spec/a_spec.rb a_test.go a.spec.ts test_a.py BarTests.cs src/aiTest/kotlin/A.kt e2e/login.ts a.cy.ts a.e2e-spec.ts src/foo/tests.rs; do
  run_hook "$(edit_p "$W/$f" "it('x')" "it.only('x')")"; expect_out "E-20"
done
for f in src/contest.ts src/latest.go src/attest.py lib/testing.rb src/latest/a.ts; do
  run_hook "$(edit_p "$W/$f" "it('x')" "it.only('x')")"; expect_not "E-20"
done

tc TC-E04b "테스트 판정은 프로젝트 기준 경로로 한다 — 프로젝트가 tests/ 아래여도 코드는 코드다"
if [ "$TC_ON" = 1 ]; then
  P2="$TMP/tests/app"; mkdir -p "$P2"
  OUT="$(jq -n --arg f "$P2/src/main.py" --arg w "$P2" '{hook_event_name: "PostToolUse", tool_name: "Edit", session_id: "s1", cwd: $w, tool_input: {file_path: $f, old_string: "assert x", new_string: "x"}}' | "$SCRIPT" --hook 2>&1)"
  expect_not "E-20"
fi

tc TC-E05 "이름 안의 fit( · xit( 는 표지가 아니다"
run_hook "$(edit_p "$W/a.test.js" "x()" "benefit(1); exit(0); profit(2)")"
expect_not "E-20"
run_hook "$(edit_p "$W/a.test.js" "it('x')" "fit('x')")"
expect_out "E-20"

tc TC-E06 "MultiEdit 은 편집 전부를 합쳐 본다"
run_hook "$(jq -n --arg f "$W/a.test.js" --arg w "$W" '{hook_event_name: "PostToolUse", tool_name: "MultiEdit", session_id: "s1", cwd: $w, tool_input: {file_path: $f, edits: [{old_string: "expect(a).toBe(1)", new_string: ""}, {old_string: "expect(b).toBe(2)", new_string: "b"}]}}')"
expect_out "단언 2 → 0"

tc TC-E07 "언어별 단언 · skip 표지를 센다"
while IFS='|' read -r file a; do
  run_hook "$(edit_p "$W/$file" "$a" "x")"; expect_out "단언 1 → 0"
done <<'EOF'
a_test.go|assert.Equal(t, 1, f())
tests/a.rs|assert_eq!(f(), 1);
FooTests.cs|Assert.That(f(), Is.EqualTo(1));
a.test.js|assert.strictEqual(f(), 1)
test/a_test.rb|assert_equal 1, f
FooSpec.kt|f() shouldBe 1
EOF
while IFS='|' read -r file a; do
  run_hook "$(edit_p "$W/$file" "x" "$a")"; expect_out "skip · focus 표지 0 → 1"
done <<'EOF'
a_test.go|t.Skipf("later %d", 1)
FooTests.cs|[Ignore]
FooTests.cs|[Fact(Skip = "flaky")]
EOF

tc TC-E08 "한글 경로의 추적 파일도 HEAD 와 비교한다"
if [ "$TC_ON" = 1 ]; then mkdir -p "$W/한글"; printf 'expect(1)\nexpect(2)\n' > "$W/한글/a.test.ts"; git add . && git commit -qm k; fi
run_hook "$(write_p "$W/한글/a.test.ts" "expect(1)")"
expect_out "단언 2 → 1"

tc TC-E09 "경로의 | · & 를 그대로 기록하고 stderr 가 없다"
run_hook "$(edit_p "$W/R&D|x/a.test.ts" "expect(1)" "x")"; expect_out "단언 1 → 0"; expect_not "sed:"
[ "$TC_ON" = 1 ] && { grep -qF "$W/R&D|x/a.test.ts: 단언 1 → 0" "$CLAUDE_PLUGIN_DATA/s1.signals" || fail_tc "신호 기록이 경로와 다르다"; }

echo "== B. 완료 게이트 (E-30)"

tc TC-E10 "코드를 3줄 바꾸고 검증 없이 끝내면 한 번 되돌린다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"; expect_no_out
run_hook "$(stop_p s1 false "고쳤습니다.")"
expect_code 0; blocked; expect_out "E-30"; expect_out "$W/src/a.py"; expect_out "evidence-reviewer"

tc TC-E11 "2줄이면 막지 않고 기록을 지운다"
run_hook "$(edit_p "$W/src/a.py" "" "$(printf 'a\nb')")"
run_hook "$(stop_p)"; expect_no_out
[ "$TC_ON" = 1 ] && [ -e "$CLAUDE_PLUGIN_DATA/s1.edits" ] && fail_tc "기록이 남았다"

tc TC-E12 "바꾼 줄은 요청 전체로 합친다 — 2줄 + 1줄이면 막는다"
run_hook "$(edit_p "$W/src/a.py" "" "$(printf 'a\nb')")"
run_hook "$(edit_p "$W/src/b.py" "" "c")"
run_hook "$(stop_p)"; blocked; expect_out "$W/src/b.py"

tc TC-E13 "지운 줄도 센다 — 3줄을 지우면 막는다"
run_hook "$(edit_p "$W/src/a.py" "$L3" "")"
run_hook "$(stop_p)"; blocked

tc TC-E14 "문서만 고쳤으면 막지 않는다 (DS-30 몫)"
run_hook "$(edit_p "$W/README.md" "" "$L3")"
run_hook "$(edit_p "$W/docs/NOTES.TXT" "" "$L3")"
run_hook "$(stop_p)"; expect_no_out

tc TC-E15 "프로젝트 밖 파일은 세지 않는다"
run_hook "$(edit_p "$TMP/other/a.py" "" "$L3")"
run_hook "$(stop_p)"; expect_no_out

tc TC-E16 "이 훅이 되돌린 뒤의 종료(stop_hook_active)는 통과시키고 기록을 지운다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(stop_p)"; blocked
run_hook "$(stop_p s1 true)"; expect_no_out
run_hook "$(stop_p)"; expect_no_out

tc TC-E16b "다른 훅이 되돌려 stop_hook_active 가 true 여도 아직 안 막았으면 막는다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(stop_p s1 true)"; blocked
run_hook "$(stop_p s1 true)"; expect_no_out

tc TC-E17 "evidence-reviewer 가 돌면 통과, 다른 에이전트는 통과시키지 않는다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(agent_p Explore)"
run_hook "$(stop_p)"; blocked
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(agent_p common-evidence-review:evidence-reviewer)"
run_hook "$(stop_p)"; expect_no_out

tc TC-E17b "검증 뒤에 3줄 이상 또 고치면 다시 막는다. 검증 뒤 편집만 센다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(agent_p evidence-reviewer)"
run_hook "$(edit_p "$W/src/b.py" "" "$L3")"
run_hook "$(stop_p)"; blocked; expect_out "$W/src/b.py"; expect_not "$W/src/a.py"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(agent_p evidence-reviewer)"
run_hook "$(edit_p "$W/src/b.py" "" "x")"
run_hook "$(stop_p)"; expect_no_out

tc TC-E18 "EVIDENCE_REVIEW_GATE=0 이면 기록도 차단도 없다"
if [ "$TC_ON" = 1 ]; then
  export EVIDENCE_REVIEW_GATE=0
  run_hook "$(prompt_p "고쳐줘")"; run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
  run_hook "$(stop_p)"; expect_no_out
  [ -n "$(ls -A "$CLAUDE_PLUGIN_DATA" 2>/dev/null)" ] && fail_tc "기록이 생겼다"
  unset EVIDENCE_REVIEW_GATE
fi

tc TC-E19 "세션마다 따로 센다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3" s1)"
run_hook "$(stop_p s2)"; expect_no_out
run_hook "$(stop_p s1)"; blocked

tc TC-E20 "요청 원문을 기록하고 경로를 알린다. 백그라운드 알림은 뺀다"
run_hook "$(prompt_p "빈 입력에서 parse 가 죽는 걸 고쳐줘")"
run_hook "$(prompt_p "<task-notification> done </task-notification>")"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(stop_p)"; blocked; expect_out "$CLAUDE_PLUGIN_DATA/s1.request"
if [ "$TC_ON" = 1 ]; then
  grep -qF "parse 가 죽는" "$CLAUDE_PLUGIN_DATA/s1.request" || fail_tc "요청 원문이 없다"
  grep -qF "task-notification" "$CLAUDE_PLUGIN_DATA/s1.request" && fail_tc "백그라운드 알림이 들어갔다"
fi
run_hook "$(stop_p s1 true)"
[ "$TC_ON" = 1 ] && [ -e "$CLAUDE_PLUGIN_DATA/s1.request" ] && fail_tc "통과한 뒤에도 요청 기록이 남았다"

tc TC-E20b "새 요청은 앞 요청(중단돼 Stop 이 안 돈 것)의 기록을 잇지 않는다"
run_hook "$(prompt_p "첫 요청")"
run_hook "$(edit_p "$W/src/a.py" "" "$(printf 'a\nb')")"
run_hook "$(prompt_p "둘째 요청")"
run_hook "$(edit_p "$W/src/b.py" "" "c")"
run_hook "$(stop_p)"; expect_no_out

tc TC-E21 "요청 기록이 없으면 대화의 요청을 쓰라고 알린다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
run_hook "$(stop_p)"; expect_out "요청 기록: 없음"

tc TC-E22 "최종 답에서 주장 후보를 뽑는다 — 코드 펜스 안은 빼고 10개까지, 문자 단위로 자른다"
if [ "$TC_ON" = 1 ]; then
  long="원인은 $(printf '가%.0s' $(seq 1 300))"
  msg="$(printf '## 결과\n\n- 빈 배열에서 죽는 버그를 고쳤습니다\n- 테스트 12개 통과\n그 밖의 설명\n```\necho 통과\n```\n%s\n' "$long")"
  for i in 1 2 3 4 5 6 7 8 9 10 11; do msg="$msg
필요 $i"; done
  run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
  run_hook "$(stop_p s1 false "$msg")"
  expect_out "  - 빈 배열에서 죽는 버그를 고쳤습니다"; expect_out "  - 테스트 12개 통과"
  expect_not "그 밖의 설명"; expect_not "echo 통과"; expect_not "필요 9"
  printf '%s' "$OUT" | jq -e . >/dev/null 2>&1 || fail_tc "출력이 올바른 JSON 이 아니다"
  printf '%s' "$OUT" | jq -r .reason | grep -q "원인은 가\{196\}$" || fail_tc "200자로 자르지 않았다"
fi

tc TC-E23 "기록된 테스트 약화 신호를 게이트 메시지에 넣는다"
run_hook "$(edit_p "$W/src/a.test.ts" "$(printf 'expect(a)\nexpect(b)\nexpect(c)')" "expect(a)")"
run_hook "$(stop_p)"; blocked; expect_out "테스트 약화 신호 (E-20)"; expect_out "단언 3 → 1"

tc TC-E23b "requirements.txt · CMakeLists.txt 는 문서가 아니라 설정으로 센다"
run_hook "$(edit_p "$W/requirements.txt" "" "$L3")"
run_hook "$(stop_p)"; blocked
run_hook "$(edit_p "$W/CMakeLists.txt" "" "$L3")"
run_hook "$(stop_p)"; blocked

tc TC-E24 "EVIDENCE_REVIEW_MIN_LINES 로 문턱을 바꾼다"
if [ "$TC_ON" = 1 ]; then
  export EVIDENCE_REVIEW_MIN_LINES=1
  run_hook "$(edit_p "$W/src/a.py" "x = 1" "x = 2")"
  run_hook "$(stop_p)"; blocked
  unset EVIDENCE_REVIEW_MIN_LINES
fi

tc TC-E25 "백그라운드로 띄운 evidence-reviewer 는 끝날 때(SubagentStop)까지 검증으로 치지 않는다"
run_hook "$(edit_p "$W/src/a.py" "" "$L3")"
[ "$TC_ON" = 1 ] && OUT="$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Agent", session_id: "s1", tool_input: {subagent_type: "evidence-reviewer", run_in_background: true}, tool_response: {isAsync: true, status: "async_launched"}}' | "$SCRIPT" --hook 2>&1)"
run_hook "$(stop_p)"; expect_no_out
[ "$TC_ON" = 1 ] && { [ -s "$CLAUDE_PLUGIN_DATA/s1.edits" ] || fail_tc "기다리는 동안 기록이 지워짐"; }
run_hook "$(jq -n '{hook_event_name: "SubagentStop", session_id: "s1", agent_type: "Explore"}')"
run_hook "$(stop_p)"; expect_no_out
[ "$TC_ON" = 1 ] && { [ -e "$CLAUDE_PLUGIN_DATA/s1.pending" ] || fail_tc "다른 에이전트의 SubagentStop 이 검증 중을 지움"; }
run_hook "$(jq -n '{hook_event_name: "SubagentStop", session_id: "s1", agent_type: "common-evidence-review:evidence-reviewer"}')"
[ "$TC_ON" = 1 ] && { [ -e "$CLAUDE_PLUGIN_DATA/s1.reviewed" ] && [ ! -e "$CLAUDE_PLUGIN_DATA/s1.pending" ] || fail_tc "SubagentStop 뒤 검증함이 아님"; }
run_hook "$(stop_p)"; expect_no_out

echo "== C. CLI --diff"

tc TC-E30 "기본 브랜치 대비 테스트 약화를 낸다. --strict 면 exit 2"
if [ "$TC_ON" = 1 ]; then
  D="$TMP/cli"; mkdir -p "$D/test" && cd "$D" && git init -q -b main . \
    && printf 'expect(1)\nexpect(2)\n' > test/a.test.js && printf 'x\n' > app.js && git add . && git commit -qm base \
    && git update-ref refs/remotes/origin/main HEAD && git checkout -qb work \
    && printf 'expect(1)\n' > test/a.test.js && printf 'it.skip(1)\n' > test/b.test.js && printf 'y\n' > app.js
  run --diff; expect_code 0; expect_out "test/a.test.js: E-20 단언 2 → 1"; expect_out "test/b.test.js: E-20 skip"; expect_not "app.js:"
  expect_out "테스트 파일 2개, E-20 신호 2건"
  run --diff --strict; expect_code 2
  mkdir -p sub && cd sub && run --diff; expect_out "테스트 파일 2개"; cd "$D" || exit 1
  git checkout -q -- test/a.test.js && rm -f test/b.test.js
  run --diff --strict; expect_code 0; expect_out "E-20 신호 0건"
  cd "$W" || exit 1
fi

tc TC-E31 "인자 없음 · 모르는 인자 · git 밖은 exit 1"
run; expect_code 1
run --bogus; expect_code 1
if [ "$TC_ON" = 1 ]; then mkdir -p "$TMP/nogit" && cd "$TMP/nogit" && run --diff; expect_code 1; cd "$W" || exit 1; fi

echo "== D. fail-open"

tc TC-E40 "훅 입력이 JSON 이 아니거나 jq 가 없으면 조용히 통과"
run_hook "not json"; expect_code 0; expect_no_out
if [ "$TC_ON" = 1 ]; then
  mkdir -p "$TMP/nobin"; ln -sf "$(command -v dirname)" "$TMP/nobin/dirname"
  OUT="$(stop_p | PATH="$TMP/nobin" "$(command -v bash)" "$SCRIPT" --hook 2>&1)"; CODE=$?
  expect_code 0; expect_no_out
fi

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
