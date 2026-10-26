#!/usr/bin/env bash
# 근거 리뷰 — E-20 테스트 약화 신호 · E-30 완료 게이트. 규칙: references/evidence-rules.md
#   evidence-validate.sh --hook             훅 (stdin 에 훅 입력)
#   evidence-validate.sh --diff [--strict]  기본 브랜치 대비 diff 의 E-20 신호
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES="$PLUGIN_ROOT/references/evidence-rules.md"
MIN_LINES="${EVIDENCE_REVIEW_MIN_LINES:-3}"
case "$MIN_LINES" in ''|*[!0-9]*) MIN_LINES=3 ;; esac

SKIP_RE='@Disabled|@Ignore([^A-Za-z]|$)|\.skip\(|\.only\(|(^|[^A-Za-z_.])(xit|xdescribe|xtest|fit|fdescribe)\(|\.todo\(|@pytest\.mark\.(skip|xfail)|@unittest\.skip|t\.Skip(f|Now)?\(|#\[ignore\]|\[Ignore(\]|\()|\(Skip[[:space:]]*='
ASSERT_RE='(^|[^A-Za-z_])([Aa]ssert[A-Za-z_]*!?|expect|verify|XCTAssert[A-Za-z]*)[[:space:]]*\(|(^|[^A-Za-z_])[Aa]ssert\.[A-Za-z]+[[:space:]]*\(|(^|[^A-Za-z_])should([A-Z][A-Za-z]*)?([^A-Za-z_]|$)|(^|[^A-Za-z_])require\.[A-Za-z]+\(|(^|[^A-Za-z_])assert[A-Za-z_]*[[:space:]]+[^(=[:space:]]'
CLAIM_RE='완료|고쳤|고침|수정했|해결|통과|원인|버그|오류|필요|때문|fixed|resolved|pass(es|ed|ing)?|root cause|bug|because'

die() { echo "evidence-validate: $*" >&2; exit 1; }

is_test() { # $1=프로젝트 기준 경로 — 절대 경로면 프로젝트 위 디렉터리 이름(~/tests/app)까지 걸린다
  local b="${1##*/}"
  case "/$1" in */test/*|*/tests/*|*/__tests__/*|*/spec/*|*/e2e/*|*/cypress/*|*/src/*Test/*) return 0 ;; esac
  case "$b" in *_test.*|*.test.*|*.spec.*|*-spec.*|*_spec.*|*Spec.*|*.cy.*|*.e2e.*|*Test.*|*Tests.*|tests.rs) return 0 ;; test_*.py) return 0 ;; esac
  return 1
}

is_doc() {
  case "$(printf '%s' "${1##*/}" | tr '[:upper:]' '[:lower:]')" in
    requirements*.txt|constraints*.txt|*-lock.txt|cmakelists.txt|robots.txt) return 1 ;;
    *.md|*.mdx|*.markdown|*.rst|*.txt|*.adoc) return 0 ;;
  esac
  return 1
}

count() { # $1=정규식 — stdin 에서 일치 개수
  grep -oE -- "$1" | wc -l | tr -d ' '
}

nonblank() { grep -c '[^[:space:]]' | tr -d ' '; }

signals() { # $1=고치기 전 파일 $2=고친 뒤 파일 → 신호 줄 (없으면 출력 없음)
  local s0 s1 a0 a1
  s0="$(count "$SKIP_RE" < "$1")"; s1="$(count "$SKIP_RE" < "$2")"
  a0="$(count "$ASSERT_RE" < "$1")"; a1="$(count "$ASSERT_RE" < "$2")"
  [ "$s1" -gt "$s0" ] && echo "skip · focus 표지 ${s0} → ${s1}"
  [ "$a1" -lt "$a0" ] && echo "단언 ${a0} → ${a1}"
  return 0
}

state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/common-evidence-review}"
  mkdir -p "$d" 2>/dev/null || return 1
  echo "$d"
}

state() { # $1=훅 입력 $2=확장자
  local sid d
  sid="$(printf '%s' "$1" | jq -r '.session_id // "nosession"' | tr -cd 'A-Za-z0-9_-')"
  d="$(state_dir)" || return 1
  echo "$d/${sid:-nosession}.$2"
}

clear_state() { # $1=훅 입력
  local x f
  for x in edits signals request reviewed blocked; do
    f="$(state "$1" "$x")" && rm -f "$f"
  done
}

hook_prompt() {
  local p f
  [ "${EVIDENCE_REVIEW_GATE:-1}" != 0 ] || exit 0
  p="$(printf '%s' "$1" | jq -r '.prompt // ""')"
  case "$p" in ''|'<task-notification>'*) exit 0 ;; esac
  clear_state "$1"   # 새 요청 — 중단돼 Stop 이 돌지 않은 요청의 기록을 잇지 않는다
  f="$(state "$1" request)" || exit 0
  { printf -- '--- %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"; printf '%s\n' "$p"; } > "$f"
  exit 0
}

hook_edit() {
  local f cwd tool before after n0 n1 n sig rel st msg t rv line
  f="$(printf '%s' "$1" | jq -r '.tool_input.file_path // ""')"
  [ -n "$f" ] || exit 0
  cwd="$(printf '%s' "$1" | jq -r '.cwd // ""')"
  tool="$(printf '%s' "$1" | jq -r '.tool_name // ""')"
  before="$(mktemp "${TMPDIR:-/tmp}/evidence.XXXXXX")" || exit 0
  after="$(mktemp "${TMPDIR:-/tmp}/evidence.XXXXXX")" || { rm -f "$before"; exit 0; }
  trap 'rm -f "$before" "$after"' EXIT
  if [ "$tool" = Write ]; then
    printf '%s' "$1" | jq -r '.tool_input.content // ""' > "$after"
    rel="$(cd "$(dirname "$f")" 2>/dev/null && git -c core.quotePath=false ls-files --full-name -- "${f##*/}" 2>/dev/null | head -1)"
    if [ -n "$rel" ]; then
      (cd "$(dirname "$f")" && git show "HEAD:$rel" 2>/dev/null) > "$before" || : > "$before"
    fi
  else
    printf '%s' "$1" | jq -r '[.tool_input.old_string // empty, (.tool_input.edits // [] | .[].old_string)] | join("\n")' > "$before"
    printf '%s' "$1" | jq -r '[.tool_input.new_string // empty, (.tool_input.edits // [] | .[].new_string)] | join("\n")' > "$after"
  fi

  t="$f"; [ -n "$cwd" ] && case "$f" in "$cwd"/*) t="${f#"$cwd"/}" ;; esac
  sig=""
  is_test "$t" && sig="$(signals "$before" "$after")"

  # 검증 뒤의 편집은 다시 검증받는다 (E-11) — 그 뒤 편집만 센다
  if [ "${EVIDENCE_REVIEW_GATE:-1}" != 0 ] && rv="$(state "$1" reviewed)" && [ -e "$rv" ]; then
    rm -f "$rv"
    st="$(state "$1" edits)" && rm -f "$st"
    st="$(state "$1" signals)" && rm -f "$st"
  fi

  if [ "${EVIDENCE_REVIEW_GATE:-1}" != 0 ] && [ -n "$cwd" ] && ! is_doc "$f" \
     && case "$f" in "$cwd"/*) true ;; *) false ;; esac; then
    n0="$(nonblank < "$before")"; n1="$(nonblank < "$after")"
    n="$n1"; [ "$n0" -gt "$n" ] && n="$n0"
    if [ "$n" -gt 0 ] && st="$(state "$1" edits)"; then
      printf '%s\037%s\n' "$n" "$f" >> "$st"
    fi
  fi

  [ -n "$sig" ] || exit 0
  if st="$(state "$1" signals)"; then
    while IFS= read -r line; do printf '%s: %s\n' "$f" "$line"; done <<EOF >> "$st"
$sig
EOF
  fi
  msg="테스트 약화 신호 (common-evidence-review E-20) — ${f##*/}
$(printf '%s\n' "$sig" | sed 's/^/- /')
의도한 변경이면 그대로 둔다. 다만 \"테스트 통과\" 를 근거로 쓰려면 이 변경이 왜 필요한지 요청과 연결해 밝힌다 (E-08).
규칙: $RULES"
  jq -n --arg c "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  exit 0
}

hook_review() {
  local who st
  who="$(printf '%s' "$1" | jq -r '.tool_input.subagent_type // ""')"
  case "$who" in *evidence-reviewer*) st="$(state "$1" reviewed)" && : > "$st" ;; esac
  exit 0
}

claims() { # $1=훅 입력 → 최종 답의 주장 후보 줄 (코드 펜스 밖, 10개까지). macOS cut · awk 는 바이트로 잘라 jq 로 자른다
  printf '%s' "$1" | jq -r --arg re "$CLAIM_RE" '
    (.last_assistant_message // "") | split("\n")
    | reduce .[] as $l ({f: false, o: []};
        if ($l | test("^\\s*```")) then .f = (.f | not)
        elif .f then .
        elif ($l | test($re; "i")) then .o += [$l | sub("^[\\s#>*|-]+"; "") | .[0:200]]
        else . end)
    | .o | map(select(test("\\S"))) | .[0:10][]' 2>/dev/null
}

hook_stop() {
  local ed sg rq rv bl active total files c sig
  ed="$(state "$1" edits)" || exit 0
  sg="$(state "$1" signals)"; rq="$(state "$1" request)"; rv="$(state "$1" reviewed)"; bl="$(state "$1" blocked)"
  active="$(printf '%s' "$1" | jq -r '.stop_hook_active // false')"
  # stop_hook_active 는 다른 플러그인의 Stop 훅이 막아도 true 다 — 이 훅이 막은 뒤일 때만 통과시킨다
  if [ "${EVIDENCE_REVIEW_GATE:-1}" = 0 ] || { [ "$active" = true ] && [ -e "$bl" ]; } || [ -e "$rv" ] || [ ! -s "$ed" ]; then
    clear_state "$1"; exit 0
  fi
  total="$(awk -F '\037' '{s += $1} END {print s + 0}' "$ed")"
  if [ "$total" -lt "$MIN_LINES" ]; then clear_state "$1"; exit 0; fi

  files="$(awk -F '\037' '!seen[$2]++ {print "  - " $2}' "$ed" | head -10)"
  c="$(claims "$1" | sed 's/^/  - /')"
  sig=""; [ -s "$sg" ] && sig="$(head -10 "$sg" | sed 's/^/  - /')"
  : > "$bl"
  jq -n --arg r "완료 보류 (common-evidence-review E-30): 이번 요청에서 바꾼 코드 · 설정을 독립 검증하지 않았다.
바꾼 파일:
${files}
요청 기록: $( [ -s "$rq" ] && echo "$rq" || echo "없음 — 대화의 사용자 요청을 원문 그대로 쓴다")
주장 후보 (최종 답에서):
${c:-  - 없음}
$( [ -n "$sig" ] && printf '테스트 약화 신호 (E-20):\n%s' "$sig")
evidence-review 스킬로 evidence-reviewer 에게 요청 원문 · 바뀐 파일 · 결론을 뺀 질문만 넘겨 판정받는다.
검증할 주장이 없는 변경(이름만 바꿈 · 포맷)이면 그 이유를 한 줄로 말하고 끝낸다 — 다음 종료는 막지 않는다.
규칙: $RULES" '{decision: "block", reason: $r}'
  exit 0
}

if [ "${1:-}" = "--hook" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  INPUT="$(cat)"
  printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1 || exit 0
  case "$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')" in
    UserPromptSubmit) hook_prompt "$INPUT" ;;
    PostToolUse)
      case "$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')" in
        Write|Edit|MultiEdit) hook_edit "$INPUT" ;;
        Agent|Task) hook_review "$INPUT" ;;
      esac ;;
    Stop) hook_stop "$INPUT" ;;
  esac
  exit 0
fi

# CLI
STRICT=0; DIFF=0
while [ $# -gt 0 ]; do
  case "$1" in
    --diff) DIFF=1 ;;
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "모르는 인자: $1" ;;
  esac
  shift
done
[ "$DIFF" = 1 ] || die "--diff 가 필요하다 (--help)"
git rev-parse --git-dir >/dev/null 2>&1 || die "git 저장소가 아니다"

BASE="$(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || git rev-parse HEAD 2>/dev/null)" \
  || die "기준 커밋을 찾지 못했다"
TOP="$(git rev-parse --show-toplevel)"
B="$(mktemp "${TMPDIR:-/tmp}/evidence.XXXXXX")"; A="$(mktemp "${TMPDIR:-/tmp}/evidence.XXXXXX")"
trap 'rm -f "$B" "$A"' EXIT

N=0; FILES=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  is_test "$rel" || continue
  FILES=$((FILES+1))
  git -C "$TOP" show "$BASE:$rel" > "$B" 2>/dev/null || : > "$B"
  if [ -f "$TOP/$rel" ]; then cat "$TOP/$rel" > "$A"; else : > "$A"; fi
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    N=$((N+1)); echo "⚠️  $rel: E-20 $s"
  done <<EOF
$(signals "$B" "$A")
EOF
done <<EOF
$( { git -C "$TOP" -c core.quotePath=false diff --name-only "$BASE" --; git -C "$TOP" -c core.quotePath=false ls-files --others --exclude-standard; } | sort -u)
EOF

echo "테스트 파일 ${FILES}개, E-20 신호 ${N}건 (기준 $(git rev-parse --short "$BASE")) — 신호는 후보다. 판정은 evidence-review 스킬 · 규칙: $RULES"
[ "$STRICT" = 1 ] && [ "$N" -gt 0 ] && exit 2
exit 0
