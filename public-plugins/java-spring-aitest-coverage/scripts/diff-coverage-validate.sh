#!/usr/bin/env bash
# git 로컬 diff(HEAD 대비 tracked + untracked) 기준 @AiTest 검증.
#   변경 Controller 의 *AiTest* 존재 → aiTest 실행 → 수정 메서드 JaCoCo 100%.
# deps: git, awk, jq(설정 파일이 있을 때), bash 3.2+
#
# Usage: diff-coverage-validate.sh [--check-only | --report-only] [git-ref]
#   --check-only  : 변경 Controller 의 *AiTest* 존재만 본다 (aiTest · JaCoCo 미실행)
#   --report-only : aiTest 를 돌리지 않고 기존 JaCoCo 리포트로 판정한다.
#                   리포트가 없거나 로컬 diff 파일보다 오래되면 FAIL (Stop 게이트용)
#
# 대상 모듈 = 설정 .modules → 루트 build.gradle 의 aiTestModules → 단일 모듈(".") 순.
# 라이브러리 모듈 → 소비 모듈 = 설정 .libraryModules. 설정: .claude/java-spring-aitest-coverage.json
#
# 종료 코드: 0 통과 · 1 미충족 · 2 실행 오류
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

CHECK_ONLY=false
REPORT_ONLY=false
BASE="HEAD"
while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=true; shift ;;
    --report-only) REPORT_ONLY=true; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) BASE="$1"; shift ;;
  esac
done

NAME="diff-coverage-validate"
CONFIG="$ROOT/.claude/java-spring-aitest-coverage.json"
REPORT_REL="build/reports/jacoco/aiTestCoverageReport/aiTestCoverageReport.xml"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "$NAME: not a git repo" >&2
  exit 2
fi

cfg() { # $1=jq 식 → 값 (설정 파일이 없으면 빈 값)
  [ -f "$CONFIG" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    echo "$NAME: $CONFIG 를 읽으려면 jq 가 필요합니다" >&2
    exit 2
  fi
  jq -r "$1" "$CONFIG" 2>/dev/null || { echo "$NAME: $CONFIG 파싱 실패" >&2; exit 2; }
}

# --- 변경 파일 ----------------------------------------------------------------
tmp="$(mktemp -d "${TMPDIR:-/tmp}/aitest-diff.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
changed_file="$tmp/changed"
entries_file="$tmp/entries"
modules_file="$tmp/modules"

{
  git diff "$BASE" --name-only 2>/dev/null || { echo "$NAME: git diff $BASE 실패" >&2; exit 2; }
  git ls-files --others --exclude-standard 2>/dev/null
} | awk 'NF && !seen[$0]++' > "$changed_file"

if [ ! -s "$changed_file" ]; then
  echo "$NAME: no diff vs $BASE — OK"
  exit 0
fi

TRIGGER_RE='(^|/)src/main/java/.*\.java$|(^|/)src/main/resources/.*[Mm]apper.*\.xml$|(^|/)src/test/java/.*AiTest.*\.java$'
if ! grep -qE "$TRIGGER_RE" "$changed_file"; then
  echo "$NAME: no main Java/mapper/AiTest diff — OK"
  exit 0
fi

# --- 모듈 -----------------------------------------------------------------------
# 모듈 = Gradle 프로젝트 경로(콜론 구분, 앞 콜론 없음). 디렉터리 = 콜론을 / 로. 루트 단일 모듈은 "."
MODULES="$(cfg '.modules // [] | .[]' | xargs)"
if [ -z "$MODULES" ] && [ -f build.gradle ]; then
  MODULES="$(sed -nE "s/.*aiTestModules[[:space:]]*=[[:space:]]*\[([^]]*)\].*/\1/p" build.gradle | head -1 | tr -d "'\"" | tr ',' ' ' | xargs)"
fi
[ -n "$MODULES" ] || MODULES="."
LIBRARIES="$(cfg '.libraryModules // {} | to_entries[] | "\(.key)=\(.value | join(","))"' | xargs)"

mod_dir() { if [ "$1" = "." ]; then echo ""; else echo "${1//://}/"; fi; }
mod_task() { if [ "$1" = "." ]; then echo "$2"; else echo ":$1:$2"; fi; }

# 출력: 소비 모듈|FQN|클래스|kind|소스 경로   (kind = controller · service · other · library)
awk -v mods="$MODULES" -v libs="$LIBRARIES" '
function dir_of(m) { if (m == ".") return ""; gsub(/:/, "/", m); return m "/" }
function owner(f, list, n,    i, d, best, bl) {   # 가장 긴 디렉터리 접두가 이기는 모듈
  best = ""; bl = -1
  for (i = 1; i <= n; i++) {
    d = dir_of(list[i])
    if (index(f, d "src/main/java/") == 1 && length(d) > bl) { best = list[i]; bl = length(d) }
  }
  return best
}
function kind(s) { if (s ~ /Controller$/) return "controller"; if (s ~ /Service$/) return "service"; return "other" }
function add(m, fq, s, k, f,    key) { key = m SUBSEP fq; if (key in seen) return; seen[key] = 1; print m "|" fq "|" s "|" k "|" f }
BEGIN {
  nm = split(mods, mod, " ")
  nl = split(libs, pair, " ")
  for (i = 1; i <= nl; i++) { split(pair[i], kv, "="); lib[i] = kv[1]; consumers[i] = kv[2] }
}
/\.java$/ && /src\/main\/java\// {
  f = $0
  fq = substr(f, index(f, "src/main/java/") + 14); sub(/\.java$/, "", fq); gsub(/\//, ".", fq)
  n = split(fq, bits, "."); s = bits[n]
  m = owner(f, mod, nm)
  if (m != "") { add(m, fq, s, kind(s), f); next }
  l = owner(f, lib, nl)
  if (l == "") next
  for (i = 1; i <= nl; i++) if (lib[i] == l) { nc = split(consumers[i], c, ","); for (j = 1; j <= nc; j++) add(c[j], fq, s, "library", f) }
}
' "$changed_file" | sort -u > "$entries_file"

entry_count="$(awk 'END { print NR }' "$entries_file")"

has_aitest() { # $1=모듈 $2=클래스 이름
  local dir; dir="$(mod_dir "$1")src/test/java"
  [ -d "$dir" ] || return 1
  # 파일명이 대상으로 시작하거나(FooControllerAiTest — MockMvc 테스트는 본문에 클래스명이 없다),
  # 본문에 단어 경계로 나온다 — FooController 가 FooControllerHelper 로 오인되지 않게
  [ -n "$(find "$dir" -name "${2}*AiTest*.java" -print 2>/dev/null | head -1)" ] && return 0
  grep -rqw --include='*AiTest*.java' -- "$2" "$dir" 2>/dev/null
}

module_of_test() { # $1=테스트 파일 → 모듈 (없으면 빈 값)
  local m d best="" bl=-1
  for m in $MODULES; do
    d="$(mod_dir "$m")"
    case "$1" in "${d}src/test/java/"*) [ "${#d}" -gt "$bl" ] && { best="$m"; bl="${#d}"; } ;; esac
  done
  echo "$best"
}

if [ "$entry_count" -gt 0 ]; then
  missing=""
  while IFS='|' read -r mod fqn simple kind _src; do
    [ "$kind" = "controller" ] || continue
    has_aitest "$mod" "$simple" || missing="${missing}  $mod: $simple ($fqn) 을 다루는 *AiTest* 가 없음"$'\n'
  done < "$entries_file"
  if [ -n "$missing" ]; then
    echo "$NAME: FAIL — 변경 Controller 에 @AiTest 가 없습니다:" >&2
    printf '%s' "$missing" >&2
    echo "  → <module>/src/test/java/**/*AiTest*.java 에 @AiTest · @AiWebTest 작성" >&2
    exit 1
  fi
  cut -d'|' -f1 "$entries_file" | sort -u > "$modules_file"
else
  { grep -E '(^|/)src/test/java/.*AiTest.*\.java$' "$changed_file" || true; } | while IFS= read -r f; do
    module_of_test "$f"
  done | awk 'NF' | sort -u > "$modules_file"
fi

module_count="$(awk 'END { print NR }' "$modules_file")"
if [ "$module_count" -eq 0 ]; then
  echo "$NAME: no verifiable module diff — OK"
  exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
  echo "$NAME: check-only OK — @AiTest 존재만 확인 ($entry_count class(es), $module_count module(s))"
  echo "$NAME: aiTest · JaCoCo 는 돌지 않았다. 완료 게이트는 $0 $BASE 가 필요하다"
  exit 0
fi

# 모듈 하나의 판정에 영향을 주는 소스 디렉터리 — 자기 src/ + 설정의 라이브러리 src/main/
source_dirs_of() {
  local m="$1" p l cs
  echo "$(mod_dir "$m")src/"
  for p in $LIBRARIES; do
    l="${p%%=*}"; cs=",${p#*=},"
    case "$cs" in *",$m,"*) echo "$(mod_dir "$l")src/main/" ;; esac
  done
}

if [ "$REPORT_ONLY" = true ]; then
  # 리포트가 로컬 diff 파일보다 오래되면 그 변경은 아직 aiTest 로 측정되지 않은 것이다
  stale=""
  while IFS= read -r mod; do
    xml="$(mod_dir "$mod")$REPORT_REL"
    if [ ! -f "$xml" ]; then
      stale="${stale}  $mod: JaCoCo 리포트 없음 ($xml)"$'\n'
      continue
    fi
    dirs="$(source_dirs_of "$mod")"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      hit=0
      while IFS= read -r d; do case "$f" in "$d"*) hit=1 ;; esac; done <<< "$dirs"
      if [ "$hit" = 1 ] && [ "$f" -nt "$xml" ]; then
        stale="${stale}  $mod: $f 가 리포트보다 최신"$'\n'
        break
      fi
    done < "$changed_file"
  done < "$modules_file"
  if [ -n "$stale" ]; then
    echo "$NAME: FAIL — aiTest JaCoCo 리포트가 없거나 로컬 diff 보다 오래됨 (report-only):" >&2
    printf '%s' "$stale" >&2
    echo "  → $0 $BASE 로 aiTest 를 실행해 리포트를 갱신" >&2
    exit 1
  fi
  if [ "$entry_count" -eq 0 ]; then
    echo "$NAME: report-only PASS (AiTest-only diff, $module_count module(s))"
    exit 0
  fi
else
  # --- aiTest 실행 ------------------------------------------------------------
  java_version="$(cfg '.javaVersion // empty')"
  if [ -n "$java_version" ] && [ -x /usr/libexec/java_home ]; then
    JAVA_HOME="$(/usr/libexec/java_home -v "$java_version" 2>/dev/null || echo "${JAVA_HOME:-}")"
    export JAVA_HOME
  fi
  if [ ! -x ./gradlew ]; then
    echo "$NAME: ./gradlew 가 없습니다" >&2
    exit 2
  fi

  set -- -q
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    set -- "$@" -PskipDockerEnsure=true
  fi
  echo "$NAME: running aiTest (JaCoCo ON) for: $(paste -sd, "$modules_file")"
  while IFS= read -r mod; do
    set -- "$@" "$(mod_task "$mod" compileAiTestJava)" "$(mod_task "$mod" aiTest)"
    # main 변경(자기 모듈 · 라이브러리)이 있으면 전체, AiTest 만 바뀌었으면 그 클래스만
    if grep -q "^$mod|" "$entries_file"; then
      echo "  → $(mod_task "$mod" aiTest) (full — main Java changed)"
      continue
    fi
    d="$(mod_dir "$mod")"
    while IFS= read -r t; do
      [ "$(module_of_test "$t")" = "$mod" ] || continue
      fq="${t#*src/test/java/}"; fq="${fq%.java}"; fq="${fq//\//.}"
      set -- "$@" --tests "$fq"
      echo "  → $(mod_task "$mod" aiTest) --tests $fq"
    done < <(grep -E "^${d}src/test/java/.*AiTest.*\.java$" "$changed_file" || true)
  done < "$modules_file"
  ./gradlew "$@"

  if [ "$entry_count" -eq 0 ]; then
    echo "$NAME: PASS (AiTest-only diff, $module_count module(s))"
    exit 0
  fi
fi

# --- 수정 메서드 커버리지 -------------------------------------------------------
ok=""; skip=""; bad=""
while IFS='|' read -r mod fqn _simple _kind src; do
  xml="$(mod_dir "$mod")$REPORT_REL"
  if out="$("$SCRIPT_DIR/method-coverage-get.sh" "$BASE" "$xml" "$src" "$fqn" "$mod" 2>&1)"; then
    if printf '%s\n' "$out" | grep -q '^OK '; then ok="${ok}${out}"$'\n'; else skip="${skip}${out}"$'\n'; fi
  else
    bad="${bad}${out}"$'\n'
  fi
done < "$entries_file"

[ -z "$ok" ] || { echo "$NAME: changed method coverage OK:"; printf '%s' "$ok" | sed '/^$/d; s/^/  /'; }
[ -z "$skip" ] || { echo "$NAME: changed method coverage skipped:"; printf '%s' "$skip" | sed '/^$/d; s/^/  /'; }
if [ -n "$bad" ]; then
  echo "$NAME: FAIL — changed method JaCoCo below 100%:" >&2
  printf '%s' "$bad" | sed '/^$/d; s/^/  /' >&2
  echo "  → 수정 메서드를 100% 덮도록 @AiTest 보강 후 재실행 (최대 3회)" >&2
  echo "  → 리포트: <module>/build/reports/jacoco/aiTestCoverageReport/html/" >&2
  exit 1
fi

echo "$NAME: PASS ($entry_count class(es), $module_count module(s), changed method coverage 100%)"
exit 0
