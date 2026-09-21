#!/usr/bin/env bash
# Kotlin 코드의 이름이 Kotlin 컨벤션(Kotlin 공식 Coding conventions 의 Naming rules)을 지키는지 검증한다.
# 단어 선택 · 줄임말 · 뜻은 보지 않는다 — kotlin-name-create 스킬이 판단한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit) → *.kt 의 편집 뒤 내용을 편집 전 내용과 비교해 **새로 생긴 위반만** 막는다.
#                            경고만 있으면 additionalContext 로 알린다.
# CLI 모드 :
#   validate-kotlin-naming.sh <파일|디렉터리> ...
#   validate-kotlin-naming.sh --all [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/kotlin-naming-rules.md"
LABEL="kotlin-naming"

die() { echo "validate-kotlin-naming: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/kotlin-naming.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

ERRORS=()
WARNINGS=()

# ---- 대상 -----------------------------------------------------------------
# 검사할 파일인가. 빌드 산출물 · 의존성 · 생성 코드는 보지 않는다. *.kts(빌드 스크립트)는 보지 않는다.
is_target() { # $1=경로
  case "$1" in
    *.kt) ;;
    *) return 1 ;;
  esac
  case "/$1" in
    */node_modules/*|*/build/*|*/target/*|*/out/*|*/.gradle/*|*/generated/*|*/.git/*) return 1 ;;
  esac
  return 0
}

# 테스트 코드인가 — 테스트 함수 이름의 밑줄을 허용한다
is_test_path() { # $1=경로
  case "/$1" in
    */test/*|*/*Test/*|*Test.kt|*Tests.kt) return 0 ;;
  esac
  return 1
}

# ---- 언어 규칙 --------------------------------------------------------------
# $1=내용 파일 $2=원래 파일명(basename) $3=원래 경로 → "E|W \037 조항 \037 줄 \037 메시지" 줄들
scan() {
  local istest=0
  is_test_path "${3:-$2}" && istest=1
  awk -v fname="$2" -v istest="$istest" '
    function upper_camel(s,   n, i, out, parts) {
      if (s ~ /_/) {
        n = split(tolower(s), parts, "_"); out = ""
        for (i = 1; i <= n; i++) if (parts[i] != "") out = out toupper(substr(parts[i], 1, 1)) substr(parts[i], 2)
        return out
      }
      return toupper(substr(s, 1, 1)) substr(s, 2)
    }
    function lower_camel(s,   pre, u) {
      pre = ""; if (s ~ /^_/) { pre = "_"; sub(/^_+/, "", s) }
      u = upper_camel(s); return pre tolower(substr(u, 1, 1)) substr(u, 2)
    }
    function upper_snake(s,   out, i, c, prev) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1); prev = substr(s, i - 1, 1)
        if (i > 1 && c ~ /[A-Z]/ && prev ~ /[a-z0-9]/) out = out "_"
        out = out c
      }
      return toupper(out)
    }
    function emit(kind, code, ln, msg) { printf "%s\037%s\037%d\037%s\n", kind, code, ln, msg }
    function lead_ident(s) { sub(/[^A-Za-z0-9_].*$/, "", s); return s }
    function strip_tparams(s) { sub(/^<[^<>]*(<[^<>]*>[^<>]*)*>[ \t]*/, "", s); return s }

    # 문자열 · 문자 리터럴 · 주석(중첩 블록 주석 포함) · 백틱 이름을 비운다. 여러 줄 raw string 은 줄을 넘어 이어진다
    function clean(s,   out, i, n, c, c2, c3, j) {
      out = ""; n = length(s); i = 1
      while (i <= n) {
        c = substr(s, i, 1); c2 = substr(s, i, 2); c3 = substr(s, i, 3)
        if (cdepth > 0) {
          if (c2 == "/*") { cdepth++; i += 2 }
          else if (c2 == "*/") { cdepth--; i += 2; if (cdepth == 0) out = out " " }
          else i++
          continue
        }
        if (inraw) {
          if (c3 == "\"\"\"") { inraw = 0; i += 3; while (substr(s, i, 1) == "\"") i++; out = out "\"\"" }
          else i++
          continue
        }
        if (c2 == "//") break
        if (c2 == "/*") { cdepth = 1; i += 2; continue }
        if (c3 == "\"\"\"") { inraw = 1; i += 3; continue }
        if (c == "\"" || c == "\047") {
          i++
          while (i <= n) { j = substr(s, i, 1); if (j == "\\") { i += 2; continue } i++; if (j == c) break }
          out = out c c; continue
        }
        if (c == "`") {
          j = index(substr(s, i + 1), "`"); if (j == 0) break
          i += j + 1; out = out "``"; continue
        }
        out = out c; i++
      }
      return out
    }

    # 팩터리 함수 판정 — "fun Foo(…): Foo" 의 반환 타입이 이름과 같은가. 매개변수가 여러 줄이면 닫는 괄호까지 기다린다
    function resolve_factory(   i, n, c, d, rest) {
      n = length(pbuf); d = 0
      for (i = 1; i <= n; i++) {
        c = substr(pbuf, i, 1)
        if (c == "(") d++
        else if (c == ")") { d--; if (d == 0) {
          rest = substr(pbuf, i + 1)
          if (rest !~ ("^[ \t]*:[ \t]*" pname "([^A-Za-z0-9_]|$)"))
            emit("E", "KN-05", pline, "함수 이름 \047" pname "\047 는 lowerCamelCase 여야 한다 → \047" lower_camel(pname) "\047 (대문자로 시작하는 것은 반환 타입이 " pname " 인 팩터리 함수 · @Composable 뿐이다)")
          pname = ""; return
        } }
      }
      if (NR - pline > 30) { pname = ""; return }
    }

    function check_fun(s, before, comp,   p, head, n, ok) {
      if (s ~ /^interface([^A-Za-z0-9_]|$)/) return
      s = strip_tparams(s)
      if (s ~ /^[`(]/) return
      p = index(s, "("); head = (p == 0) ? s : substr(s, 1, p - 1)
      # 확장 함수의 수신 타입 — "String.foo" · "List<T>.foo" · "Foo?.foo"
      if (match(head, /^[A-Za-z_][A-Za-z0-9_.]*(<.*>)?\??\./)) head = substr(head, RLENGTH + 1)
      if (head ~ /^`/) return
      n = lead_ident(head); if (n == "") return
      ok = istest ? (n ~ /^[a-z][A-Za-z0-9_]*$/) : (n ~ /^[a-z][A-Za-z0-9]*$/)
      if (ok) return
      if (comp || before ~ COMPOSABLE) return
      if (n ~ /^[A-Z][A-Za-z0-9]*$/) {
        pname = n; pline = NR; pbuf = (p == 0) ? "" : substr(s, p)
        resolve_factory(); return
      }
      emit("E", "KN-05", NR, "함수 이름 \047" n "\047 는 lowerCamelCase 여야 한다 → \047" lower_camel(n) "\047")
    }

    BEGIN {
      cdepth = 0; inraw = 0; bdepth = 0; pdepth = 0; comppending = 0; pname = ""
      ncls = 0; nother = 0
      COMPOSABLE = "@([A-Za-z_][A-Za-z0-9_]*\\.)*Composable([^A-Za-z0-9_]|$)"
    }
    {
      line = clean($0)
      bd0 = bdepth; pd0 = pdepth
      t = line; o = gsub(/[{]/, "", t); t = line; c = gsub(/[}]/, "", t); bdepth += o - c; if (bdepth < 0) bdepth = 0
      t = line; o = gsub(/[(]/, "", t); t = line; c = gsub(/[)]/, "", t); pdepth += o - c; if (pdepth < 0) pdepth = 0

      if (pname != "") { pbuf = pbuf " " line; resolve_factory() }
      if (line ~ /^[ \t]*$/) next

      # 어노테이션만 있는 줄 — 다음 선언에 붙는다
      if (line ~ /^[ \t]*(@[A-Za-z_][A-Za-z0-9_.:]*(\([^()]*\))?[ \t]*)+$/) { if (line ~ COMPOSABLE) comppending = 1; next }
      comp = comppending; comppending = 0

      # KN-01 패키지
      if (line ~ /^[ \t]*package[ \t]+[A-Za-z0-9_.]+/) {
        p = line; sub(/^[ \t]*package[ \t]+/, "", p); sub(/[^A-Za-z0-9_.].*$/, "", p)
        # 공식 컨벤션은 여러 단어를 이어 붙이거나 camelCase(org.example.myProject)로 쓰는 것을 허용한다 — 대문자로 시작하는 조각만 막는다
        if (p ~ /(^|\.)[A-Z]/) emit("E", "KN-01", NR, "패키지 \047" p "\047 의 조각은 소문자로 시작해야 한다 → \047" tolower(p) "\047")
        else if (p ~ /_/) emit("W", "KN-01", NR, "패키지 \047" p "\047 에 밑줄이 있다 — 단어를 밑줄 없이 이어 붙인다 (\047" p "\047 → \047" tolower(upper_camel(p)) "\047 처럼)")
        next
      }
      if (line ~ /^[ \t]*import[ \t]/) next

      # KN-03 을 위한 최상위 선언 수집 — 중괄호 · 괄호 밖에서 시작하는 선언
      if (bd0 == 0 && pd0 == 0) {
        d = line; sub(/^[ \t]*(@[A-Za-z_][A-Za-z0-9_.:]*(\([^()]*\))?[ \t]+)*/, "", d)
        sub(/^((public|private|internal|protected|abstract|final|open|sealed|data|enum|annotation|inner|value|inline|expect|actual|const|lateinit|override|suspend|tailrec|operator|infix|external)[ \t]+)*/, "", d)
        if (d ~ /^fun[ \t]+interface[ \t]+[A-Za-z_]/) { sub(/^fun[ \t]+/, "", d) }
        if (d ~ /^(class|interface|object)[ \t]+[A-Za-z_]/) {
          sub(/^(class|interface|object)[ \t]+/, "", d); ncls++; clsname = lead_ident(d); clsline = NR
        } else if (d ~ /^(fun|val|var|typealias)([^A-Za-z0-9_]|$)/) nother++
      }

      # KN-02 타입 이름 · KN-07 약어 — 이름 없는 companion object · object 식은 이름 자리에 식별자가 없어 맞지 않는다
      rest = " " line
      while (match(rest, /[^A-Za-z0-9_.@:](class|interface|object|typealias)[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        n = m; sub(/^.*[ \t]/, "", n)
        if (n !~ /^[A-Z][A-Za-z0-9]*$/)      emit("E", "KN-02", NR, "타입 이름 \047" n "\047 는 UpperCamelCase 여야 한다 → \047" upper_camel(n) "\047")
        else if (n ~ /[A-Z][A-Z][A-Z][A-Z]/) emit("W", "KN-07", NR, "타입 이름 \047" n "\047 — 약어는 두 글자까지만 대문자로 쓴다 (HTTPClient → HttpClient, IOStream 은 된다)")
      }

      # KN-04 const val
      rest = " " line
      while (match(rest, /[^A-Za-z0-9_]const[ \t]+val[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        n = m; sub(/^.*[ \t]/, "", n)
        if (n != "serialVersionUID" && n !~ /^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$/)
          emit("E", "KN-04", NR, "상수 \047" n "\047 (const val) 는 SCREAMING_SNAKE_CASE 여야 한다 → \047" upper_snake(n) "\047")
      }

      # KN-05 fun
      rest = " " line; before = ""
      while (match(rest, /[^A-Za-z0-9_.@:]fun[ \t]+/)) {
        before = before substr(rest, 1, RSTART)
        rest = substr(rest, RSTART + RLENGTH)
        check_fun(rest, before, comp)
      }

      # KN-06 val · var — 소문자로 시작하는 snake_case 만 막는다
      rest = " " line; before = ""
      while (match(rest, /[^A-Za-z0-9_.@:]va[lr][ \t]+/)) {
        before = before substr(rest, 1, RSTART)
        s = substr(rest, RSTART + RLENGTH); rest = s
        if (before ~ /(^|[^A-Za-z0-9_])const[ \t]+$/) continue
        s = strip_tparams(s)
        if (s ~ /^[`(]/) continue
        if (match(s, /^[A-Za-z_][A-Za-z0-9_.]*(<[^=:]*>)?\??\./)) s = substr(s, RLENGTH + 1)
        n = lead_ident(s)
        if (n ~ /^_?[a-z][A-Za-z0-9]*_/)
          emit("E", "KN-06", NR, "프로퍼티 · 변수 이름 \047" n "\047 는 lowerCamelCase 여야 한다 → \047" lower_camel(n) "\047")
      }
    }
    END {
      if (pname != "") emit("E", "KN-05", pline, "함수 이름 \047" pname "\047 는 lowerCamelCase 여야 한다 → \047" lower_camel(pname) "\047 (대문자로 시작하는 것은 반환 타입이 " pname " 인 팩터리 함수 · @Composable 뿐이다)")
      if (fname == "") exit
      base = fname; sub(/\.kt$/, "", base); main = base; suffix = ""
      # 멀티플랫폼 접미사 — Platform.jvm.kt 는 Platform 으로 본다
      if (index(base, ".") > 0) { suffix = substr(base, index(base, ".")); main = substr(base, 1, index(base, ".") - 1) }
      if (ncls == 1 && nother == 0) {
        if (main != clsname)
          emit("E", "KN-03", clsline, "최상위 선언이 \047" clsname "\047 하나뿐이다 — 파일 이름은 " clsname suffix ".kt 여야 한다 (지금 " fname ")")
      } else if (ncls + nother > 0 && main !~ /^[A-Z][A-Za-z0-9]*$/) {
        emit("W", "KN-03", 1, "파일 이름 \047" fname "\047 은 UpperCamelCase 로 쓴다 → \047" upper_camel(main) suffix ".kt\047")
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

check_file() { # $1=경로 [$2=테스트 경로 판정에 쓸 상대 경로]
  scan "$1" "$(basename "$1")" "${2:-$1}" > "$TMP/scan"
  collect "$TMP/scan" "$1"
}

report_cli() {
  local w e
  for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "⚠️  $w" >&2; done
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "" >&2
    echo "❌ Kotlin 네이밍 규칙 위반 ($LABEL)" >&2
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

  scan "$TMP/before" "$name" "$rel" > "$TMP/scan-before"
  scan "$TMP/after" "$name" "$rel" > "$TMP/scan-after"
  # 새로 생긴 위반 — 줄 번호를 빼고 (종류 · 조항 · 메시지) 로 센다. 같은 위반이 늘어난 만큼만 새것이다
  # NR == FNR 은 첫 파일이 비면 둘째 파일에서도 참이 된다 — 파일 이름으로 가른다
  awk -F'\037' 'FILENAME == ARGV[1] { seen[$1 FS $2 FS $4]++; next } seen[$1 FS $2 FS $4]-- > 0 { next } { print }' \
    "$TMP/scan-before" "$TMP/scan-after" > "$TMP/scan-new"
  collect "$TMP/scan-new" "$path"

  local e w body
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "❌ Kotlin 네이밍 규칙 위반 ($LABEL) — 이 편집이 새로 만든 이름만 봤다" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w" >&2; done
    echo "제안한 이름으로 고쳐 다시 써라. 규칙: $RULES" >&2
    exit 2
  fi
  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    body="Kotlin 네이밍 경고 ($LABEL) — 막지 않았다. 이 프로젝트의 기존 관례와 맞는지 보고 필요하면 고쳐라."
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
    is_target "${f#"$root"/}" && check_file "$f" "${f#"$root"/}"
  done < <(find "$root" \( -name .git -o -name node_modules -o -name build -o -name target -o -name .gradle \
                          -o -path "$root/.claude/worktrees" \) -prune -o -type f -name '*.kt' -print 2>/dev/null | sort)
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
