#!/usr/bin/env bash
# scripts/reference-validate.sh 의 회귀 테스트. 네트워크 없이 curl 스텁으로 돈다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/reference-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/reference-validate-tc.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
unset REFERENCE_VALIDATE REFERENCE_VALIDATE_LIMIT
export STUB="$TMP/stub"
mkdir -p "$STUB" "$TMP/bin" "$TMP/docs"

# 스텁: routes 의 "부분 문자열 \037 상태 \037 본문" 첫 일치로 답한다. 상태 timeout 은 응답 없음
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w|-m|-A) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s\n' "$url" >> "$STUB/calls"
while IFS=$'\037' read -r pat code body; do
  case "$url" in
    *"$pat"*)
      if [ "$code" = timeout ]; then printf '000'; exit 28; fi
      if [ -n "$out" ]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
      printf '%s' "$code"; exit 0 ;;
  esac
done < "$STUB/routes"
[ -n "$out" ] && : > "$out"
printf '404'
EOF
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH"

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
  export CLAUDE_PLUGIN_DATA="$TMP/data-$1"
  : > "$STUB/routes"; : > "$STUB/calls"
}
section() { flush_tc; echo "$1"; }
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
route() { printf '%s\037%s\037%s\n' "$1" "$2" "${3:-}" >> "$STUB/routes"; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$1" | "$SCRIPT" --hook 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_calls() { [ "$TC_ON" = 1 ] || return 0; local n; n="$(grep -c . "$STUB/calls" 2>/dev/null)"; [ "$n" = "$1" ] || fail_tc "curl 호출 $n 회 (기대 $1)"; }
expect_called() { [ "$TC_ON" = 1 ] || return 0; grep -qF -- "$1" "$STUB/calls" || fail_tc "'$1' 를 조회하지 않음"; }
expect_not_called() { [ "$TC_ON" = 1 ] || return 0; grep -qF -- "$1" "$STUB/calls" && fail_tc "'$1' 를 조회하면 안 됩니다"; return 0; }
write_payload() { jq -n --arg f "$1" --arg c "$2" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $f, content: $c}}'; }
edit_payload() { jq -n --arg f "$1" --arg o "$2" --arg n "$3" '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}'; }
doc() { printf '%s\n' "$2" > "$TMP/docs/$1"; printf '%s' "$TMP/docs/$1"; }

GOOD_DOI="10.1038/nature12373"
NOT_RETRACTED='{"is_retracted": false}'

section "== A. 훅 차단 (RS-01 · RS-02)"

tc TC-V01 "등록된 DOI 를 Write → 통과, 출력 없음"
route "handles/$GOOD_DOI" 200 '{"responseCode":1}'
route "openalex" 200 "$NOT_RETRACTED"
run_hook "$(write_payload "$TMP/docs/a.md" "참고 $GOOD_DOI.")"
expect_code 0; expect_no_out; expect_called "handles/$GOOD_DOI"

tc TC-V02 "없는 DOI 를 Write → deny, 메시지에 그 DOI (RS-01)"
route "handles/10.99999/fake.1" 404 '{"responseCode":100}'
run_hook "$(write_payload "$TMP/docs/b.md" "가짜 10.99999/fake.1 인용")"
expect_code 0; expect_out '"permissionDecision": "deny"'; expect_out "RS-01"; expect_out "DOI 10.99999/fake.1"

tc TC-V03 "없는 arXiv ID 를 Edit 의 new_string 에 → deny (RS-02)"
route "abs/2399.99999" 404 ''
run_hook "$(edit_payload "$(doc c.md '# 문서')" "# 문서" "# 문서 arXiv:2399.99999")"
expect_out '"permissionDecision": "deny"'; expect_out "arXiv ID 2399.99999"

tc TC-V04 "old_string 에 이미 있던 식별자는 새로 생긴 것이 아니다 → 조회 안 함"
run_hook "$(edit_payload "$(doc d.md 'x 10.99999/old.1')" "x 10.99999/old.1" "y 10.99999/old.1")"
expect_code 0; expect_no_out; expect_calls 0

tc TC-V05 "파일에 이미 있던 식별자를 Write 로 다시 쓰면 조회 안 함, 새 것만 조회"
route "handles/10.1234/new" 200 '{}'
route "openalex" 200 "$NOT_RETRACTED"
f="$(doc e.md 'x 10.99999/old.2')"
run_hook "$(write_payload "$f" "x 10.99999/old.2 y 10.1234/new")"
expect_no_out; expect_not_called "old.2"; expect_called "handles/10.1234/new"

tc TC-V06 "없는 것과 있는 것이 섞이면 없는 것만 메시지에"
route "handles/$GOOD_DOI" 200 '{}'
route "handles/10.99999/fake.2" 404 '{}'
route "openalex" 200 "$NOT_RETRACTED"
run_hook "$(write_payload "$TMP/docs/f.md" "$GOOD_DOI 10.99999/fake.2")"
expect_out "10.99999/fake.2"; expect_not "DOI $GOOD_DOI"

tc TC-V07 "MultiEdit 의 new_string 들을 모두 본다"
route "handles/10.99999/fake.3" 404 '{}'
p="$(jq -n --arg f "$TMP/docs/g.md" '{tool_name: "MultiEdit", tool_input: {file_path: $f, edits: [{old_string: "a", new_string: "b"}, {old_string: "c", new_string: "d 10.99999/fake.3"}]}}')"
run_hook "$p"
expect_out '"permissionDecision": "deny"'; expect_out "fake.3"

section "== B. 알림 · 통과 (RS-03 · RS-04)"

tc TC-V10 "철회된 DOI → 통과 + additionalContext (RS-03)"
route "handles/10.1016/s0140-6736(97)11096-0" 200 '{}'
route "openalex" 200 '{"is_retracted": true}'
run_hook "$(write_payload "$TMP/docs/h.md" "Wakefield 10.1016/S0140-6736(97)11096-0")"
expect_code 0; expect_not '"deny"'; expect_out "additionalContext"; expect_out "RS-03"

tc TC-V11 "조회 시간 초과 → 통과 + 확인 못 함 알림 (RS-04)"
route "handles/" timeout ''
run_hook "$(write_payload "$TMP/docs/i.md" "$GOOD_DOI")"
expect_code 0; expect_not '"deny"'; expect_out "RS-04"

tc TC-V12 "arXiv 429 → arXiv DOI 로 다시 확인해 있으면 통과"
route "abs/" 429 'Rate exceeded.'
route "handles/10.48550/arxiv.1706.03762" 200 '{}'
run_hook "$(write_payload "$TMP/docs/j.md" "arXiv:1706.03762v5")"
expect_code 0; expect_no_out; expect_called "handles/10.48550/arxiv.1706.03762"

tc TC-V14 "arXiv 429 · arXiv DOI 도 없음 → deny (RS-02)"
route "abs/" 429 'Rate exceeded.'
route "handles/10.48550/" 404 '{}'
run_hook "$(write_payload "$TMP/docs/j2.md" "arXiv:2399.99999")"
expect_out '"permissionDecision": "deny"'; expect_out "arXiv ID 2399.99999"

tc TC-V15 "arXiv 429 · arXiv DOI 도 시간 초과 → 차단하지 않고 확인 못 함 (RS-04)"
route "abs/" 429 'Rate exceeded.'
route "handles/" timeout ''
run_hook "$(write_payload "$TMP/docs/j3.md" "arXiv:1706.03762")"
expect_not '"deny"'; expect_out "RS-04"

tc TC-V13 "상한을 넘은 식별자는 조회하지 않고 확인 못 함으로 알린다"
route "handles/" 200 '{}'
route "openalex" 200 "$NOT_RETRACTED"
OUT="$(write_payload "$TMP/docs/k.md" "10.1234/a 10.1234/b 10.1234/c" | REFERENCE_VALIDATE_LIMIT=2 "$SCRIPT" --hook 2>&1)"
expect_out "RS-04"; expect_not_called "handles/10.1234/c"

section "== C. 검사 대상"

tc TC-V20 ".md 가 아닌 파일은 검사 안 함"
run_hook "$(write_payload "$TMP/docs/a.txt" "10.99999/fake.9")"
expect_code 0; expect_no_out; expect_calls 0

tc TC-V21 "REFERENCE_VALIDATE=off 면 검사 안 함"
OUT="$(write_payload "$TMP/docs/l.md" "10.99999/fake.9" | REFERENCE_VALIDATE=off "$SCRIPT" --hook 2>&1)"; CODE=$?
expect_code 0; expect_no_out; expect_calls 0

tc TC-V22 "식별자 없음 → 조회 0회"
run_hook "$(write_payload "$TMP/docs/m.md" "# 그냥 문서 10.5 버전")"
expect_no_out; expect_calls 0

tc TC-V23 "Read 같은 다른 도구 → 검사 안 함"
run_hook '{"tool_name":"Read","tool_input":{"file_path":"/x.md"}}'
expect_no_out; expect_calls 0

section "== D. 식별자 추출"

tc TC-V30 "문장부호 · 마크다운 링크 꼬리를 떼고, 괄호가 든 DOI 는 살린다"
route "handles/" 200 '{}'
route "openalex" 200 "$NOT_RETRACTED"
run "$(doc n.md '[논문](https://doi.org/10.1000/abc.def). 그리고 (10.1016/S0140-6736(20)30183-5), 10.2000/xyz;')"
expect_called "handles/10.1000/abc.def"; expect_called "handles/10.1016/s0140-6736(20)30183-5"; expect_called "handles/10.2000/xyz"
expect_not_called "abc.def)"; expect_not_called "xyz;"

tc TC-V31 "arXiv 새 형식 · 버전 · 옛 형식 · URL 형식을 뽑는다"
route "abs/" 200 ''
run "$(doc o.md 'arXiv:2301.00001v2, arxiv.org/abs/1706.03762 와 arXiv:hep-th/9901001')"
expect_called "abs/2301.00001v2"; expect_called "abs/1706.03762"; expect_called "abs/hep-th/9901001"

tc TC-V32 "arXiv 접두사 없는 숫자(2023.12345)는 arXiv ID 로 보지 않는다"
run "$(doc p.md '수치 2023.12345 와 버전 1.2.3')"
expect_calls 0

tc TC-V33 "한국어 조사 · 전각 문장부호가 붙은 DOI 는 조사 앞에서 끊는다"
route "handles/" 200 '{}'
route "openalex" 200 "$NOT_RETRACTED"
run "$(doc ko.md '리뷰(10.1038/nature14539)를 참고. 10.1038/nature14539에서 보듯이, DOI: 10.1038/nature14540，参照')"
expect_code 0; expect_called "handles/10.1038/nature14539"; expect_called "handles/10.1038/nature14540"
expect_not_called "nature14539)"; expect_not_called "nature14539%"; expect_not "에서"

tc TC-V34 "출판사 URL 꼬리(bioRxiv v1 · .pdf · /abstract · 쿼리 · 끝 슬래시)를 뗀다"
route "handles/" 200 '{}'
route "openalex" 200 "$NOT_RETRACTED"
run "$(doc pub.md 'biorxiv.org/content/10.1101/2020.03.22.002386v1 link.springer.com/content/pdf/10.1007/s11263-015-0816-y.pdf wiley.com/doi/10.1002/andp.19053221004/abstract plos.org/file?id=10.1371/journal.pone.0185809&type=printable 10.1145/3290605.3300857/')"
expect_code 0
expect_called "handles/10.1101/2020.03.22.002386"; expect_not_called "002386v1"
expect_called "handles/10.1007/s11263-015-0816-y"; expect_not_called ".pdf"
expect_called "handles/10.1002/andp.19053221004"; expect_not_called "/abstract"
expect_called "handles/10.1371/journal.pone.0185809"; expect_not_called "printable"
expect_called "handles/10.1145/3290605.3300857"

tc TC-V35 "<> 가 든 SICI DOI 는 살리고 인코딩해 조회한다, 자동 링크 꺾쇠는 뗀다"
route "handles/" 200 '{}'
route "openalex" 200 "$NOT_RETRACTED"
run "$(doc sici.md '10.1002/(SICI)1097-0258(19980430)17:8<857::AID-SIM777>3.0.CO;2-E 와 <https://doi.org/10.1038/nature12373>')"
expect_called "handles/10.1002/(sici)1097-0258(19980430)17:8%3C857::aid-sim777%3E3.0.co;2-e"; expect_called "handles/10.1038/nature12373"
expect_not_called "nature12373%3E"

tc TC-V36 "주제 분류가 붙은 옛 arXiv ID(math.DG/0211159)는 math/0211159 로 조회한다"
route "abs/" 200 ''
run "$(doc oldax.md 'Perelman, arXiv:math.DG/0211159')"
expect_called "abs/math/0211159"; expect_not_called "math.DG"

tc TC-V37 "인라인 코드 · 코드 펜스 안의 예시 식별자는 보지 않는다"
route "handles/" 404 '{}'
p="$(jq -n --arg f "$TMP/docs/code.md" --arg c "$(printf '예시: `10.1234/example.2024` 처럼 쓴다\n\n```\narXiv:2399.99999\n```\n')" '{tool_name: "Write", tool_input: {file_path: $f, content: $c}}')"
run_hook "$p"
expect_code 0; expect_no_out; expect_calls 0

section "== E. 파일 모드 (/reference-validate)"

tc TC-V40 "없는 DOI → 종료 1, ❌ RS-01"
route "handles/10.99999/fake.4" 404 '{}'
run "$(doc q.md '10.99999/fake.4')"
expect_code 1; expect_out "❌ RS-01"

tc TC-V41 "모두 있으면 종료 0"
route "handles/" 200 '{}'
route "openalex" 200 "$NOT_RETRACTED"
run "$(doc r.md "$GOOD_DOI")"
expect_code 0; expect_out "✅ DOI $GOOD_DOI"

tc TC-V42 "--urls: 404 는 실패, 403 은 경고 (RS-05 · RS-06)"
route "example.org/gone" 404 ''
route "example.org/paywall" 403 ''
route "example.org/ok" 200 ''
run --urls "$(doc s.md 'https://example.org/gone https://example.org/paywall https://example.org/ok.')"
expect_code 1; expect_out "❌ RS-05 404 https://example.org/gone"; expect_out "⚠️  RS-06 403"; expect_out "✅ 200 https://example.org/ok"

tc TC-V45 "--urls: 괄호가 든 URL 은 살리고 문장 끝 괄호만 뗀다"
route "Mercury_(planet)" 200 ''
route "example.org/x" 200 ''
run --urls "$(doc paren.md 'https://en.wikipedia.org/wiki/Mercury_(planet) 와 (https://example.org/x).')"
expect_code 0; expect_called "wiki/Mercury_(planet)"; expect_called "https://example.org/x"; expect_not_called "example.org/x)"

tc TC-V43 "--urls 없이는 URL 을 조회하지 않는다"
run "$(doc t.md 'https://example.org/gone')"
expect_code 0; expect_calls 0

tc TC-V44 "없는 파일 → 종료 1"
run "$TMP/docs/none.md"
expect_code 1

section "== F. 캐시"

tc TC-V50 "한 번 있다고 확인한 DOI 는 다시 조회하지 않고, 철회 여부도 캐시에서 낸다"
route "handles/" 200 '{}'
route "openalex" 200 '{"is_retracted": true}'
f="$(doc u.md '10.3000/retracted')"
run "$f"; : > "$STUB/calls"; run "$f"
expect_calls 0; expect_out "RS-03"

tc TC-V51 "없다고 나온 DOI 는 캐시하지 않는다"
route "handles/" 404 '{}'
f="$(doc v.md '10.99999/fake.5')"
run "$f"; : > "$STUB/calls"; run "$f"
expect_calls 1

tc TC-V52 "남이 만든 캐시 디렉터리는 읽지도 쓰지도 않는다"
route "handles/" 404 '{}'
mkdir -p "$TMP/foreign"; ln -s /dev/null "$TMP/foreign/checked.txt"
OUT="$(printf 'x 10.99999/fake.6\n' > "$TMP/docs/w.md"; CLAUDE_PLUGIN_DATA="$TMP/foreign" "$SCRIPT" "$TMP/docs/w.md" 2>&1)"; CODE=$?
expect_code 1; expect_out "RS-01"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
