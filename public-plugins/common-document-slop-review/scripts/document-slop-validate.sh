#!/usr/bin/env bash
# DS-01 ~ DS-16 — 문서의 slop · 근거 없는 주장 · 형식 과잉을 찾는다. DS-01 ~ DS-04 는 차단, 나머지는 경고다.
# DS-30 — 문서를 고친 세션이 document-slop-review 없이 끝나면 한 번 되돌린다.
#
#   훅:  document-slop-validate.sh --hook  (stdin 으로 훅 입력)
#        PostToolUse(Write|Edit|MultiEdit) — 이번에 쓴 줄만 본다. 차단은 exit 2 + stderr, 경고는 additionalContext
#        PostToolUse(Skill|Agent)          — document-slop-review(er) 가 돌면 DS-30 기록을 지운다. 백그라운드 리뷰어는 리뷰 중으로만 표시
#        SubagentStop                      — 백그라운드 document-slop-reviewer 가 끝나면 DS-30 기록을 지운다
#        UserPromptSubmit                  — 이 훅이 막은 표시를 지운다
#        Stop                              — DS-30
#   CLI: document-slop-validate.sh [--strict] [--diff [<기준>]] [파일|디렉터리 ...]   (기본: 현재 디렉터리)
#        차단이 있으면 exit 2, --strict 면 경고가 있어도 exit 2. 실행 오류는 exit 1
#
# 줄이나 바로 윗줄에 `document-slop-ignore` 가 있으면 그 줄은 보지 않는다.
set -uo pipefail
# 디렉터리 검증기는 따옴표 안의 꺾쇠 닫기를 리다이렉션으로, 따옴표 안의 $'…' 를 읽을 수 없는 스크립트로 본다 — 본문에 쓰지 않고 여기서 만든다
GT=$(printf 4 | LC_ALL=C tr 0-9 ':-C' 2>/dev/null)
C_US=$'\037'
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$ROOT" ]; then
  SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
  ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
fi
RULES="$ROOT/references/document-slop-rules.md"
PATTERNS="$ROOT/references/document-slop-patterns.json"
GATE_MIN_LINES=3
NL='
'
die() { echo "document-slop-validate: $*" >&2; exit 1; }

is_doc() {
  local b
  b=$(printf '%s' "${1##*/}" | tr 'A-Z' 'a-z')
  case "$1" in */node_modules/*|*/.git/*|*/vendor/*) return 1 ;; esac
  case "$b" in
    requirements*.txt|constraints*.txt|cmakelists.txt|robots.txt|license*|*-lock.txt) return 1 ;;
    *.md|*.mdx|*.markdown|*.rst|*.txt|*.adoc) return 0 ;;
  esac
  return 1
}

# 규칙 JSON → awk 가 읽는 "키 \x1f 값" 줄
PAT_FILE=""
load_patterns() {
  [ -n "$PAT_FILE" ] && return 0
  command -v jq >/dev/null 2>&1 || return 1
  [ -f "$PATTERNS" ] || return 1
  PAT_FILE=$(mktemp "${TMPDIR:-/tmp}/document-slop.XXXXXX") || return 1
  jq -r '
    (.rules | to_entries[] | .key as $k | .value as $v |
      ("msg\u001f\($k)\u001f\($v.message)"),
      ("level\u001f\($k)\u001f\($v.level)"),
      (($v.patterns // [])[] | "pat\u001f\($k)\u001f\(.)"),
      (($v.words // [])[] | "word\u001f\($k)\u001f\(.)"),
      ($v | to_entries[] | select(.value | type == "number" or type == "string") | select(.key != "message" and .key != "level") | "opt\u001f\($k).\(.key)\u001f\(.value)")),
    (.evidence[] | "evidence\u001f-\u001f\(.)"),
    (.dated[] | "dated\u001f-\u001f\(.)")
  ' "$PATTERNS" > "$PAT_FILE" 2>/dev/null || return 1
}
cleanup() { [ -n "$PAT_FILE" ] && rm -f "$PAT_FILE"; [ -n "${SEL_FILE:-}" ] && rm -f "$SEL_FILE"; }
trap cleanup EXIT

# $1=파일 $2=모드(all|text|lines) $3=선택 파일(text: 이번에 쓴 텍스트, lines: 줄 번호)
# 출력: "줄번호 \x1f 조항 \x1f 수준 \x1f 메시지"  (DS-04 는 수준 link, 메시지는 링크 대상)
check_file() {
  LC_ALL=C bash "$SELF_DIR/document-slop-signal-list.sh" "$2" "$PAT_FILE" "$3" "$1" | sort -t "$C_US" -k1,1n
}

# 링크 대상 · 수준을 판정해 "줄번호 \x1f 조항 \x1f 수준 \x1f 메시지" 로 낸다
resolve() { # $1=파일
  local dir ln rule lvl msg p
  dir=$(dirname "$1")
  while IFS="$C_US" read -r ln rule lvl msg; do
    [ -n "$rule" ] || continue
    if [ "$lvl" = link ]; then
      p=$(printf '%s' "$msg" | sed 's/%20/ /g')
      [ -e "$dir/$p" ] && continue
      printf '%s\037%s\037block\037%s (%s)\n' "$ln" "$rule" "상대 링크가 가리키는 경로가 없다 — 경로를 고치거나 링크를 지운다" "$msg"
    else
      printf '%s\037%s\037%s\037%s\n' "$ln" "$rule" "$lvl" "$msg"
    fi
  done
}

where() { [ "$1" = 0 ] && echo "문서 전체" || echo "${1}행"; }

# 판정 줄 → 차단은 "B위치 조항 메시지", 나머지는 "W위치 조항 메시지"
tag_results() {
  local ln rule lvl msg at
  while IFS="$C_US" read -r ln rule lvl msg; do
    [ -n "$rule" ] || continue
    at=$(where "$ln")
    if [ "$lvl" = block ]; then printf 'B%s %s %s\n' "$at" "$rule" "$msg"; else printf 'W%s %s %s\n' "$at" "$rule" "$msg"; fi
  done
}

state_file() { # $1=훅 입력
  local sid dir
  sid=$(printf '%s' "$1" | jq -r '.session_id // "nosession"' | tr -cd 'A-Za-z0-9_-')
  dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/common-document-slop-review}"
  mkdir -p "$dir" 2>/dev/null || return 1
  echo "$dir/gate-${sid:-nosession}.list"
}

hook_edit() { # $1=훅 입력
  local f new sel blocks="" warns="" nb=0 nw=0 cwd st left more nonblank tagged rest line
  f=$(printf '%s' "$1" | jq -r '.tool_input.file_path // ""')
  [ -n "$f" ] && [ -f "$f" ] && is_doc "$f" || exit 0
  load_patterns || exit 0
  new=$(printf '%s' "$1" | jq -r '[.tool_input.content // empty, .tool_input.new_string // empty, (.tool_input.edits // [] | .[].new_string)] | join("\n")')
  left=$(printf '%s' "$new" | tr -d '[:space:]')
  [ -n "$left" ] || exit 0
  SEL_FILE=$(mktemp "${TMPDIR:-/tmp}/document-slop.XXXXXX") || exit 0
  printf '%s\n' "$new" > "$SEL_FILE"
  tagged=$(check_file "$f" text "$SEL_FILE" | resolve "$f" | tag_results)
  rest="$tagged$NL"
  while [ -n "$rest" ]; do
    line="${rest%%$NL*}"; rest="${rest#*$NL}"
    case "$line" in
      B*) nb=$((nb+1)); blocks="${blocks}- ${line#B}
" ;;
      W*) nw=$((nw+1)); [ "$nw" -le 10 ] && warns="${warns}- ${line#W}
" ;;
    esac
  done
  more=$((nw - 10))
  [ "$nw" -gt 10 ] && warns="${warns}- … 외 ${more}건 — document-slop-validate.sh ${f##*/} 로 전체를 본다
"

  # DS-30 기록 — 프로젝트 안 문서를 실질적으로 고쳤을 때만
  cwd=$(printf '%s' "$1" | jq -r '.cwd // ""')
  nonblank=$(grep -c '[^[:space:]]' "$SEL_FILE")
  if [ "${DOCUMENT_SLOP_REVIEW_GATE:-1}" != 0 ] && [ -n "$cwd" ] && case "$f" in "$cwd"/*) true ;; *) false ;; esac \
     && [ "$nonblank" -ge "$GATE_MIN_LINES" ]; then
    st=$(state_file "$1") && { grep -qxF -- "$f" "$st" 2>/dev/null || printf '%s\n' "$f" >> "$st"; }
  fi

  if [ "$nb" -gt 0 ]; then
    {
      echo "문서 slop 차단 (common-document-slop-review) — ${f##*/} 은 이미 저장됐다. 아래를 고친다"
      printf '%s' "$blocks"
      [ -n "$warns" ] && { echo "경고:"; printf '%s' "$warns"; }
      echo "규칙: $RULES"
    } >&2
    exit 2
  fi
  [ "$nw" -gt 0 ] || exit 0
  jq -n --arg c "문서 slop 경고 (common-document-slop-review) — ${f##*/}
${warns}경고는 후보다. 출처 · 미확인 표시 · 단서는 지우지 않는다. 의도한 줄이면 <!-- document-slop-ignore --${GT}.
규칙: $RULES" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  exit 0
}

hook_review() { # $1=훅 입력 — 리뷰가 돌았으면 DS-30 기록을 지운다. 백그라운드 리뷰어는 SubagentStop 까지 리뷰 중
  local who st
  who=$(printf '%s' "$1" | jq -r '(.tool_input.skill // "") + " " + (.tool_input.subagent_type // "")')
  case "$who" in *document-slop-review*) ;; *) exit 0 ;; esac
  st=$(state_file "$1") || exit 0
  if printf '%s' "$1" | jq -e '(.tool_response | objects | (.isAsync == true or .status == "async_launched")) // false' >/dev/null 2>&1; then
    : > "${st%.list}.pending"
  else
    rm -f "$st" "${st%.list}.blocked"
  fi
  exit 0
}

hook_subagent_stop() { # $1=훅 입력
  local st who
  who=$(printf '%s' "$1" | jq -r '.agent_type // ""')
  case "$who" in
    *document-slop-reviewer*) st=$(state_file "$1") && rm -f "$st" "${st%.list}.pending" "${st%.list}.blocked" ;;
  esac
  exit 0
}

hook_stop() { # $1=훅 입력
  local st active list
  [ "${DOCUMENT_SLOP_REVIEW_GATE:-1}" != 0 ] || exit 0
  st=$(state_file "$1") || exit 0
  [ -s "$st" ] || exit 0
  # 백그라운드 리뷰어를 기다리며 끝내는 응답 — 막지 않고 기록을 남긴다 (완료 알림 뒤 다시 판정)
  [ -e "${st%.list}.pending" ] && exit 0
  active=$(printf '%s' "$1" | jq -r '.stop_hook_active // false')
  # stop_hook_active 는 다른 플러그인의 Stop 훅이 막아도 true 다 — 이 훅이 막은 뒤일 때만 통과시킨다
  if [ "$active" = true ] && [ -e "${st%.list}.blocked" ]; then rm -f "$st" "${st%.list}.blocked"; exit 0; fi
  list=$(head -10 "$st" | sed 's/^/  - /')
  : > "${st%.list}.blocked"
  jq -n --arg r "완료 보류 (common-document-slop-review DS-30): 이번 세션에서 고친 문서를 판단 리뷰하지 않았다.
${list}
document-slop-review 스킬로 리뷰하고 결함을 고친다 (근거 대조 · 지워도 되는 문장 · 반복 · 구조).
오탈자처럼 리뷰할 내용이 없는 변경이면 그 이유를 한 줄로 말하고 끝낸다 — 다음 종료는 막지 않는다.
규칙: $RULES" '{decision: "block", reason: $r}'
  exit 0
}

if [ "${1:-}" = "--hook" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  INPUT=$(cat)
  printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1 || exit 0
  EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')
  case "$EVENT" in
    PostToolUse)
      TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
      case "$TOOL_NAME" in
        Write|Edit|MultiEdit) hook_edit "$INPUT" ;;
        Skill|Agent|Task) hook_review "$INPUT" ;;
      esac ;;
    SubagentStop) hook_subagent_stop "$INPUT" ;;
    UserPromptSubmit) st=$(state_file "$INPUT") && rm -f "${st%.list}.blocked" ;;
    Stop) hook_stop "$INPUT" ;;
  esac
  exit 0
fi

command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"
load_patterns || die "규칙 파일을 읽지 못했다: $PATTERNS"

STRICT=0; DIFF=0; BASE=""
TARGETS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --diff)
      DIFF=1
      if [ "$#" -gt 1 ] && [ "${2#-}" = "$2" ] && git rev-parse --verify -q "$2^{commit}" >/dev/null 2>&1; then BASE="$2"; shift; fi ;;
    -*) die "모르는 옵션: $1" ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done

FILES=(); LINESETS=()
add_file() { FILES+=("$1"); LINESETS+=("$2"); }
list_dir() {
  local t="${1%/}"
  if git -C "$t" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$t" ls-files --cached --others --exclude-standard -- . | sed "s#^#$t/#" | sort -u
    return
  fi
  find "$t" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path "$t/.claude/*" | sort
}

if [ "$DIFF" = 1 ]; then
  TOP=$(git rev-parse --show-toplevel 2>/dev/null) || die "--diff 는 git 저장소 안에서만 쓴다"
  if [ -z "$BASE" ]; then
    BASE=$(git -C "$TOP" merge-base HEAD origin/HEAD 2>/dev/null || git -C "$TOP" merge-base HEAD origin/main 2>/dev/null || git -C "$TOP" rev-parse HEAD)
  fi
  CHANGED=$(git -C "$TOP" diff --name-only --diff-filter=AMR "$BASE")
  REST="$CHANGED$NL"
  while [ -n "$REST" ]; do
    rel="${REST%%$NL*}"; REST="${REST#*$NL}"
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && is_doc "$TOP/$rel" || continue
    lines=$(git -C "$TOP" diff -U0 "$BASE" -- "$rel" | awk '/^@@/ { s = $3; sub(/^\+/, "", s); k = split(s, a, ","); c = (k < 2) ? 1 : a[2]; for (i = 0; i < c; i++) printf " %d", a[1] + i }')
    [ -n "$lines" ] && add_file "$TOP/$rel" "$lines"
  done
  UNTRACKED=$(git -C "$TOP" ls-files --others --exclude-standard)
  REST="$UNTRACKED$NL"
  while [ -n "$REST" ]; do
    rel="${REST%%$NL*}"; REST="${REST#*$NL}"
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && is_doc "$TOP/$rel" || continue
    add_file "$TOP/$rel" ""
  done
else
  [ "${#TARGETS[@]}" -gt 0 ] || TARGETS=(".")
  for t in "${TARGETS[@]}"; do
    [ -e "$t" ] || die "없는 경로: $t"
    if [ -d "$t" ]; then
      LISTED=$(list_dir "$t")
      REST="$LISTED$NL"
      while [ -n "$REST" ]; do
        f="${REST%%$NL*}"; REST="${REST#*$NL}"
        [ -n "$f" ] && [ -f "$f" ] && is_doc "$f" || continue
        add_file "$f" ""
      done
    else
      is_doc "$t" && add_file "$t" ""
    fi
  done
fi

N=0; B=0; W=0
SEL_FILE=$(mktemp "${TMPDIR:-/tmp}/document-slop.XXXXXX") || die "임시 파일을 만들지 못했다"
for i in ${FILES+"${!FILES[@]}"}; do
  f="${FILES[$i]}"; set_="${LINESETS[$i]}"
  N=$((N+1)); OUT=""
  if [ -n "$set_" ]; then printf '%s\n' "$set_" > "$SEL_FILE"; mode=lines; else : > "$SEL_FILE"; mode=all; fi
  TAGGED=$(check_file "$f" "$mode" "$SEL_FILE" | resolve "$f" | tag_results)
  REST="$TAGGED$NL"
  while [ -n "$REST" ]; do
    LINE="${REST%%$NL*}"; REST="${REST#*$NL}"
    case "$LINE" in
      B*) B=$((B+1)); OUT="${OUT}  ❌ ${LINE#B}
" ;;
      W*) W=$((W+1)); OUT="${OUT}  ⚠️  ${LINE#W}
" ;;
    esac
  done
  [ -z "$OUT" ] || { echo "$f"; printf '%s' "$OUT"; }
done

if [ "$DIFF" = 1 ]; then SHORT=$(git -C "$TOP" rev-parse --short "$BASE"); SCOPE="변경 문서 ${N}개 (기준 ${SHORT})"; else SCOPE="문서 ${N}개"; fi
echo "${SCOPE}, 차단 ${B}건 · 경고 ${W}건 — 경고는 후보다. 판정은 document-slop-review 스킬 · 규칙: $RULES"
[ "$B" -gt 0 ] && exit 2
[ "$STRICT" = 1 ] && [ "$W" -gt 0 ] && exit 2
exit 0
