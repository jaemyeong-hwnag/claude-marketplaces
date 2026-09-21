#!/usr/bin/env bash
# Node.js 프로젝트의 이름이 npm 규칙과 JavaScript 관례(Airbnb Style Guide)를 지키는지 검증한다.
# 단어 선택 · 줄임말 · 뜻은 보지 않는다 — node-name-create 스킬이 판단한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit) → JS · package.json(과 TS 의 환경 변수)의 편집 뒤 내용을 편집 전 내용과 비교해
#                            **새로 생긴 위반만** 막는다. 경고만 있으면 additionalContext 로 알린다.
# CLI 모드 :
#   validate-node-naming.sh <파일|디렉터리> ...
#   validate-node-naming.sh --all [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/node-naming-rules.md"
LABEL="node-naming"

die() { echo "validate-node-naming: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/node-naming.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

ERRORS=()
WARNINGS=()

# ---- 대상 -----------------------------------------------------------------
# 검사할 파일인가. 빌드 산출물 · 의존성 · 생성 코드는 보지 않는다.
# TS 계열은 환경 변수(ND-03)만 본다 — 식별자는 typescript-naming 이 본다.
is_target() { # $1=경로
  case "$(basename "$1")" in
    *.min.js) return 1 ;;
    package.json|*.js|*.mjs|*.cjs|*.jsx|*.ts|*.tsx|*.mts|*.cts) ;;
    *) return 1 ;;
  esac
  case "/$1" in
    */node_modules/*|*/dist/*|*/build/*|*/out/*|*/coverage/*|*/.next/*|*/generated/*|*/vendor/*|*/.git/*) return 1 ;;
  esac
  return 0
}

# ---- 언어 규칙 --------------------------------------------------------------
# 출력 형식: "E|W \037 조항 \037 줄 \037 메시지" 줄들
scan() { # $1=내용 파일 $2=원래 파일명(basename)
  case "$2" in
    package.json) scan_package "$1" ;;
    *.ts|*.tsx|*.mts|*.cts) scan_source "$1" "$2" ts ;;
    *) scan_source "$1" "$2" js ;;
  esac
}

# 이름 변환 — scan_package · scan_source 가 같이 쓴다
AWK_NAMES='
  function upper_camel(s,   n, i, out, parts) {
    if (s ~ /_/) {
      n = split(tolower(s), parts, "_"); out = ""
      for (i = 1; i <= n; i++) if (parts[i] != "") out = out toupper(substr(parts[i], 1, 1)) substr(parts[i], 2)
      return out
    }
    return toupper(substr(s, 1, 1)) substr(s, 2)
  }
  function lower_camel(s,   u) { u = upper_camel(s); return tolower(substr(u, 1, 1)) substr(u, 2) }
  function upper_snake(s,   out, i, c, prev) {
    out = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1); prev = substr(s, i - 1, 1)
      if (i > 1 && c ~ /[A-Z]/ && prev ~ /[a-z0-9]/) out = out "_"
      out = out c
    }
    gsub(/[^A-Za-z0-9_]/, "_", out)
    return toupper(out)
  }
  # 소문자 단어를 - 로 잇는다. keep 에 든 문자는 구분자로 남긴다 (예: ":" · ".")
  function kebab(s, keep,   out, i, c, prev) {
    out = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1); prev = substr(s, i - 1, 1)
      if (i > 1 && c ~ /[A-Z]/ && prev ~ /[a-z0-9]/) out = out "-"
      if (c ~ /[A-Za-z0-9]/ || (keep != "" && index(keep, c) > 0)) out = out c; else out = out "-"
    }
    out = tolower(out)
    gsub(/-+/, "-", out)
    while (out ~ /^[-._]/) out = substr(out, 2)
    sub(/-+$/, "", out)
    return out
  }
  function emit_at(kind, code, ln, msg) { printf "%s\037%s\037%d\037%s\n", kind, code, ln, msg }
'

# package.json — ND-01 name · ND-02 scripts 키. JSON 이 깨져 있으면 판정하지 않는다
scan_package() { # $1=내용 파일
  jq -e 'type == "object"' "$1" >/dev/null 2>&1 || return 0
  jq -j '
    (if (.name | type) == "string" then "N\u001f" + (.name | gsub("\n"; " ")) + "\n" else "" end),
    (if (.scripts | type) == "object" then (.scripts | keys_unsorted[] | "S\u001f" + gsub("\n"; " ") + "\n") else "" end)
  ' "$1" > "$TMP/pkg-values"
  awk "$AWK_NAMES"'
    # 1. jq 가 뽑은 값
    FILENAME == ARGV[1] {
      split($0, f, "\037")
      if (f[1] == "N") { hasname = 1; name = substr($0, 3) }
      else if (f[1] == "S") { nkeys++; keys[nkeys] = substr($0, 3) }
      next
    }
    # 2. 원문에서 줄 번호 — 문자열 밖의 괄호로 깊이를 센다
    {
      line = $0; i = 1
      while (i <= length(line)) {
        c = substr(line, i, 1)
        if (c == "\"") {
          j = i + 1; tok = ""
          while (j <= length(line)) {
            d = substr(line, j, 1)
            if (d == "\\") { tok = tok substr(line, j, 2); j += 2; continue }
            if (d == "\"") break
            tok = tok d; j++
          }
          rest = substr(line, j + 1)
          if (rest ~ /^[ \t]*:/) {
            if (depth == 1) { top = tok; if (tok == "name" && !nameline) nameline = FNR }
            else if (depth == 2 && top == "scripts" && !(tok in keyline)) keyline[tok] = FNR
          }
          i = j + 1; continue
        }
        if (c == "{" || c == "[") depth++
        else if (c == "}" || c == "]") depth--
        i++
      }
    }
    END {
      # ND-01 — npm 의 패키지 이름 규칙 (validate-npm-package-name 과 같다)
      if (hasname) {
        why = ""; n = name
        if (n == "") why = "비어 있다"
        else {
          if (length(n) > 214)               why = why ", 214자를 넘는다"
          if (n ~ /^[._]/)                   why = why ", . 이나 _ 로 시작한다"
          if (n ~ /[A-Z]/)                   why = why ", 대문자가 있다"
          if (n ~ /^[ \t]|[ \t]$/)           why = why ", 앞뒤에 공백이 있다"
          if (n == "node_modules" || n == "favicon.ico") why = why ", 쓸 수 없는 이름이다"
          scope = ""; pkg = n
          if (n ~ /^@/) {
            if (n ~ /^@[^\/]+\/[^\/]+$/) { scope = substr(n, 2, index(n, "/") - 2); pkg = substr(n, index(n, "/") + 1) }
            else { why = why ", 스코프는 @scope/name 이어야 한다"; pkg = substr(n, 2); gsub(/\//, "-", pkg) }
          }
          if ((scope != "" && tolower(scope) !~ /^[a-z0-9._-]+$/) || tolower(pkg) !~ /^[a-z0-9._-]+$/)
            why = why ", URL 에 그대로 쓸 수 없는 문자가 있다 (소문자 · 숫자 · - . _ 만)"
          sub(/^, /, "", why)
        }
        if (why != "") {
          sug = kebab(pkg, "._"); gsub(/_/, "-", sug); gsub(/-+/, "-", sug)
          if (scope != "") { s = kebab(scope, "._"); sug = "@" s "/" sug }
          sug = substr(sug, 1, 214)
          emit_at("E", "ND-01", nameline ? nameline : 1, "package.json 의 name \047" n "\047 는 npm 규칙에 맞지 않는다 — " why (sug != "" ? " → \047" sug "\047" : ""))
        }
      }
      # ND-02 — scripts 키
      for (k = 1; k <= nkeys; k++) {
        key = keys[k]
        if (key ~ /^[a-z0-9]+([-:][a-z0-9]+)*$/ || key == "prepublishOnly") continue
        m = split(key, seg, ":"); sug = ""
        for (x = 1; x <= m; x++) sug = sug (x > 1 ? ":" : "") kebab(seg[x], "")
        emit_at("W", "ND-02", (key in keyline) ? keyline[key] : 1, "npm script \047" key "\047 — 소문자 · 숫자를 - 와 : 로 잇는다 → \047" sug "\047")
      }
    }
  ' "$TMP/pkg-values" "$1"
}

# JS · TS 소스 — ND-03 환경 변수, (js 만) ND-04 클래스 · ND-05 변수 · 함수 · ND-06 파일 이름
scan_source() { # $1=내용 파일 $2=파일명 $3=js|ts
  awk -v fname="$2" -v mode="$3" "$AWK_NAMES"'
    function emit(kind, code, msg) { emit_at(kind, code, NR, msg) }
    function ident_of(m,   n) { n = m; sub(/^.*[^A-Za-z0-9_$]/, "", n); return n }

    # 한 줄의 코드만 남긴다 — 주석을 지우고 문자열 · 템플릿 문자열의 글자를 비운다 (${…} 안은 코드로 남긴다).
    # 상태(블록 주석 · 템플릿 깊이)는 줄을 넘어 이어진다
    function sanitize(s,   out, i, c, nx, n, inclass) {
      out = ""; i = 1; n = length(s)
      while (i <= n) {
        c = substr(s, i, 1); nx = substr(s, i + 1, 1)
        if (st == "block") {
          if (c == "*" && nx == "/") { st = "code"; i += 2; out = out " " } else i++
          continue
        }
        if (st == "tpl") {
          if (c == "\\") { i += 2; continue }
          if (c == "`") { tdepth--; st = "code"; out = out "`"; prev = "a"; i++; continue }
          if (c == "$" && nx == "{") { st = "code"; brace[tdepth] = 0; out = out " "; i += 2; prev = "("; continue }
          i++; continue
        }
        # code
        if (c == "/" && nx == "/") break
        if (c == "/" && nx == "*") { st = "block"; i += 2; continue }
        if (c == "\"" || c == "\047") {
          i++
          while (i <= n) { d = substr(s, i, 1); if (d == "\\") { i += 2; continue } if (d == c) break; i++ }
          out = out c c; prev = "a"; i++; continue
        }
        if (c == "`") { tdepth++; st = "tpl"; out = out "`"; i++; continue }
        if (c == "/" && (prev == "" || index("(,=:[!&|?{};+-*%<>~^", prev) > 0 || prevword ~ /^(return|typeof|case|do|else|in|of|new|delete|void|throw|yield|await)$/)) {
          # 정규식 리터럴 — 문자 클래스 안의 / 는 끝이 아니다
          i++; inclass = 0
          while (i <= n) {
            d = substr(s, i, 1)
            if (d == "\\") { i += 2; continue }
            if (d == "[") inclass = 1; else if (d == "]") inclass = 0
            else if (d == "/" && !inclass) break
            i++
          }
          out = out "0"; prev = "a"; i++; continue
        }
        if (c == "{" && tdepth > 0) brace[tdepth]++
        if (c == "}" && tdepth > 0) {
          if (brace[tdepth] == 0) { st = "tpl"; out = out " "; i++; continue }
          brace[tdepth]--
        }
        out = out c
        if (c ~ /[A-Za-z0-9_$]/) { if (prev ~ /[A-Za-z0-9_$]/) prevword = prevword c; else prevword = c; prev = c }
        else if (c !~ /[ \t]/) { prev = c; prevword = "" }
        i++
      }
      return out
    }

    # process.env["NAME"] · process.env[\047NAME\047] 을 문자열을 비우기 전에 표시해 둔다 — process.env[#NAME#]
    function mark_env(s,   out, m, q, nm) {
      out = ""
      while (match(s, /process\.env[ \t]*\[[ \t]*("[^"\\#]*"|\047[^\047\\#]*\047)[ \t]*\]/)) {
        m = substr(s, RSTART, RLENGTH)
        nm = m; sub(/^[^\[]*\[[ \t]*./, "", nm); sub(/.[ \t]*\]$/, "", nm)
        out = out substr(s, 1, RSTART - 1) "process.env[#" nm "#]"
        s = substr(s, RSTART + RLENGTH)
      }
      return out s
    }

    function check_env(n) {
      if (n !~ /[a-z]/) return
      if (n ~ /^npm_/ || n ~ /^(http_proxy|https_proxy|no_proxy|all_proxy)$/) return
      emit("E", "ND-03", "환경 변수 \047" n "\047 는 UPPER_SNAKE_CASE 여야 한다 → \047" upper_snake(n) "\047")
    }

    # 소문자가 섞인 snake_case 인가 — 앞뒤 밑줄(_private, __dirname)은 뺀다
    function snake_mixed(n,   core) {
      core = n; sub(/^[_$]+/, "", core); sub(/_+$/, "", core)
      return (core ~ /_/ && core ~ /[a-z]/)
    }
    function camel_suggest(n,   lead, core) {
      lead = n; sub(/[^_$].*$/, "", lead)
      core = substr(n, length(lead) + 1); sub(/_+$/, "", core)
      return lead lower_camel(core)
    }

    BEGIN { st = "code"; tdepth = 0; prev = ""; prevword = "" }
    {
      raw = $0
      if (NR == 1 && raw ~ /^#!/) next
      line = sanitize(mark_env(raw))
      if (line ~ /^[ \t]*$/) next

      # ND-03 환경 변수
      rest = line
      while (match(rest, /process\.env(\?)?\.[A-Za-z_$][A-Za-z0-9_$]*[ \t]*\(?/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        if (m ~ /\($/) continue                     # process.env.hasOwnProperty(…) — 메서드 호출
        n = m; sub(/[ \t]*$/, "", n); n = ident_of(n)
        check_env(n)
      }
      rest = line
      while (match(rest, /process\.env\[#[^#]*#\]/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        n = m; sub(/^process\.env\[#/, "", n); sub(/#\]$/, "", n)
        check_env(n)
      }
      if (mode != "js") next

      # ND-04 클래스
      rest = " " line
      while (match(rest, /[^A-Za-z0-9_$.]class[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        n = ident_of(m)
        if (n == "extends" || n == "implements") continue
        if (n !~ /^[A-Z][A-Za-z0-9]*$/) emit("E", "ND-04", "클래스 이름 \047" n "\047 는 PascalCase 여야 한다 → \047" upper_camel(n) "\047")
      }

      # ND-05 변수 · 함수 — 구조 분해({ a_b } · [a_b])는 보지 않는다
      rest = " " line
      while (match(rest, /[^A-Za-z0-9_$.](let|const|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/) || match(rest, /[^A-Za-z0-9_$.]function([ \t]+|[ \t]*\*[ \t]*)[A-Za-z_$][A-Za-z0-9_$]*/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        n = ident_of(m)
        kind = (m ~ /function/) ? "함수" : "변수"
        if (snake_mixed(n)) emit("E", "ND-05", kind " 이름 \047" n "\047 는 camelCase 여야 한다 (상수면 UPPER_SNAKE_CASE) → \047" camel_suggest(n) "\047")
      }
    }
    END {
      # 빈 내용(훅의 편집 전 새 파일)은 파일 이름을 보지 않는다 — 편집 뒤와 비교해 새 경고로 잡히게
      if (mode != "js" || NR == 0) exit
      # ND-06 파일 이름 — 점으로 나눈 조각마다 kebab-case, 첫 조각은 default export 이름을 따른 camelCase · PascalCase 도 허용
      # (useQuery.js · Button.js). 앞 점(.eslintrc.js) · 앞 밑줄(_app.js) · [id].js 허용. 밑줄 · 섞인 구분자만 경고한다
      base = fname; ext = base; sub(/\.[^.]*$/, "", base); sub(/^.*\./, "", ext)
      b = base; sub(/^\./, "", b); sub(/^_+/, "", b); gsub(/\[\[?(\.\.\.)?[A-Za-z0-9_-]+\]?\]/, "x", b)
      if (b == "") exit
      bad = 0; m = split(b, seg, ".")
      for (x = 1; x <= m; x++) {
        if (seg[x] ~ /^[a-z0-9]+(-[a-z0-9]+)*$/) continue
        if (x == 1 && seg[x] ~ /^[A-Za-z][A-Za-z0-9]*$/) continue
        bad = 1
      }
      if (base ~ /^(Gruntfile|Gulpfile|Jakefile)$/) bad = 0
      if (bad) {
        sug = kebab(base, "."); if (base ~ /^\./) sug = "." sug
        emit_at("W", "ND-06", 1, "파일 이름 \047" fname "\047 — kebab-case 로 쓴다 → \047" sug "." ext "\047")
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
    echo "❌ Node.js 네이밍 규칙 위반 ($LABEL)" >&2
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
    echo "❌ Node.js 네이밍 규칙 위반 ($LABEL) — 이 편집이 새로 만든 이름만 봤다" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w" >&2; done
    echo "제안한 이름으로 고쳐 다시 써라. 규칙: $RULES" >&2
    exit 2
  fi
  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    body="Node.js 네이밍 경고 ($LABEL) — 막지 않았다. 이 프로젝트의 기존 관례와 맞는지 보고 필요하면 고쳐라."
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
                          -o -name .next -o -name generated -o -name vendor -o -path "$root/.claude/worktrees" \) -prune -o -type f \
                       \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \
                          -o -name '*.mts' -o -name '*.cts' -o -name package.json \) -print 2>/dev/null | sort)
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
