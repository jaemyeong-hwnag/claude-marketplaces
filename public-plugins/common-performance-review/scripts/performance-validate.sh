#!/usr/bin/env bash
# PF-01 ~ PF-20 — 코드에서 성능 위험 패턴을 찾는다. 모두 경고다 (판정은 performance-review 스킬이 맥락을 읽고 한다).
#
#   훅:  PostToolUse(Write|Edit|MultiEdit) — 이번에 쓴 줄에서 나온 것만 additionalContext 로 알린다
#   CLI: performance-validate.sh [--strict] [--diff [<기준>]] [--include-tests] [파일|디렉터리 ...]   (기본: 현재 디렉터리)
#        --diff 는 기준(기본: origin 기본 브랜치와의 merge-base) 이후 추가 · 변경된 줄만 본다
#        경고가 있어도 exit 0, --strict 면 exit 2
#
# 줄 끝이나 바로 윗줄에 `performance-ignore` 주석이 있으면 그 줄은 보지 않는다.
set -uo pipefail

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_DIR" ]; then
  SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
  PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
fi
RULES="$PLUGIN_DIR/references/performance-rules.md"
HELPER_DIR=$(dirname "${BASH_SOURCE[0]}")
die() { echo "performance-validate: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요하다"

# 확장자 → 문법 계열 (빈 문자열이면 보지 않는다)
lang_of() {
  case "$1" in
    *.py) echo py ;;
    *.java|*.kt|*.kts|*.scala|*.go|*.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx|*.cs|*.php|*.swift|*.rs) echo brace ;;
    *.sql) echo sql ;;
    *) echo "" ;;
  esac
}

is_test_path() { # $1=기준 디렉터리 안 상대 경로
  case "/$1" in
    */test/*|*/tests/*|*/__tests__/*|*/spec/*|*/testdata/*|*/fixtures/*) return 0 ;;
    *_test.go|*.test.*|*.spec.*|*Test.java|*Tests.java|*Test.kt|*Tests.kt|*/test_*.py|*_test.py|*conftest.py) return 0 ;;
  esac
  return 1
}

# 테스트 경로는 저장소 최상위(저장소가 아니면 프로젝트 디렉터리) 기준으로 본다 — 바깥 상위 디렉터리(~/test/app)의 이름에 끌려가지 않게
base_of() { # $1=디렉터리 → 기준 디렉터리 (물리 경로)
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || (cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && pwd -P) || pwd -P
}
rel_of() { # $1=기준 $2=경로 → 기준 안이면 상대 경로, 아니면 그대로
  local a d
  d=$(dirname "$2")
  a=$(cd "$d" 2>/dev/null && pwd -P) || { printf '%s\n' "$2"; return; }
  a="$a/${2##*/}"
  case "$a" in "$1"/*) printf '%s\n' "${a:${#1}+1}" ;; *) printf '%s\n' "$2" ;; esac
}

# 파일 하나 → "줄번호 \x1f 조항 \x1f 메시지" 줄들
check_file() {
  local f="$1" lang
  lang=$(lang_of "$f")
  [ -n "$lang" ] || return 0
  bash "$HELPER_DIR/performance-line-check.sh" "$lang" "${f##*.}" "$f"
}

# 줄 단위 출력 → LINES 배열 (빈 줄은 버린다)
split_lines() {
  local old_ifs="$IFS"
  set -f; IFS='
'
  LINES=($1)
  IFS="$old_ifs"; set +f
}
# check_file 한 줄 → ln · rule · msg
US=$'\x1f'
split_row() {
  local rest
  ln="${1%%$US*}"; rest="${1#*$US}"
  rule="${rest%%$US*}"; msg="${rest#*$US}"
}

# 훅: 이번에 쓴 줄(Write 는 전체, Edit 는 new_string)에서 나온 것만
if [ "$#" -eq 0 ] && [ ! -t 0 ]; then
  INPUT=$(cat)
  if [ -n "$INPUT" ] && printf '%s' "$INPUT" | jq -e '.hook_event_name' >/dev/null 2>&1; then
    EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name')
    [ "$EVENT" = "PostToolUse" ] || exit 0
    F=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
    [ -n "$F" ] && [ -f "$F" ] || exit 0
    F_LANG=$(lang_of "$F")
    [ -n "$F_LANG" ] || exit 0
    F_DIR=$(dirname "$F")
    F_BASE=$(base_of "$F_DIR")
    F_REL=$(rel_of "$F_BASE" "$F")
    ! is_test_path "$F_REL" || exit 0
    NEW=$(printf '%s' "$INPUT" | jq -r '[.tool_input.content // empty, .tool_input.new_string // empty, (.tool_input.edits // [] | .[].new_string)] | join("\n")' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -n "$NEW" ] || exit 0
    OUT=""; TOTAL=0
    FOUND=$(check_file "$F")
    split_lines "$FOUND"
    for row in ${LINES+"${LINES[@]}"}; do
      split_row "$row"
      [ -n "$ln" ] || continue
      src=$(sed -n "${ln}p" "$F" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
      [ -n "$src" ] || continue
      printf '%s\n' "$NEW" | grep -qxF -- "$src" || continue
      TOTAL=$((TOTAL+1))
      [ "$TOTAL" -le 10 ] && OUT="${OUT}- ${ln}행 ${rule} ${msg}
"
    done
    [ "$TOTAL" -gt 0 ] || exit 0
    [ "$TOTAL" -gt 10 ] && OUT="${OUT}- … 외 $((TOTAL - 10))건 — performance-validate.sh 로 전체를 본다
"
    MSG="성능 위험 패턴 (common-performance-review) — ${F##*/}
${OUT}패턴은 후보다. 호출 맥락 · 데이터 규모를 읽고 판정한다 (performance-review 스킬). 의도한 것이면 그 줄에 performance-ignore 주석.
규칙: $RULES"
    jq -n --arg c "$MSG" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
    exit 0
  fi
  # 훅 이벤트가 아닌 JSON 은 훅 입력이 깨진 것이다 — 조용히 끝낸다
  [ -n "$INPUT" ] && printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1 && exit 0
fi

STRICT=0; DIFF=0; BASE=""; TESTS=0
TARGETS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --include-tests) TESTS=1 ;;
    --diff)
      DIFF=1
      if [ "$#" -gt 1 ] && [ "${2#-}" = "$2" ] && git rev-parse --verify -q "$2^{commit}" >/dev/null 2>&1; then BASE="$2"; shift; fi ;;
    -*) die "모르는 옵션: $1" ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done

# 대상 파일과, 볼 줄 번호 목록 (빈 문자열이면 전체)
FILES=(); LINESETS=()
add_file() { FILES+=("$1"); LINESETS+=("$2"); }
BASE_DIR=""
want() { # $1=경로 — 볼 파일인가 (테스트 판정은 BASE_DIR 기준)
  local lang relp
  lang=$(lang_of "$1")
  [ -n "$lang" ] || return 1
  [ "$TESTS" = 1 ] && return 0
  relp=$(rel_of "$BASE_DIR" "$1")
  ! is_test_path "$relp"
}
# 디렉터리 → 파일 목록. git 작업 트리면 .gitignore 를 따른다
list_dir() {
  local t="${1%/}"
  if git -C "$t" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$t" ls-files --cached --others --exclude-standard -- . | sed "s#^#$t/#" | grep -v -E '/(node_modules|vendor|dist|build|target)/|\.min\.js$' | sort -u
    return
  fi
  find "$t" -type f -size -1024k \( -name '*.py' -o -name '*.java' -o -name '*.kt' -o -name '*.kts' -o -name '*.scala' -o -name '*.go' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.cs' -o -name '*.php' -o -name '*.swift' -o -name '*.rs' -o -name '*.sql' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path "$t/.claude/*" -not -path '*/build/*' -not -path '*/target/*' -not -path '*/dist/*' \
    -not -path '*/.venv/*' -not -path '*/venv/*' -not -path '*/vendor/*' -not -path '*/__pycache__/*' -not -path '*/.next/*' -not -path '*/coverage/*' -not -name '*.min.js' | sort
}

if [ "$DIFF" = 1 ]; then
  TOP=$(git rev-parse --show-toplevel 2>/dev/null) || die "--diff 는 git 저장소 안에서만 쓴다"
  if [ -z "$BASE" ]; then
    BASE=$(git -C "$TOP" merge-base HEAD origin/HEAD 2>/dev/null || git -C "$TOP" merge-base HEAD origin/main 2>/dev/null || git -C "$TOP" rev-parse HEAD)
  fi
  BASE_DIR="$TOP"
  CHANGED=$(git -C "$TOP" diff --name-only --diff-filter=AMR "$BASE")
  split_lines "$CHANGED"
  for rel in ${LINES+"${LINES[@]}"}; do
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && want "$TOP/$rel" || continue
    lines=$(git -C "$TOP" diff -U0 "$BASE" -- "$rel" | awk '/^@@/ { s = $3; sub(/^\+/, "", s); k = split(s, a, ","); c = (k < 2) ? 1 : a[2]; for (i = 0; i < c; i++) printf " %d", a[1] + i }')
    [ -n "$lines" ] && add_file "$TOP/$rel" "$lines"
  done
  # 추적 안 된 새 파일은 전부 추가된 줄이다
  UNTRACKED=$(git -C "$TOP" ls-files --others --exclude-standard)
  split_lines "$UNTRACKED"
  for rel in ${LINES+"${LINES[@]}"}; do
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && want "$TOP/$rel" || continue
    add_file "$TOP/$rel" ""
  done
else
  [ "${#TARGETS[@]}" -gt 0 ] || TARGETS=(".")
  for t in "${TARGETS[@]}"; do
    [ -e "$t" ] || die "없는 경로: $t"
    if [ -d "$t" ]; then
      BASE_DIR=$(base_of "$t"); td=$(cd "$t" && pwd -P)
      case "$td/" in "$BASE_DIR"/*) ;; *) BASE_DIR="$td" ;; esac
      LISTED=$(list_dir "$t")
      split_lines "$LISTED"
      for f in ${LINES+"${LINES[@]}"}; do
        [ -n "$f" ] && [ -f "$f" ] && want "$f" || continue
        add_file "$f" ""
      done
    else
      add_file "$t" ""
    fi
  done
fi

N=0; W=0
for i in ${FILES+"${!FILES[@]}"}; do
  f="${FILES[$i]}"; set_="${LINESETS[$i]}"
  N=$((N+1)); OUT=""
  FOUND=$(check_file "$f")
  split_lines "$FOUND"
  for row in ${LINES+"${LINES[@]}"}; do
    split_row "$row"
    [ -n "$ln" ] || continue
    if [ -n "$set_" ]; then case "$set_ " in *" $ln "*) ;; *) continue ;; esac; fi
    OUT="${OUT}  - ${ln}행 ${rule} ${msg}
"
    W=$((W+1))
  done
  [ -z "$OUT" ] || { echo "⚠️  $f"; printf '%s' "$OUT"; }
done

if [ "$DIFF" = 1 ]; then SHORT=$(git -C "$TOP" rev-parse --short "$BASE"); SCOPE="변경 파일 ${N}개 (기준 $SHORT)"; else SCOPE="파일 ${N}개"; fi
echo "${SCOPE}, 경고 ${W}건 — 패턴은 후보다. 판정은 performance-review 스킬 · 규칙: $RULES"
[ "$STRICT" = 1 ] && [ "$W" -gt 0 ] && exit 2
exit 0
