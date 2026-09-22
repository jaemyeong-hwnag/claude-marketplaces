#!/usr/bin/env bash
# TypeScript 소스의 식별자가 TypeScript 명명 관례(TypeScript 팀 Coding guidelines · Google TypeScript Style Guide)를 지키는지 검증한다.
# 단어 선택 · 줄임말 · 뜻은 보지 않는다 — typescript-name-create 스킬이 판단한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit) → *.ts · *.tsx · *.mts · *.cts 의 편집 뒤 내용을 편집 전 내용과 비교해 **새로 생긴 위반만** 막는다.
#                            경고만 있으면 additionalContext 로 알린다.
# CLI 모드 :
#   validate-typescript-naming.sh <파일|디렉터리> ...
#   validate-typescript-naming.sh --all [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/typescript-naming-rules.md"
LABEL="typescript-naming"

die() { echo "validate-typescript-naming: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/typescript-naming.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

ERRORS=()
WARNINGS=()

# ---- 대상 -----------------------------------------------------------------
# 검사할 파일인가. 선언 파일 · 빌드 산출물 · 의존성 · 생성 코드는 보지 않는다.
is_target() { # $1=경로
  case "$1" in
    *.d.ts|*.d.mts|*.d.cts) return 1 ;;
    *.ts|*.tsx|*.mts|*.cts) ;;
    *) return 1 ;;
  esac
  case "/$1" in
    */node_modules/*|*/dist/*|*/build/*|*/out/*|*/coverage/*|*/.next/*|*/generated/*|*/.git/*) return 1 ;;
  esac
  return 0
}

# ---- 언어 규칙 --------------------------------------------------------------
# $1=내용 파일 $2=원래 파일명(basename) → "E|W \037 조항 \037 줄 \037 메시지" 줄들
scan() {
  awk -v fname="$2" '
    # ---- 이름 바꾸기 (제안용) ----
    function cap(p) {
      if (p ~ /^[A-Z0-9]+$/) return toupper(substr(p, 1, 1)) tolower(substr(p, 2))
      return toupper(substr(p, 1, 1)) substr(p, 2)
    }
    function pascal(s,   n, i, out, parts) {
      n = split(s, parts, "_"); out = ""
      for (i = 1; i <= n; i++) if (parts[i] != "") out = out cap(parts[i])
      return out
    }
    # 앞 밑줄은 그대로 두고 나머지를 camelCase 로
    function camel(s,   pre, core, u) {
      pre = s; sub(/[^_].*$/, "", pre); core = substr(s, length(pre) + 1)
      u = pascal(core); return pre tolower(substr(u, 1, 1)) substr(u, 2)
    }
    # 값 이름 제안 — 대문자로 시작하면 PascalCase, 아니면 camelCase
    function value_name(s,   pre, core) {
      pre = s; sub(/[^_].*$/, "", pre); core = substr(s, length(pre) + 1)
      if (core ~ /^[A-Z]/) return pre pascal(core)
      return camel(s)
    }
    function value_msg(what, n,   v) {
      v = value_name(n)
      if (v ~ /^_*[A-Z]/) return what " 이름 \047" n "\047 는 밑줄 없이 PascalCase 로 쓴다 → \047" v "\047"
      return what " 이름 \047" n "\047 는 camelCase 여야 한다 → \047" v "\047"
    }
    # 소문자가 섞인 snake_case 인가 — 앞뒤 밑줄(_unused · __dirname) 과 UPPER_SNAKE 는 아니다
    function snaky(s,   c) { c = s; sub(/^[_$]+/, "", c); sub(/_+$/, "", c); return (c ~ /_/ && c ~ /[a-z]/) }
    function is_pascal(s) { return s ~ /^[A-Z][A-Za-z0-9]*$/ }
    function emit(kind, code, msg) { printf "%s\037%s\037%d\037%s\n", kind, code, NR, msg }

    # ---- 주석 · 문자열 · 템플릿 리터럴을 비운다 (따옴표만 남긴다) ----
    function clean(s,   out, i, n, c, c2, q) {
      out = ""; n = length(s); i = 1
      while (i <= n) {
        c = substr(s, i, 1); c2 = substr(s, i, 2)
        if (st == "block") { if (c2 == "*/") { st = ""; i += 2 } else i++; continue }
        if (st == "tpl") {
          if (c == "\\") { i += 2; continue }
          if (c2 == "${") { tdepth++; i += 2; continue }
          if (c == "}" && tdepth > 0) { tdepth--; i++; continue }
          if (c == "`" && tdepth == 0) { st = ""; out = out "`"; i++; continue }
          i++; continue
        }
        if (c2 == "/*") { st = "block"; out = out " "; i += 2; continue }
        if (c2 == "//") break
        if (c == "\"" || c == "\047") {
          q = c; out = out q q; i++
          while (i <= n) { c = substr(s, i, 1); if (c == "\\") { i += 2; continue } i++; if (c == q) break }
          continue
        }
        if (c == "`") { st = "tpl"; tdepth = 0; out = out "`"; i++; continue }
        out = out c; i++
      }
      return out
    }

    # ---- TS-05 타입 매개변수 — s 는 "<" 로 시작한다. 같은 줄에서 닫힐 때만 본다 ----
    function tparams(s,   i, n, c, depth, cur, cnt, list, k, p) {
      depth = 0; cur = ""; cnt = 0; n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "=" && substr(s, i + 1, 1) == ">") { cur = cur "=>"; i++; continue }
        if (c == "<" || c == "(" || c == "[" || c == "{") { depth++; if (depth == 1) continue }
        else if (c == ">" || c == ")" || c == "]" || c == "}") {
          depth--
          if (depth == 0) {
            list[++cnt] = cur
            for (k = 1; k <= cnt; k++) {
              p = list[k]; sub(/^[ \t]+/, "", p)
              while (p ~ /^(const|in|out)[ \t]+/) sub(/^[a-z]+[ \t]+/, "", p)
              if (!match(p, /^[A-Za-z_$][A-Za-z0-9_$]*/)) continue
              p = substr(p, 1, RLENGTH)
              if (!is_pascal(p)) emit("W", "TS-05", "타입 매개변수 \047" p "\047 는 T 또는 PascalCase 로 쓴다 → \047" (length(p) == 1 ? toupper(p) : "T" pascal(p)) "\047")
            }
            return
          }
        }
        else if (c == "," && depth == 1) { list[++cnt] = cur; cur = ""; continue }
        if (depth >= 1) cur = cur c
      }
    }

    # ---- TS-04 enum 멤버 하나 ----
    function enum_member(s) {
      sub(/=.*$/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s)
      if (s !~ /^[A-Za-z_$][A-Za-z0-9_$]*$/) return      # 비었거나 따옴표 이름
      if (is_pascal(s) || s ~ /^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$/) return
      emit("W", "TS-04", "enum 멤버 \047" s "\047 는 PascalCase 또는 UPPER_SNAKE_CASE 로 쓴다 → \047" pascal(s) "\047")
    }

    BEGIN {
      st = ""; tdepth = 0; sp = 0; pend = ""; ebuf = ""
      kname["class"] = "클래스"; kname["interface"] = "인터페이스"; kname["type"] = "타입"
      kname["enum"] = "enum"; kname["namespace"] = "네임스페이스"; kname["module"] = "네임스페이스"
    }
    {
      line = clean($0)
      top = (sp > 0) ? stack[sp] : ""
      if (line ~ /^[ \t]*$/) next

      # TS-01 선언 이름 · TS-02 I 접두사 · TS-05 타입 매개변수
      rest = " " line
      while (match(rest, /[^A-Za-z0-9_$.](class|interface|enum|namespace|module|type)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
        m = substr(rest, RSTART + 1, RLENGTH - 1); after = substr(rest, RSTART + RLENGTH); rest = after
        kw = m; sub(/[ \t].*$/, "", kw); n = m; sub(/^[a-z]+[ \t]+/, "", n)
        # 뒤따르는 문맥으로 선언인지 가린다 (JSX 본문 · 변수 이름 type 을 읽지 않게)
        if (kw == "class")          ok = (after ~ /^[ \t]*($|[{<]|(extends|implements)([^A-Za-z0-9_$]|$))/)
        else if (kw == "interface") ok = (after ~ /^[ \t]*($|[{<]|extends([^A-Za-z0-9_$]|$))/)
        else if (kw == "enum")      ok = (after ~ /^[ \t]*($|\{)/)
        else if (kw == "type")      ok = (after ~ /^[ \t]*[=<]/)
        else                        ok = (after ~ /^[ \t]*(\.[A-Za-z_$][A-Za-z0-9_$.]*)?[ \t]*($|\{)/)
        if (!ok) continue
        if (kw == "class") pend = "class"; else if (kw == "enum") pend = "enum"; else if (kw == "interface") pend = "iface"
        if (!is_pascal(n)) emit("E", "TS-01", kname[kw] " 이름 \047" n "\047 는 PascalCase 여야 한다 → \047" pascal(n) "\047")
        else if (kw == "interface" && n ~ /^I[A-Z][a-z]/) emit("W", "TS-02", "인터페이스 \047" n "\047 에 I 접두사를 붙이지 않는다 → \047" substr(n, 2) "\047")
        a = after; sub(/^[ \t]+/, "", a)
        if (kw != "enum" && a ~ /^</) tparams(a)
      }
      # 이름 없는 class 식 — 본문의 멤버를 보기 위해 표시만 한다
      if (line ~ /(^|[^A-Za-z0-9_$.])class[ \t]*(\{|extends[^A-Za-z0-9_$])/) pend = "class"

      # TS-03 변수 · 함수 — ambient 선언(declare)은 이름이 밖에서 정해지므로 보지 않는다
      if (line !~ /^[ \t]*(export[ \t]+)?declare[ \t]/) {
        rest = " " line
        while (match(rest, /[^A-Za-z0-9_$.](let|const|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
          m = substr(rest, RSTART + 1, RLENGTH - 1); rest = substr(rest, RSTART + RLENGTH)
          n = m; sub(/^[a-z]+[ \t]+/, "", n)
          if (n == "enum") continue
          if (snaky(n)) emit("E", "TS-03", value_msg("변수", n))
        }
        rest = " " line
        while (match(rest, /[^A-Za-z0-9_$.]function[ \t]*\*?[ \t]*[A-Za-z_$][A-Za-z0-9_$]*/)) {
          m = substr(rest, RSTART + 1, RLENGTH - 1); after = substr(rest, RSTART + RLENGTH); rest = after
          n = m; sub(/^function[ \t]*\*?[ \t]*/, "", n)
          if (snaky(n)) emit("E", "TS-03", value_msg("함수", n))
          a = after; sub(/^[ \t]+/, "", a)
          if (a ~ /^</) tparams(a)
        }
      }

      # TS-06 class 멤버 — 접근 제어자 · readonly 로 시작하는 선언만 (생성자 매개변수 프로퍼티 포함)
      if (top == "class") {
        decl = line; sub(/^[ \t]*(@[A-Za-z_$][A-Za-z0-9_$.]*(\([^()]*\))?[ \t]+)*/, "", decl)
        if (match(decl, /^((public|private|protected|readonly|static|abstract|override|declare|async|accessor)[ \t]+)+/)) {
          mods = substr(decl, 1, RLENGTH); d = substr(decl, RLENGTH + 1)
          if (mods ~ /(public|private|protected|readonly)/) {
            sub(/^(get|set)[ \t]+/, "", d); sub(/^\*[ \t]*/, "", d)
            if (match(d, /^[A-Za-z_$][A-Za-z0-9_$]*[ \t]*[?!]?[ \t]*[:(=<;,)]/)) {
              n = substr(d, 1, RLENGTH); sub(/[^A-Za-z0-9_$].*$/, "", n)
              if (snaky(n)) emit("W", "TS-06", "class 멤버 \047" n "\047 가 snake_case 다 — API 페이로드를 그대로 받는 DTO 가 아니면 camelCase 로 → \047" camel(n) "\047")
            }
          }
        }
      }

      # 중괄호로 문맥을 따라간다 — enum 본문의 멤버(TS-04)를 여기서 모은다
      nn = length(line)
      for (i = 1; i <= nn; i++) {
        c = substr(line, i, 1)
        if (c == "{") { stack[++sp] = (pend != "") ? pend : "other"; pend = ""; ebuf = ""; continue }
        if (sp > 0 && stack[sp] == "enum") {
          if (c == "}") { enum_member(ebuf); ebuf = ""; sp--; continue }
          if (c == ",") { enum_member(ebuf); ebuf = ""; continue }
          ebuf = ebuf c; continue
        }
        if (c == "}" && sp > 0) sp--
      }
      if (sp > 0 && stack[sp] == "enum") { enum_member(ebuf); ebuf = "" }
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
    echo "❌ TypeScript 네이밍 규칙 위반 ($LABEL)" >&2
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
    echo "❌ TypeScript 네이밍 규칙 위반 ($LABEL) — 이 편집이 새로 만든 이름만 봤다" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w" >&2; done
    echo "제안한 이름으로 고쳐 다시 써라. 규칙: $RULES" >&2
    exit 2
  fi
  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    body="TypeScript 네이밍 경고 ($LABEL) — 막지 않았다. 이 프로젝트의 기존 관례와 맞는지 보고 필요하면 고쳐라."
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
  done < <(find "$root" \( -name .git -o -name node_modules -o -name dist -o -name build -o -name out -o -name coverage \
                          -o -name .next -o -name generated -o -path "$root/.claude/worktrees" \) -prune -o -type f \
                          \( -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \) -print 2>/dev/null | sort)
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
