#!/usr/bin/env bash
# Go 코드의 이름이 Go 컨벤션(Effective Go · Go Code Review Comments · staticcheck ST1003)을 지키는지 검증한다.
# 단어 선택 · 줄임말 · 뜻은 보지 않는다 — go-name-create 스킬이 판단한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit) → *.go 의 편집 뒤 내용을 편집 전 내용과 비교해 **새로 생긴 위반만** 막는다.
#                            경고만 있으면 additionalContext 로 알린다.
# CLI 모드 :
#   validate-go-naming.sh <파일|디렉터리> ...
#   validate-go-naming.sh --all [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/go-naming-rules.md"
LABEL="go-naming"

die() { echo "validate-go-naming: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/go-naming.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

ERRORS=()
WARNINGS=()

# ---- 대상 -----------------------------------------------------------------
# 검사할 파일인가. 의존성 · 테스트 데이터는 보지 않는다. 생성 파일은 scan 이 내용으로 가른다.
is_target() { # $1=경로
  case "$1" in
    *.go) ;;
    *) return 1 ;;
  esac
  case "/$1" in
    */vendor/*|*/testdata/*|*/node_modules/*|*/.git/*) return 1 ;;
  esac
  return 0
}

# ---- 언어 규칙 --------------------------------------------------------------
# $1=내용 파일 $2=원래 파일명(basename) → "E|W \037 조항 \037 줄 \037 메시지" 줄들
scan() {
  awk -v fname="$2" '
    # 주석 · 문자열 · 룬 · raw string 을 비운다. 블록 주석과 raw string 은 줄을 넘는다
    function clean(s,   out, i, n, c, q, j) {
      out = ""; i = 1; n = length(s)
      while (i <= n) {
        if (inblock) { j = index(substr(s, i), "*/"); if (j == 0) return out; i += j + 1; inblock = 0; out = out " "; continue }
        if (inraw)   { j = index(substr(s, i), "`");  if (j == 0) return out; i += j;     inraw = 0;   out = out "\"\""; continue }
        c = substr(s, i, 1)
        if (c == "/" && substr(s, i + 1, 1) == "/") return out
        if (c == "/" && substr(s, i + 1, 1) == "*") { inblock = 1; i += 2; continue }
        if (c == "`") { inraw = 1; i++; continue }
        if (c == "\"" || c == "\047") {
          q = c; i++
          while (i <= n) { c = substr(s, i, 1); if (c == "\\") { i += 2; continue } if (c == q) break; i++ }
          i++; out = out q q; continue
        }
        out = out c; i++
      }
      return out
    }
    # 이니셜리즘을 대문자로 — 뒤에 대문자나 끝이 올 때만 (Identity · Ids 는 건드리지 않는다)
    function initial(s,   out, i, k, w, L, nx, hit) {
      out = ""; i = 1
      while (i <= length(s)) {
        hit = 0
        for (k = 1; k <= NW; k++) {
          w = IW[k]; L = length(w)
          if (substr(s, i, L) == w) {
            nx = substr(s, i + L, 1)
            if (nx == "" || nx ~ /[A-Z]/) { out = out toupper(w); i += L; hit = 1; break }
          }
        }
        if (!hit) { out = out substr(s, i, 1); i++ }
      }
      return out
    }
    # 밑줄을 없앤 MixedCaps — 첫 글자의 대소문자(공개 여부)를 유지한다
    function mixed(s,   n, p, i, w, out, allup, exported) {
      exported = (s ~ /^_*[A-Z]/); allup = (s !~ /[a-z]/)
      n = split(s, p, "_"); out = ""
      for (i = 1; i <= n; i++) {
        if (p[i] == "") continue
        w = p[i]; if (allup) w = tolower(w)
        if (out != "") w = toupper(substr(w, 1, 1)) substr(w, 2)
        out = out w
      }
      if (exported) out = toupper(substr(out, 1, 1)) substr(out, 2)
      else          out = tolower(substr(out, 1, 1)) substr(out, 2)
      return initial(out)
    }
    function snake(s,   out, i, c, prev) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1); prev = substr(s, i - 1, 1)
        if (i > 1 && c ~ /[A-Z]/ && prev ~ /[a-z0-9]/) out = out "_"
        out = out c
      }
      gsub(/-/, "_", out)
      return tolower(out)
    }
    function emit(kind, code, msg) { OUT[++NO] = sprintf("%s\037%s\037%d\037%s", kind, code, NR, msg) }
    # s 앞의 식별자 목록(a, b, c)을 NM[1..n] 에 담고 n 을 돌려준다. 남은 글은 REST
    function names(s,   n, t) {
      n = 0
      while (match(s, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*/)) {
        t = substr(s, RSTART, RLENGTH); gsub(/[ \t]/, "", t); NM[++n] = t; s = substr(s, RSTART + RLENGTH)
        if (s ~ /^[ \t]*,/) sub(/^[ \t]*,/, "", s); else break
      }
      REST = s
      return n
    }
    # GO-02 밑줄 · GO-03 이니셜리즘
    function check(what, n,   fix) {
      if (n == "_" || n == "") return
      if (n ~ /_/) {
        if (what == "함수" && istest && n ~ /^(Test|Benchmark|Example|Fuzz)/) return
        fix = mixed(n)
        emit("E", "GO-02", what " 이름 \047" n "\047 에 밑줄을 쓰지 않는다 (MixedCaps) → \047" fix "\047")
        return
      }
      fix = initial(n)
      if (fix != n) emit("W", "GO-03", what " 이름 \047" n "\047 — 이니셜리즘은 대소문자를 한 가지로 쓴다 → \047" fix "\047")
    }
    # GO-04 매개변수 없는 GetX()
    function getter(n, after) {
      if (n ~ /^[Gg]et[A-Z0-9]/ && after ~ /^[ \t]*\([ \t]*\)/)
        emit("W", "GO-04", "게터 \047" n "()\047 에 Get 을 붙이지 않는다 → \047" (n ~ /^G/ ? substr(n, 4) : tolower(substr(n, 4, 1)) substr(n, 5)) "()\047")
    }

    BEGIN {
      NW = split("Https Http Uuid Url Uri Json Api Sql Html Xml Ip Tcp Udp Rpc Ssh Tls Ttl Cpu Dns Id", IW, " ")
      istest = (fname ~ /_test\.go$/)
      inblock = 0; inraw = 0; bd = 0; pd = 0; group = ""; seenpkg = 0; generated = 0; NO = 0
    }
    {
      raw = $0; sub(/\r$/, "", raw)
      if (!seenpkg && raw ~ /^\/\/ Code generated .* DO NOT EDIT\.[ \t]*$/) generated = 1
      line = clean(raw)
      if (line ~ /^[ \t]*$/) next

      ctx = (bd > 0) ? stk[bd] : ""
      atpd = (bd > 0) ? spd[bd] : 0
      t = line; sub(/^[ \t]+/, "", t)

      if (bd == 0 && pd == 0) {
        # GO-01 패키지
        if (t ~ /^package[ \t]+[A-Za-z_]/) {
          seenpkg = 1
          p = t; sub(/^package[ \t]+/, "", p); sub(/[^A-Za-z0-9_].*$/, "", p)
          if (p !~ /^[a-z][a-z0-9]*(_test)?$/) {
            fix = p; suf = ""
            if (fix ~ /_test$/) { suf = "_test"; sub(/_test$/, "", fix) }
            fix = tolower(fix); gsub(/_/, "", fix)
            emit("E", "GO-01", "패키지 \047" p "\047 는 소문자 한 단어여야 한다 (밑줄 · 대문자 X) → \047" fix suf "\047")
          }
        }
        # 함수 · 메서드
        else if (t ~ /^func[ \t(]/) {
          f = t; sub(/^func[ \t]*/, "", f); ismethod = 0
          if (f ~ /^\(/) {
            ismethod = 1
            recv = f; sub(/\).*$/, "", recv); sub(/^\([ \t]*/, "", recv)
            f = substr(f, index(f, ")") + 1); sub(/^[ \t]+/, "", f)
            # GO-06 리시버 이름
            if (recv ~ /^[A-Za-z_][A-Za-z0-9_]*[ \t]+/) {
              rn = recv; sub(/[ \t].*$/, "", rn)
              rt = recv; sub(/^[A-Za-z_][A-Za-z0-9_]*[ \t]+/, "", rt); gsub(/[* \t]/, "", rt); sub(/\[.*$/, "", rt)
              if (rn == "this" || rn == "self")
                emit("W", "GO-06", "리시버 \047" rn "\047 대신 타입의 짧은 약자를 쓴다 → \047func (" tolower(substr(rt, 1, 1)) " " (recv ~ /\*/ ? "*" : "") rt ")\047")
            }
          }
          if (match(f, /^[A-Za-z_][A-Za-z0-9_]*/)) {
            n = substr(f, 1, RLENGTH); after = substr(f, RLENGTH + 1)
            check(ismethod ? "메서드" : "함수", n)
            if (ismethod) getter(n, after)
          }
        }
        else if (t ~ /^type[ \t]+[A-Za-z_]/) { f = t; sub(/^type[ \t]+/, "", f); if (names(f) > 0) check("타입", NM[1]) }
        else if (t ~ /^(var|const)[ \t]+[A-Za-z_]/) {
          what = (t ~ /^var/) ? "변수" : "상수"
          f = t; sub(/^(var|const)[ \t]+/, "", f); k = names(f)
          for (i = 1; i <= k; i++) check(what, NM[i])
        }
        if (t ~ /^(var|const|type|import)[ \t]*\(/) { group = t; sub(/[ \t]*\(.*$/, "", group) }
      }
      # 괄호 블록 안의 선언 — var ( … ) · const ( … ) · type ( … )
      else if (bd == 0 && pd == 1 && group != "") {
        k = names(t)
        if (group == "type" && k > 0) check("타입", NM[1])
        else if (group == "var" || group == "const") for (i = 1; i <= k; i++) check(group == "var" ? "변수" : "상수", NM[i])
      }
      # 구조체 필드 — 이름 목록 뒤에 타입이 온다. 임베딩(Type · *Type · pkg.Type)은 이름이 아니다
      else if (ctx == "S" && pd == atpd) {
        k = names(t)
        if (k > 1 || (k == 1 && REST ~ /^[ \t]+[^ \t"]/)) for (i = 1; i <= k; i++) check("필드", NM[i])
      }
      # 인터페이스 메서드
      else if (ctx == "I" && pd == atpd) {
        if (match(t, /^[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) {
          n = t; sub(/[^A-Za-z0-9_].*$/, "", n); after = substr(t, length(n) + 1)
          check("메서드", n); getter(n, after)
        }
      }
      # 함수 안의 타입 선언
      else if (ctx == "B" && t ~ /^type[ \t]+[A-Za-z_]/) { f = t; sub(/^type[ \t]+/, "", f); if (names(f) > 0) check("타입", NM[1]) }

      # 괄호 깊이 — { 앞이 struct / interface 면 그 본문이다
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "{") {
          pre = substr(line, 1, i - 1); bd++; spd[bd] = pd
          stk[bd] = (pre ~ /(^|[^A-Za-z0-9_])struct[ \t]*$/) ? "S" : (pre ~ /(^|[^A-Za-z0-9_])interface[ \t]*$/) ? "I" : "B"
        }
        else if (c == "}") { if (bd > 0) bd-- }
        else if (c == "(") pd++
        else if (c == ")") { if (pd > 0) pd-- }
      }
      if (bd == 0 && pd == 0) group = ""
    }
    END {
      if (generated) exit
      for (i = 1; i <= NO; i++) print OUT[i]
      # GO-05 파일 이름 — 내용이 있을 때만 (새 파일의 "편집 전" 과 비교하려고)
      if (NR > 0 && fname ~ /[A-Z-]/) {
        base = fname; sub(/\.go$/, "", base)
        printf "W\037GO-05\0371\037파일 이름 \047%s\047 는 소문자 · 숫자 · 밑줄로 쓴다 → \047%s.go\047\n", fname, snake(base)
      }
    }
  ' "$1"
}

# ---- 수집 · 출력 ------------------------------------------------------------
collect() { # $1=scan 출력 파일 $2=라벨(경로)
  local kind code ln msg
  while IFS=$'\037' read -r kind code ln msg; do
    [ -n "$kind" ] || continue
    if [ "$kind" = E ]; then ERRORS+=("$2:$ln: $msg ($code)"); else WARNINGS+=("$2:$ln: $msg ($code)"); fi
  done < "$1"
}

check_file() { # $1=경로
  scan "$1" "$(basename "$1")" > "$TMP/scan"
  collect "$TMP/scan" "$1"
}

report_cli() {
  local w e
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w" >&2; done
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ Go 네이밍 규칙 위반 ($LABEL)" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    echo "" >&2
    echo "규칙: $RULES" >&2
    exit 2
  fi
  exit 0
}

# ---- 훅 ---------------------------------------------------------------------
# 편집 뒤 내용을 만든다. Write 는 content, Edit 는 현재 파일에 치환을 적용한다.
# jq 의 index 는 버전에 따라 바이트 · 글자 기준이 갈리므로 split 으로 첫 번째만 바꾼다.
after_content() { # $1=payload $2=현재 파일(없으면 빈 파일)
  printf '%s' "$1" | jq -j --rawfile cur "$2" '
    def rep($s; $o; $n; $all):
      if $o == "" then $s
      elif $all then ($s | split($o) | join($n))
      else ($s | split($o)) as $p | if ($p | length) < 2 then $s else $p[0] + $n + ($p[1:] | join($o)) end
      end;
    .tool_input as $t
    | if ($t.content | type) == "string" then $t.content
      elif ($t.edits | type) == "array" then reduce $t.edits[] as $e ($cur; rep(.; $e.old_string // ""; $e.new_string // ""; $e.replace_all // false))
      else rep($cur; $t.old_string // ""; $t.new_string // ""; $t.replace_all // false)
      end'
}

hook() {
  local payload path rel name
  payload="$(cat)"
  [ -n "$payload" ] || exit 0
  [ "$(printf '%s' "$payload" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null)" = PreToolUse ] || exit 0
  path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)"
  [ -n "$path" ] || exit 0
  # 제외 디렉터리는 프로젝트 기준 상대 경로로 본다 — 프로젝트가 build/ · test/ 같은 이름의 폴더 아래 있어도 오판하지 않게
  rel="${path#"${PROJECT_DIR%/}"/}"
  is_target "$rel" || exit 0
  name="$(basename "$path")"

  : > "$TMP/before"
  [ -f "$path" ] && cat "$path" > "$TMP/before"
  after_content "$payload" "$TMP/before" > "$TMP/after" || exit 0

  scan "$TMP/before" "$name" > "$TMP/scan-before"
  scan "$TMP/after" "$name" > "$TMP/scan-after"
  # 새로 생긴 위반 — 줄 번호를 빼고 (종류 · 조항 · 메시지) 로 센다. 같은 위반이 늘어난 만큼만 새것이다
  # NR == FNR 은 첫 파일이 비면 둘째 파일에서도 참이 된다 — 파일 이름으로 가른다
  awk -F'\037' 'FILENAME == ARGV[1] { seen[$1 FS $2 FS $4]++; next } seen[$1 FS $2 FS $4]-- > 0 { next } { print }' \
    "$TMP/scan-before" "$TMP/scan-after" > "$TMP/scan-new"
  collect "$TMP/scan-new" "$path"

  local e w body
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "❌ Go 네이밍 규칙 위반 ($LABEL) — 이 편집이 새로 만든 이름만 봤다" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w" >&2; done
    echo "제안한 이름으로 고쳐 다시 써라. 규칙: $RULES" >&2
    exit 2
  fi
  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    body="Go 네이밍 경고 ($LABEL) — 막지 않았다. 이 프로젝트의 기존 관례와 맞는지 보고 필요하면 고쳐라."
    for w in "${WARNINGS[@]}"; do body="$body"$'\n'"- $w"; done
    body="$body"$'\n'"규칙: $RULES"
    jq -n --arg c "$body" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  fi
  exit 0
}

# ---- CLI --------------------------------------------------------------------
check_tree() { # $1=루트 디렉터리
  local root="${1%/}" f
  # 제외는 루트 기준으로 쓴다 — "*/.claude/…" 는 루트가 워크트리 안이면 전부 제외한다
  while IFS= read -r f; do
    is_target "${f#"$root"/}" && check_file "$f"
  done < <(find "$root" \( -name .git -o -name node_modules -o -name vendor -o -name testdata \
                          -o -path "$root/.claude/worktrees" \) -prune -o -type f -name '*.go' -print 2>/dev/null | sort)
}

main() {
  [ "$#" -gt 0 ] || hook
  local arg
  case "$1" in
    --all) check_tree "${2:-$PROJECT_DIR}" ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) for arg in "$@"; do
         if [ -d "$arg" ]; then check_tree "$arg"
         elif [ -f "$arg" ]; then check_file "$arg"
         else die "없는 경로: $arg"; fi
       done ;;
  esac
  report_cli
}

main "$@"
