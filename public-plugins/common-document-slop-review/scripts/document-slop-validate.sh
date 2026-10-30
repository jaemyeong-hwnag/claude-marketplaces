#!/usr/bin/env bash
# DS-01 ~ DS-16 — 문서의 slop · 근거 없는 주장 · 형식 과잉을 찾는다. DS-01 ~ DS-04 는 차단, 나머지는 경고다.
# DS-30 — 문서를 고친 세션이 document-slop-review 없이 끝나면 한 번 되돌린다.
#
#   훅:  document-slop-validate.sh --hook  (stdin 으로 훅 입력)
#        PostToolUse(Write|Edit|MultiEdit) — 이번에 쓴 줄만 본다. 차단은 exit 2 + stderr, 경고는 additionalContext
#        PostToolUse(Skill|Agent)          — document-slop-review(er) 가 돌면 DS-30 기록을 지운다. 백그라운드 리뷰어는 리뷰 중으로만 표시
#        SubagentStop                      — 백그라운드 document-slop-reviewer 가 끝나면 DS-30 기록을 지운다
#        Stop                              — DS-30
#   CLI: document-slop-validate.sh [--strict] [--diff [<기준>]] [파일|디렉터리 ...]   (기본: 현재 디렉터리)
#        차단이 있으면 exit 2, --strict 면 경고가 있어도 exit 2. 실행 오류는 exit 1
#
# 줄이나 바로 윗줄에 `document-slop-ignore` 가 있으면 그 줄은 보지 않는다.
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RULES="$ROOT/references/document-slop-rules.md"
PATTERNS="$ROOT/references/document-slop-patterns.json"
GATE_MIN_LINES=3
die() { echo "document-slop-validate: $*" >&2; exit 1; }

is_doc() {
  local b
  b="$(printf '%s' "${1##*/}" | tr 'A-Z' 'a-z')"
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
  PAT_FILE="$(mktemp "${TMPDIR:-/tmp}/document-slop.XXXXXX")" || return 1
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
  LC_ALL=C awk -v mode="$2" -v FS='\037' '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function emit(n, rule, lvl, msg) {
  if ((n SUBSEP rule) in seen) return
  seen[n SUBSEP rule] = 1
  printf "%d\037%s\037%s\037%s\n", n, rule, lvl, msg
}
function anyof(s, k,   i) { for (i = 1; i <= NP[k]; i++) if (s ~ P[k, i]) return 1; return 0 }
function firstof(s, k,   i) { for (i = 1; i <= NP[k]; i++) if (match(s, P[k, i])) return substr(s, RSTART, RLENGTH); return "" }
function has_evidence(s) { return anyof(s, "evidence") }
FILENAME == ARGV[1] {
  if ($1 == "msg") MSG[$2] = $3
  else if ($1 == "level") LVL[$2] = $3
  else if ($1 == "opt") OPT[$2] = $3
  else if ($1 == "word") WORD[$3] = 1
  else { k = ($1 == "pat") ? $2 : $1; NP[k]++; P[k, NP[k]] = $3 }
  next
}
FILENAME == ARGV[2] {
  if (mode == "text") { t = trim($0); if (t != "") WANT_TEXT[t] = 1 }
  else if (mode == "lines") { n = split($0, a, /[ ]+/); for (i = 1; i <= n; i++) if (a[i] != "") WANT_LINE[a[i]] = 1 }
  next
}
{ NL++; L[NL] = (length($0) > 4000) ? "" : $0 }
END {
  # 1차: 볼 줄 · 산문 줄 · 제목을 고른다
  fence = 0; front = 0; cmt = 0
  for (n = 1; n <= NL; n++) {
    raw = L[n]
    if (n == 1 && raw ~ /^---[ \t]*$/) { front = 1; continue }
    if (front) { if (raw ~ /^(---|\.\.\.)[ \t]*$/) front = 0; continue }
    if (raw ~ /^[ \t]*(```|~~~)/) { fence = !fence; continue }
    if (fence) continue
    if (raw ~ /^[ \t]*>/) continue
    if (raw ~ /document-slop-ignore/ || (n > 1 && L[n-1] ~ /document-slop-ignore/)) { IGN[n] = 1 }
    s = raw
    if (cmt) { if (!match(s, /-->/)) continue; s = substr(s, RSTART + 3); cmt = 0 }
    gsub(/<!--.*-->/, "", s)
    if (match(s, /<!--/)) { s = substr(s, 1, RSTART - 1); cmt = 1 }
    PROSE[n] = s
    t = trim(raw)
    if (mode == "all") W[n] = 1
    else if (mode == "text" && (t in WANT_TEXT)) W[n] = 1
    else if (mode == "lines" && (n in WANT_LINE)) W[n] = 1
    if (match(s, /^#{1,6}[ \t]/)) { HN++; HL[HN] = n; HV[HN] = RLENGTH - 1 }
  }

  distinct = 0; contrast = 0; bolds = 0; prose = 0; lead = 0
  for (n = 1; n <= NL; n++) {
    if (!(n in PROSE) || !(n in W) || (n in IGN)) continue
    s = PROSE[n]
    c = s; gsub(/`[^`]*`/, "", c)
    low = tolower(c)
    if (trim(low) == "") continue
    body = low; sub(/^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/, "", body); sub(/^#{1,6}[ \t]+/, "", body)

    if (anyof(body, "DS-01")) emit(n, "DS-01", "block", MSG["DS-01"] " (" firstof(body, "DS-01") ")")
    nolink = low; gsub(/\[[^]]*\]\([^)]*\)/, "", nolink)
    if (anyof(nolink, "DS-02")) emit(n, "DS-02", "block", MSG["DS-02"] " (" firstof(nolink, "DS-02") ")")
    if (anyof(low, "DS-03")) emit(n, "DS-03", "block", MSG["DS-03"] " (" firstof(low, "DS-03") ")")

    rest = c
    while (match(rest, /\]\([^)]*\)/)) {
      tgt = substr(rest, RSTART + 2, RLENGTH - 3); rest = substr(rest, RSTART + RLENGTH)
      emit_link(n, tgt)
    }
    if (match(c, /^[ \t]*\[[^]]+\]:[ \t]+[^ \t]+/)) { tgt = c; sub(/^[ \t]*\[[^]]+\]:[ \t]+/, "", tgt); sub(/[ \t].*$/, "", tgt); emit_link(n, tgt) }

    if (anyof(low, "DS-05") && !has_evidence(low)) emit(n, "DS-05", "warn", MSG["DS-05"] " (" firstof(low, "DS-05") ")")
    if (anyof(body, "DS-06") && !anyof(low, "dated")) emit(n, "DS-06", "warn", MSG["DS-06"] " (" trim(firstof(body, "DS-06")) ")")
    if (anyof(low, "DS-07") && !has_evidence(low) && low !~ /^[ \t]*\|/) emit(n, "DS-07", "warn", MSG["DS-07"] " (" firstof(low, "DS-07") ")")
    if (anyof(body, "DS-08")) emit(n, "DS-08", "warn", MSG["DS-08"] " (" firstof(body, "DS-08") ")")
    if (anyof(low, "DS-12")) emit(n, "DS-12", "warn", MSG["DS-12"] " (" firstof(low, "DS-12") ")")
    if (anyof(low, "DS-13")) emit(n, "DS-13", "warn", MSG["DS-13"] " (" firstof(low, "DS-13") ")")

    # DS-10 — 어휘 묶음은 이번에 쓴 줄 전체에서 센다
    tmp = low; gsub(/[^a-z\047-]+/, " ", tmp); m = split(tmp, ws, " ")
    for (i = 1; i <= m; i++) if ((ws[i] in WORD) && !(ws[i] in VOC)) { VOC[ws[i]] = n; distinct++; vlist = vlist (vlist == "" ? "" : ", ") ws[i]; if (!vfirst) vfirst = n }
    for (i = 1; i <= NP["DS-10"]; i++) if (match(low, P["DS-10", i])) { w = substr(low, RSTART, RLENGTH); if (!(w in VOC)) { VOC[w] = n; distinct++; vlist = vlist (vlist == "" ? "" : ", ") w; if (!vfirst) vfirst = n } }

    k = 0; for (i = 1; i <= NP["DS-11"]; i++) { tc = low; k += gsub(P["DS-11", i], "", tc) }
    if (k > 0) { contrast += k; if (!cfirst) cfirst = n; clist = clist (clist == "" ? "" : ", ") n "행" }

    # DS-14 — 굵게 · 머리말 목록 · 이모지 제목
    if (low !~ /^[ \t]*\|/ && low !~ /^#{1,6}[ \t]/) { prose++; tb = c; bolds += gsub(/\*\*[^*]+\*\*/, "", tb) }
    if (c ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]+\*\*[^*]+\*\*[ \t]*(:|—|–| - )/ || c ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]+\*\*[^*]+[:：]\*\*/) { lead++; if (lead == 1) lfirst = n; if (lead == OPT["DS-14.lead_run"]) emit(lfirst, "DS-14", "warn", MSG["DS-14"] " (\"**머리말**: 설명\" 목록 " lead "줄 이상 연속)") }
    else if (c !~ /^[ \t]*$/) lead = 0
    if (c ~ /^#{1,6}[ \t]/ && (c ~ /\360\237/ || c ~ /\342\234\205|\342\235\214|\342\232\240|\342\234\250|\342\255\220/)) emit(n, "DS-14", "warn", MSG["DS-14"] " (제목에 이모지)")

    # DS-16 — 같은 문장이 다른 줄에도 있는가
    t = trim(c)
    if (length(t) >= OPT["DS-16.min_bytes"] && t !~ /^(#|\|)/) {
      for (j = 1; j <= NL; j++) if (j != n && (j in PROSE) && !(j > n && (j in W)) && trim(PROSE[j]) == trim(PROSE[n])) { emit(n, "DS-16", "warn", MSG["DS-16"] " (" j "행)"); break }
    }
  }
  if (distinct >= OPT["DS-10.min_distinct"]) emit(vfirst, "DS-10", "warn", MSG["DS-10"] " (" vlist ")")
  if (contrast >= OPT["DS-11.min_count"]) emit(cfirst, "DS-11", "warn", MSG["DS-11"] " (" clist ")")
  if (bolds >= OPT["DS-14.bold_min"] && prose > 0 && bolds / prose >= OPT["DS-14.bold_ratio"]) emit(0, "DS-14", "warn", MSG["DS-14"] " (굵게 " bolds "곳 / 산문 " prose "줄)")

  # DS-09 · DS-15 — 제목은 파일 전체로 판정하고, 이번에 쓴 줄이면 알린다
  for (h = 1; h <= HN; h++) {
    n = HL[h]
    if (!(n in W) || (n in IGN)) continue
    if (h > 1 && HV[h] > HV[h-1] + 1) emit(n, "DS-15", "warn", MSG["DS-15"] " (h" HV[h-1] " → h" HV[h] ")")
  }
  if (HN > 0) {
    n = HL[HN]; t = tolower(PROSE[n])
    sub(/^#{1,6}[ \t]+/, "", t); gsub(/\*\*|__/, "", t); sub(/^[0-9.]+[ \t]*/, "", t); gsub(/[^a-z0-9;: \200-\377-]/, "", t); gsub(/\360\237[\200-\277][\200-\277]/, "", t); t = trim(t)
    if ((n in W) && !(n in IGN) && t ~ OPT["DS-09.headings"]) emit(n, "DS-09", "warn", MSG["DS-09"] " (" t ")")
  }
}
function emit_link(n, tgt) {
  tgt = trim(tgt); sub(/^</, "", tgt); sub(/>$/, "", tgt); sub(/[ \t]+".*$/, "", tgt)
  if (tgt == "" || tgt ~ /^#/ || tgt ~ /^\// || tgt ~ /^[a-zA-Z][a-zA-Z0-9+.-]*:/ || tgt ~ /\{\{|\$/) return
  sub(/[#?].*$/, "", tgt)
  if (tgt != "") emit(n, "DS-04", "link", tgt)
}
' "$PAT_FILE" "$3" "$1" | sort -t "$(printf '\037')" -k1,1n
}

# 링크 대상 · 수준을 판정해 "줄번호 \x1f 조항 \x1f 수준 \x1f 메시지" 로 낸다
resolve() { # $1=파일
  local dir ln rule lvl msg p
  dir="$(dirname "$1")"
  while IFS=$'\x1f' read -r ln rule lvl msg; do
    [ -n "$rule" ] || continue
    if [ "$lvl" = link ]; then
      p="$(printf '%s' "$msg" | sed 's/%20/ /g')"
      [ -e "$dir/$p" ] && continue
      printf '%s\037%s\037block\037%s (%s)\n' "$ln" "$rule" "상대 링크가 가리키는 경로가 없다 — 경로를 고치거나 링크를 지운다" "$msg"
    else
      printf '%s\037%s\037%s\037%s\n' "$ln" "$rule" "$lvl" "$msg"
    fi
  done
}

where() { [ "$1" = 0 ] && echo "문서 전체" || echo "${1}행"; }

state_file() { # $1=훅 입력
  local sid dir
  sid="$(printf '%s' "$1" | jq -r '.session_id // "nosession"' | tr -cd 'A-Za-z0-9_-')"
  dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/common-document-slop-review}"
  mkdir -p "$dir" 2>/dev/null || return 1
  echo "$dir/gate-${sid:-nosession}.list"
}

hook_edit() { # $1=훅 입력
  local f new sel blocks="" warns="" nb=0 nw=0 ln rule lvl msg cwd st
  f="$(printf '%s' "$1" | jq -r '.tool_input.file_path // ""')"
  [ -n "$f" ] && [ -f "$f" ] && is_doc "$f" || exit 0
  load_patterns || exit 0
  new="$(printf '%s' "$1" | jq -r '[.tool_input.content // empty, .tool_input.new_string // empty, (.tool_input.edits // [] | .[].new_string)] | join("\n")')"
  [ -n "$(printf '%s' "$new" | tr -d '[:space:]')" ] || exit 0
  SEL_FILE="$(mktemp "${TMPDIR:-/tmp}/document-slop.XXXXXX")" || exit 0
  printf '%s\n' "$new" > "$SEL_FILE"
  while IFS=$'\x1f' read -r ln rule lvl msg; do
    [ -n "$rule" ] || continue
    if [ "$lvl" = block ]; then nb=$((nb+1)); blocks="${blocks}- $(where "$ln") ${rule} ${msg}
"
    else nw=$((nw+1)); [ "$nw" -le 10 ] && warns="${warns}- $(where "$ln") ${rule} ${msg}
"
    fi
  done <<EOF
$(check_file "$f" text "$SEL_FILE" | resolve "$f")
EOF
  [ "$nw" -gt 10 ] && warns="${warns}- … 외 $((nw - 10))건 — document-slop-validate.sh ${f##*/} 로 전체를 본다
"

  # DS-30 기록 — 프로젝트 안 문서를 실질적으로 고쳤을 때만
  cwd="$(printf '%s' "$1" | jq -r '.cwd // ""')"
  if [ "${DOCUMENT_SLOP_REVIEW_GATE:-1}" != 0 ] && [ -n "$cwd" ] && case "$f" in "$cwd"/*) true ;; *) false ;; esac \
     && [ "$(grep -c '[^[:space:]]' "$SEL_FILE")" -ge "$GATE_MIN_LINES" ]; then
    st="$(state_file "$1")" && { grep -qxF -- "$f" "$st" 2>/dev/null || printf '%s\n' "$f" >> "$st"; }
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
${warns}경고는 후보다. 출처 · 미확인 표시 · 단서는 지우지 않는다. 의도한 줄이면 <!-- document-slop-ignore -->.
규칙: $RULES" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  exit 0
}

hook_review() { # $1=훅 입력 — 리뷰가 돌았으면 DS-30 기록을 지운다. 백그라운드 리뷰어는 SubagentStop 까지 리뷰 중
  local who st
  who="$(printf '%s' "$1" | jq -r '(.tool_input.skill // "") + " " + (.tool_input.subagent_type // "")')"
  case "$who" in *document-slop-review*) ;; *) exit 0 ;; esac
  st="$(state_file "$1")" || exit 0
  if printf '%s' "$1" | jq -e '(.tool_response | objects | (.isAsync == true or .status == "async_launched")) // false' >/dev/null 2>&1; then
    : > "${st%.list}.pending"
  else
    rm -f "$st"
  fi
  exit 0
}

hook_subagent_stop() { # $1=훅 입력
  local st
  case "$(printf '%s' "$1" | jq -r '.agent_type // ""')" in
    *document-slop-reviewer*) st="$(state_file "$1")" && rm -f "$st" "${st%.list}.pending" ;;
  esac
  exit 0
}

hook_stop() { # $1=훅 입력
  local st active list
  [ "${DOCUMENT_SLOP_REVIEW_GATE:-1}" != 0 ] || exit 0
  st="$(state_file "$1")" || exit 0
  [ -s "$st" ] || exit 0
  # 백그라운드 리뷰어를 기다리며 끝내는 응답 — 막지 않고 기록을 남긴다 (완료 알림 뒤 다시 판정)
  [ -e "${st%.list}.pending" ] && exit 0
  active="$(printf '%s' "$1" | jq -r '.stop_hook_active // false')"
  if [ "$active" = true ]; then rm -f "$st"; exit 0; fi
  list="$(head -10 "$st" | sed 's/^/  - /')"
  jq -n --arg r "완료 보류 (common-document-slop-review DS-30): 이번 세션에서 고친 문서를 판단 리뷰하지 않았다.
${list}
document-slop-review 스킬로 리뷰하고 결함을 고친다 (근거 대조 · 지워도 되는 문장 · 반복 · 구조).
오탈자처럼 리뷰할 내용이 없는 변경이면 그 이유를 한 줄로 말하고 끝낸다 — 다음 종료는 막지 않는다.
규칙: $RULES" '{decision: "block", reason: $r}'
  exit 0
}

if [ "${1:-}" = "--hook" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  INPUT="$(cat)"
  printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1 || exit 0
  case "$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')" in
    PostToolUse)
      case "$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')" in
        Write|Edit|MultiEdit) hook_edit "$INPUT" ;;
        Skill|Agent|Task) hook_review "$INPUT" ;;
      esac ;;
    SubagentStop) hook_subagent_stop "$INPUT" ;;
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
  TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || die "--diff 는 git 저장소 안에서만 쓴다"
  if [ -z "$BASE" ]; then
    BASE="$(git -C "$TOP" merge-base HEAD origin/HEAD 2>/dev/null || git -C "$TOP" merge-base HEAD origin/main 2>/dev/null || git -C "$TOP" rev-parse HEAD)"
  fi
  while IFS= read -r rel; do
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && is_doc "$TOP/$rel" || continue
    lines="$(git -C "$TOP" diff -U0 "$BASE" -- "$rel" | awk '/^@@/ { s = $3; sub(/^\+/, "", s); k = split(s, a, ","); c = (k < 2) ? 1 : a[2]; for (i = 0; i < c; i++) printf " %d", a[1] + i }')"
    [ -n "$lines" ] && add_file "$TOP/$rel" "$lines"
  done <<EOF
$(git -C "$TOP" diff --name-only --diff-filter=AMR "$BASE")
EOF
  while IFS= read -r rel; do
    [ -n "$rel" ] && [ -f "$TOP/$rel" ] && is_doc "$TOP/$rel" || continue
    add_file "$TOP/$rel" ""
  done <<EOF
$(git -C "$TOP" ls-files --others --exclude-standard)
EOF
else
  [ "${#TARGETS[@]}" -gt 0 ] || TARGETS=(".")
  for t in "${TARGETS[@]}"; do
    [ -e "$t" ] || die "없는 경로: $t"
    if [ -d "$t" ]; then
      while IFS= read -r f; do
        [ -n "$f" ] && [ -f "$f" ] && is_doc "$f" || continue
        add_file "$f" ""
      done <<EOF
$(list_dir "$t")
EOF
    else
      is_doc "$t" && add_file "$t" ""
    fi
  done
fi

N=0; B=0; W=0
SEL_FILE="$(mktemp "${TMPDIR:-/tmp}/document-slop.XXXXXX")" || die "임시 파일을 만들지 못했다"
for i in ${FILES+"${!FILES[@]}"}; do
  f="${FILES[$i]}"; set_="${LINESETS[$i]}"
  N=$((N+1)); OUT=""
  if [ -n "$set_" ]; then printf '%s\n' "$set_" > "$SEL_FILE"; mode=lines; else : > "$SEL_FILE"; mode=all; fi
  while IFS=$'\x1f' read -r ln rule lvl msg; do
    [ -n "$rule" ] || continue
    if [ "$lvl" = block ]; then B=$((B+1)); OUT="${OUT}  ❌ $(where "$ln") ${rule} ${msg}
"
    else W=$((W+1)); OUT="${OUT}  ⚠️  $(where "$ln") ${rule} ${msg}
"
    fi
  done <<EOF
$(check_file "$f" "$mode" "$SEL_FILE" | resolve "$f")
EOF
  [ -z "$OUT" ] || { echo "$f"; printf '%s' "$OUT"; }
done

if [ "$DIFF" = 1 ]; then SCOPE="변경 문서 ${N}개 (기준 $(git -C "$TOP" rev-parse --short "$BASE"))"; else SCOPE="문서 ${N}개"; fi
echo "${SCOPE}, 차단 ${B}건 · 경고 ${W}건 — 경고는 후보다. 판정은 document-slop-review 스킬 · 규칙: $RULES"
[ "$B" -gt 0 ] && exit 2
[ "$STRICT" = 1 ] && [ "$W" -gt 0 ] && exit 2
exit 0
