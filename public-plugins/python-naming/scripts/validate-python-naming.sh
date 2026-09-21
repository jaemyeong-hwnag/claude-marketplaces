#!/usr/bin/env bash
# Python 코드의 이름이 PEP 8 Naming Conventions 와 pep8-naming(N8xx)을 지키는지 검증한다.
# 단어 선택 · 줄임말 · 뜻은 보지 않는다 — python-name-create 스킬이 판단한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit) → *.py 의 편집 뒤 내용을 편집 전 내용과 비교해 **새로 생긴 위반만** 막는다.
#                            경고만 있으면 additionalContext 로 알린다.
# CLI 모드 :
#   validate-python-naming.sh <파일|디렉터리> ...
#   validate-python-naming.sh --all [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/python-naming-rules.md"
LABEL="python-naming"

die() { echo "validate-python-naming: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/python-naming.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

ERRORS=()
WARNINGS=()

# ---- 대상 -----------------------------------------------------------------
# 검사할 파일인가. 가상환경 · 빌드 산출물 · 의존성 · 생성 코드(마이그레이션)는 보지 않는다.
is_target() { # $1=경로
  case "$1" in
    *.py) ;;
    *) return 1 ;;
  esac
  case "/$1" in
    */venv/*|*/.venv/*|*/site-packages/*|*/__pycache__/*|*/build/*|*/dist/*|*/.tox/*|*/.eggs/*|*/node_modules/*|*/.git/*|*/migrations/*|*/alembic/versions/*) return 1 ;;
  esac
  return 0
}

# ---- 언어 규칙 --------------------------------------------------------------
# $1=내용 파일 $2=원래 파일명(basename) → "E|W \037 조항 \037 줄 \037 메시지" 줄들
scan() {
  awk -v fname="$2" '
    # 앞 밑줄은 그대로 두고 나머지를 바꾼다
    function lead_of(s,   l) { l = s; sub(/[^_].*$/, "", l); return l }
    function snake(s,   l, out, i, n, c, p, nx) {
      l = lead_of(s); s = substr(s, length(l) + 1); gsub(/-/, "_", s)
      out = ""; n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); p = substr(s, i - 1, 1); nx = substr(s, i + 1, 1)
        if (i > 1 && c ~ /[A-Z]/ && (p ~ /[a-z0-9]/ || (p ~ /[A-Z]/ && nx ~ /[a-z]/))) out = out "_"
        out = out c
      }
      out = tolower(out); gsub(/__+/, "_", out)
      return l out
    }
    function cap_words(s,   l, n, i, out, parts) {
      l = lead_of(s); s = substr(s, length(l) + 1)
      if (s ~ /[_-]/) {
        n = split(tolower(s), parts, /[_-]/); out = ""
        for (i = 1; i <= n; i++) if (parts[i] != "") out = out toupper(substr(parts[i], 1, 1)) substr(parts[i], 2)
        return l out
      }
      return l toupper(substr(s, 1, 1)) substr(s, 2)
    }
    # 첫 글자가 소문자인데 대문자가 섞였다 — userName
    function mixed(s) { return s ~ /^_*[a-z][A-Za-z0-9_]*[A-Z]/ }
    function emit(kind, code, ln, msg) { if (!skip[ln]) printf "%s\037%s\037%d\037%s\n", kind, code, ln, msg }

    # 문자열 · 주석을 비운다. 삼중 따옴표는 줄을 넘어가므로 tq 에 상태를 둔다. 주석은 cmt 에 남긴다
    function strip(s,   out, i, j, n, c, q) {
      out = ""; cmt = ""; n = length(s); i = 1
      while (i <= n) {
        if (tq != "") {
          j = index(substr(s, i), tq)
          if (j == 0) return out
          i = i + j + 2; tq = ""; out = out "\"\""; continue
        }
        c = substr(s, i, 1)
        if (c == "#") { cmt = substr(s, i); return out }
        if (c == "\"" || c == "\047") {
          if (substr(s, i, 3) == c c c) { tq = c c c; i += 3; continue }
          j = i + 1
          while (j <= n) { q = substr(s, j, 1); if (q == "\\") { j += 2; continue } if (q == c) break; j++ }
          out = out c c; i = j + 1; continue
        }
        out = out c; i++
      }
      return out
    }
    function depth_of(s,   t) { t = s; return gsub(/[(\[{]/, "", t) - gsub(/[)\]}]/, "", s) }

    # PY-04 — 시그니처 "(...)" 의 매개변수. 괄호 · 대괄호 안의 쉼표(기본값 · 타입)는 나누지 않는다
    function check_params(sig, ln,   i, n, c, d, cur, list, k, m, p) {
      n = length(sig); d = 0; cur = ""; m = 0
      for (i = 1; i <= n; i++) {
        c = substr(sig, i, 1)
        if (c ~ /[(\[{]/) { d++; if (d == 1) continue }
        else if (c ~ /[)\]}]/) { d--; if (d == 0) { list[++m] = cur; break } }
        if (d == 1 && c == ",") { list[++m] = cur; cur = ""; continue }
        if (d >= 1) cur = cur c
      }
      for (k = 1; k <= m; k++) {
        p = list[k]; sub(/^[ \t*]+/, "", p); sub(/[^A-Za-z0-9_].*$/, "", p)
        if (p == "" || p == "self" || p == "cls") continue
        if (p ~ /[a-z]/ && p ~ /[A-Z]/)
          emit("W", "PY-04", ln, "매개변수 \047" p "\047 는 snake_case 로 쓴다 → \047" snake(p) "\047")
      }
    }

    BEGIN {
      tq = ""; depth = 0; contd = 0; insig = 0; ovr = 0
      split("setUp tearDown setUpClass tearDownClass setUpModule tearDownModule asyncSetUp asyncTearDown setUpTestData", a, " ")
      for (k in a) allowed[a[k]] = 1
    }
    {
      startq = (tq != "")
      code = strip($0)
      # # noqa (코드 없이) · # noqa: N8xx 가 있는 줄은 건너뛴다
      if (cmt ~ /#[ \t]*[Nn][Oo][Qq][Aa]/ && (cmt !~ /[Nn][Oo][Qq][Aa][ \t]*:/ || cmt ~ /[Nn][Oo][Qq][Aa][ \t]*:.*N8/)) skip[NR] = 1
      stmt = (!startq && depth == 0 && !contd)
      depth += depth_of(code); if (depth < 0) depth = 0
      contd = (code ~ /\\[ \t]*$/)

      if (insig) {
        sigbuf = sigbuf " " code
        if (depth == 0) { check_params(sigbuf, sigline); insig = 0 }
        next
      }
      if (!stmt || code ~ /^[ \t]*$/) next

      # 데코레이터 — @override 가 붙은 def 는 부모의 이름을 따르므로 PY-03 을 보지 않는다
      if (code ~ /^[ \t]*@/) { if (code ~ /^[ \t]*@([A-Za-z_]+\.)?override([^A-Za-z0-9_]|$)/) ovr = 1; next }

      # PY-03 함수 · 메서드, PY-04 매개변수
      if (code ~ /^[ \t]*(async[ \t]+)?def[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
        n = code; sub(/^[ \t]*(async[ \t]+)?def[ \t]+/, "", n); sub(/[^A-Za-z0-9_].*$/, "", n)
        if (!ovr && n !~ /^_*[a-z][a-z0-9_]*$/ && !(n in allowed) && n !~ /^visit_[A-Za-z0-9_]+$/ && n !~ /^do_[A-Z]+$/ && n !~ /^_+$/)
          emit("E", "PY-03", NR, "함수 이름 \047" n "\047 는 snake_case 여야 한다 → \047" snake(n) "\047")
        ovr = 0
        i = index(code, "(")
        if (i > 0) {
          sigbuf = substr(code, i); sigline = NR
          if (depth == 0) check_params(sigbuf, sigline); else insig = 1
        }
        next
      }
      ovr = 0

      # PY-02 클래스, PY-06 예외 클래스
      if (code ~ /^[ \t]*class[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
        n = code; sub(/^[ \t]*class[ \t]+/, "", n); sub(/[^A-Za-z0-9_].*$/, "", n)
        if (n !~ /^_*[A-Z][A-Za-z0-9]*$/) {
          emit("E", "PY-02", NR, "클래스 이름 \047" n "\047 는 CapWords 여야 한다 → \047" cap_words(n) "\047")
          next
        }
        b = code; sub(/^[^(:]*/, "", b)
        if (b ~ /^\(/ && n !~ /Error$/) {
          sub(/^\(/, "", b); sub(/\).*$/, "", b); nb = split(b, bases, ",")
          for (k = 1; k <= nb; k++) {
            t = bases[k]; gsub(/[ \t]/, "", t)
            if (t ~ /=/) continue
            sub(/\[.*$/, "", t); sub(/^.*\./, "", t)
            if (t ~ /(Exception|Error)$/) {
              s = n; sub(/Exception$/, "", s)
              emit("W", "PY-06", NR, "예외 클래스 \047" n "\047 는 Error 로 끝낸다 → \047" s "Error\047")
              break
            }
          }
        }
        next
      }

      # PY-05 대입 대상 — a = … · a: T = … · a, b = … · self.a = … · a: T
      if (code ~ /^[ \t]*[A-Za-z_*][A-Za-z0-9_.]*([ \t]*,[ \t]*[A-Za-z_*][A-Za-z0-9_.]*)*[ \t]*(:[^=]*)?=([^=]|$)/ || code ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_.]*[ \t]*:[ \t]*[A-Za-z_]/) {
        tg = code; sub(/^[ \t]*/, "", tg); sub(/[ \t]*[:=].*$/, "", tg)
        nt = split(tg, tgs, ",")
        for (k = 1; k <= nt; k++) {
          t = tgs[k]; gsub(/[ \t*]/, "", t)
          # 속성은 self. · cls. 만 — 다른 객체의 속성 이름은 여기서 정하지 않는다
          if (t ~ /\./) { if (t ~ /^(self|cls)\.[A-Za-z_][A-Za-z0-9_]*$/) sub(/^[a-z]+\./, "", t); else continue }
          if (mixed(t)) emit("W", "PY-05", NR, "변수 이름 \047" t "\047 는 snake_case 로 쓴다 → \047" snake(t) "\047")
        }
      }
    }
    END {
      # PY-01 모듈 파일 이름 — 내용이 있을 때만 (새 파일의 "편집 전" 빈 내용에서 나오면 비교에서 지워진다)
      if (NR > 0 && fname !~ /^[a-z_][a-z0-9_]*\.py$/) {
        base = fname; sub(/\.py$/, "", base)
        printf "E\037PY-01\0371\037모듈 파일 이름 \047%s\047 는 소문자 snake_case 여야 한다 (하이픈 · 대문자는 import 할 수 없거나 관례 위반) → \047%s.py\047\n", fname, snake(base)
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
    echo "❌ Python 네이밍 규칙 위반 ($LABEL)" >&2
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
    echo "❌ Python 네이밍 규칙 위반 ($LABEL) — 이 편집이 새로 만든 이름만 봤다" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w" >&2; done
    echo "제안한 이름으로 고쳐 다시 써라. 규칙: $RULES" >&2
    exit 2
  fi
  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    body="Python 네이밍 경고 ($LABEL) — 막지 않았다. 이 프로젝트의 기존 관례와 맞는지 보고 필요하면 고쳐라."
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
  done < <(find "$root" \( -name .git -o -name node_modules -o -name venv -o -name .venv -o -name site-packages -o -name __pycache__ \
                          -o -name build -o -name dist -o -name .tox -o -name .eggs -o -name migrations \
                          -o -path "$root/.claude/worktrees" \) -prune -o -type f -name '*.py' -print 2>/dev/null | sort)
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
