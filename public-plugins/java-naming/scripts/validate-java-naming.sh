#!/usr/bin/env bash
# Java 코드의 이름이 Java 컨벤션(Google Java Style · Oracle Code Conventions)을 지키는지 검증한다.
# 단어 선택 · 줄임말 · 뜻은 보지 않는다 — java-name-create 스킬이 판단한다.
#
# 훅 모드 : stdin 으로 훅 JSON 을 받는다.
#   PreToolUse(Write|Edit) → *.java 의 편집 뒤 내용을 편집 전 내용과 비교해 **새로 생긴 위반만** 막는다.
#                            경고만 있으면 additionalContext 로 알린다.
# CLI 모드 :
#   validate-java-naming.sh <파일|디렉터리> ...
#   validate-java-naming.sh --all [루트]
#
# 종료 코드: 0 통과(경고만 있어도) / 2 위반 / 1 실행 오류
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RULES="$PLUGIN_ROOT/references/java-naming-rules.md"
LABEL="java-naming"

die() { echo "validate-java-naming: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/java-naming.XXXXXX")" || die "임시 디렉터리를 만들 수 없습니다"
trap 'rm -rf "$TMP"' EXIT

ERRORS=()
WARNINGS=()

# ---- 대상 -----------------------------------------------------------------
# 검사할 파일인가. 빌드 산출물 · 의존성 · 생성 코드는 보지 않는다.
is_target() { # $1=경로
  case "$1" in
    *.java) ;;
    *) return 1 ;;
  esac
  case "/$1" in
    */node_modules/*|*/build/*|*/target/*|*/out/*|*/.gradle/*|*/generated/*|*/generated-sources/*|*/vendor/*|*/.git/*) return 1 ;;
  esac
  case "$(basename "$1")" in
    package-info.java|module-info.java) return 1 ;;
  esac
  return 0
}

# ---- 언어 규칙 --------------------------------------------------------------
# $1=내용 파일 $2=원래 파일명(basename) → "E|W \037 조항 \037 줄 \037 메시지" 줄들
scan() {
  awk -v fname="$2" '
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
      return toupper(out)
    }
    function emit(kind, code, msg) { printf "%s\037%s\037%d\037%s\n", kind, code, NR, msg }
    # "타입 이름(" · "타입 이름 =" 에서 이름
    function last_ident(s) { sub(/[ \t]*[(=;]$/, "", s); sub(/^.*[^A-Za-z0-9_$]/, "", s); return s }

    BEGIN { incomment = 0; toptype = "" }
    {
      line = $0
      # 문자열 · 문자 리터럴을 비운다 (그 안의 "class" 나 "/*" 를 코드로 읽지 않게)
      gsub(/"([^"\\]|\\.)*"/, "\"\"", line)
      gsub(/\047([^\047\\]|\\.)*\047/, "\047\047", line)
      # 블록 주석
      out = ""
      while (1) {
        if (incomment) {
          i = index(line, "*/"); if (i == 0) { line = ""; break }
          line = substr(line, i + 2); incomment = 0
        }
        i = index(line, "/*"); if (i == 0) break
        out = out substr(line, 1, i - 1); line = substr(line, i + 2); incomment = 1
      }
      line = out line
      sub(/\/\/.*$/, "", line)
      if (line ~ /^[ \t]*$/) next

      # JN-01 패키지
      if (line ~ /^[ \t]*package[ \t]+[A-Za-z0-9_.]+[ \t]*;/) {
        p = line; sub(/^[ \t]*package[ \t]+/, "", p); sub(/[ \t]*;.*$/, "", p)
        if (p ~ /[A-Z]/)  emit("E", "JN-01", "패키지 \047" p "\047 는 전부 소문자여야 한다 → \047" tolower(p) "\047")
        else if (p ~ /_/) emit("W", "JN-01", "패키지 \047" p "\047 에 밑줄이 있다 — 단어를 밑줄 없이 이어 붙인다")
      }

      # JN-02 타입 이름 · JN-06 약어
      rest = " " line
      while (match(rest, /[^A-Za-z0-9_$.@](class|interface|enum|record)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/) || match(rest, /@interface[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        n = m; sub(/^.*[ \t]/, "", n)
        if (n !~ /^[A-Z][A-Za-z0-9]*$/)      emit("E", "JN-02", "타입 이름 \047" n "\047 는 UpperCamelCase 여야 한다 → \047" upper_camel(n) "\047")
        else if (n ~ /[A-Z][A-Z][A-Z][A-Z]/) emit("W", "JN-06", "타입 이름 \047" n "\047 — 약어도 한 단어처럼 쓴다 (HTTPClient → HttpClient)")
      }

      # JN-03 파일의 public 최상위 타입 — 들여쓰기 없이 시작하는 public 선언
      if (toptype == "" && line ~ /^public[ \t]+((abstract|final|sealed|non-sealed|strictfp|static)[ \t]+)*(class|interface|enum|record|@interface)[ \t]+[A-Za-z_$]/) {
        t = line; sub(/^[^(]*(class|interface|enum|record)[ \t]+/, "", t); sub(/[^A-Za-z0-9_$].*$/, "", t)
        toptype = t; topline = NR
      }

      # 멤버 선언 — 접근 제어자로 시작하는 것만 본다 (지역 변수 · 매개변수는 보지 않는다)
      decl = line; sub(/^[ \t]*(@[A-Za-z_][A-Za-z0-9_.]*(\([^()]*\))?[ \t]+)*/, "", decl)
      if (decl ~ /^(public|protected|private)[ \t]/) {
        isstatic = (decl ~ /(^|[ \t])static[ \t]/); isfinal = (decl ~ /(^|[ \t])final[ \t]/)
        mods = decl
        sub(/^((public|protected|private|static|final|abstract|synchronized|native|default|transient|volatile|strictfp)[ \t]+)*/, "", mods)
        # 타입 매개변수 — 한 단계 중첩까지 (<T extends Comparable<T>>). 탐욕적으로 반환 타입까지 먹지 않게
        sub(/^<[^<>]*(<[^<>]*>[^<>]*)*>[ \t]+/, "", mods)
        # mods = "타입 이름 (…" — 생성자는 타입이 없어 맞지 않는다
        if (match(mods, /^[A-Za-z_$][A-Za-z0-9_$.]*(<[^()=;]*>)?(\[\])*[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*[(=;]/)) {
          head = substr(mods, 1, RLENGTH); last = substr(head, length(head), 1)
          type = head; sub(/[ \t<\[].*$/, "", type)
          n = last_ident(head)
          if (type ~ /^(class|interface|enum|record|return|new|throw)$/) { }
          else if (last == "(") {
            # JN-05 메서드 — 테스트 메서드의 밑줄(given_when_then)은 허용한다
            if (n !~ /^[a-z][A-Za-z0-9_]*$/) emit("E", "JN-05", "메서드 이름 \047" n "\047 는 lowerCamelCase 여야 한다 → \047" lower_camel(n) "\047")
          } else if (isstatic && isfinal) {
            # JN-04 상수 — 원시 타입 · String 만 판정한다. 그 밖의 static final 은 상수인지 기계가 모른다
            if (type ~ /^(byte|short|int|long|float|double|char|boolean|String)$/ && n != "serialVersionUID" && n !~ /^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$/)
              emit("E", "JN-04", "상수 \047" n "\047 는 UPPER_SNAKE_CASE 여야 한다 → \047" upper_snake(n) "\047")
          } else {
            # JN-05 필드
            if (n !~ /^[a-z][A-Za-z0-9]*$/) emit("E", "JN-05", "필드 이름 \047" n "\047 는 lowerCamelCase 여야 한다 → \047" lower_camel(n) "\047")
          }
        }
      }
    }
    END {
      base = fname; sub(/\.java$/, "", base)
      if (toptype != "" && base != "" && base != toptype)
        printf "E\037JN-03\037%d\037public 타입 \047%s\047 는 %s.java 에 있어야 한다 (지금 %s)\n", topline, toptype, toptype, fname
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
    echo "❌ Java 네이밍 규칙 위반 ($LABEL)" >&2
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
    echo "❌ Java 네이밍 규칙 위반 ($LABEL) — 이 편집이 새로 만든 이름만 봤다" >&2
    for e in "${ERRORS[@]}"; do echo "  - $e" >&2; done
    for w in ${WARNINGS+"${WARNINGS[@]}"}; do echo "  ⚠️ $w" >&2; done
    echo "제안한 이름으로 고쳐 다시 써라. 규칙: $RULES" >&2
    exit 2
  fi
  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    body="Java 네이밍 경고 ($LABEL) — 막지 않았다. 이 프로젝트의 기존 관례와 맞는지 보고 필요하면 고쳐라."
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
  done < <(find "$root" \( -name .git -o -name node_modules -o -name build -o -name target -o -name .gradle \
                          -o -path "$root/.claude/worktrees" \) -prune -o -type f -name '*.java' -print 2>/dev/null | sort)
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
