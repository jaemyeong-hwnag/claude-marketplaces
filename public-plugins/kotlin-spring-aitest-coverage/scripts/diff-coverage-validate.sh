#!/usr/bin/env bash
# git 로컬 diff(HEAD 대비 tracked + untracked) 기준 Kotlin @AiTest 검증.
#   변경 Controller 를 다루는 aiTest 존재 → aiTest 실행 → 변경 메서드 JaCoCo 100%.
# deps: git, awk, javap(JDK), jq(설정 파일이 있을 때), bash 3.2+
#
# Usage: diff-coverage-validate.sh [--check-only | --report-only] [--also <git-ref>] [git-ref]
#   --check-only  : 변경 Controller 를 다루는 aiTest 존재만 본다 (aiTest · JaCoCo 미실행)
#   --report-only : aiTest 를 돌리지 않고 기존 JaCoCo 리포트로 판정한다.
#                   리포트가 없거나 로컬 diff 파일보다 오래되면 FAIL (Stop 게이트용)
#   --also <ref>  : 이 ref 와도 다른 파일만 본다 (요청 안에서 합친 원격 변경을 빼는 Stop 게이트용)
#
# 대상 모듈 = 설정 .modules → build.gradle.kts 에 환경 블록이 있는 모듈 → 단일 모듈(".") 순.
# 라이브러리 모듈 → 소비 모듈 = 설정 .libraryModules. 설정: .claude/kotlin-spring-aitest-coverage.json
#
# 종료 코드: 0 통과 · 1 미충족 · 2 실행 오류 · 판정 불가
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Gradle 루트 — 시작 디렉터리에서 git 루트까지 올라가며 settings.gradle(.kts) · gradlew 가 있는 가장 가까운 곳 (없으면 시작 디렉터리)
gradle_root() {
  local d top f
  d="$(cd "$1" 2>/dev/null && pwd -P)" || { echo "$1"; return; }
  top="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" || { echo "$1"; return; }
  while :; do
    for f in settings.gradle settings.gradle.kts gradlew; do [ -e "$d/$f" ] && { echo "$d"; return; }; done
    { [ "$d" = "$top" ] || [ "$d" = / ]; } && break
    d="$(dirname "$d")"
  done
  echo "$1"
}
ROOT="$(gradle_root "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}")"
export CLAUDE_PROJECT_DIR="$ROOT"
cd "$ROOT"

CHECK_ONLY=false
REPORT_ONLY=false
BASE="HEAD"
ALSO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=true; shift ;;
    --report-only) REPORT_ONLY=true; shift ;;
    --also) ALSO="${2:?--also 에 ref 가 필요합니다}"; shift 2 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) BASE="$1"; shift ;;
  esac
done

NAME="diff-coverage-validate"
CONFIG="$ROOT/.claude/kotlin-spring-aitest-coverage.json"
MARKER="// >>> kotlin-spring-aitest-coverage"
REPORT_REL="build/reports/jacoco/aiTestReport/aiTestReport.xml"
AITEST_DIR="src/aiTest/kotlin"

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
tmp="$(mktemp -d "${TMPDIR:-/tmp}/kt-aitest-diff.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
changed_file="$tmp/changed"
entries_file="$tmp/entries"
modules_file="$tmp/modules"

# 경로를 Gradle 루트 기준으로 맞춘다 (untracked 와 같게). 지운 파일은 판정할 코드가 없다
git diff "$BASE" --name-only --relative --diff-filter=d > "$tmp/tracked" 2>/dev/null || { echo "$NAME: git diff $BASE 실패" >&2; exit 2; }
if [ -n "$ALSO" ]; then
  git diff "$ALSO" --name-only --relative --diff-filter=d > "$tmp/also" 2>/dev/null || { echo "$NAME: git diff $ALSO 실패" >&2; exit 2; }
  { sort -u "$tmp/tracked"; sort -u "$tmp/also"; } | sort | uniq -d > "$tmp/both"
  mv "$tmp/both" "$tmp/tracked"
fi
{
  cat "$tmp/tracked"
  git ls-files --others --exclude-standard 2>/dev/null
} | awk 'NF && !seen[$0]++' > "$changed_file"

if [ ! -s "$changed_file" ]; then
  echo "$NAME: no diff vs $BASE — OK"
  exit 0
fi

TRIGGER_RE='(^|/)src/main/(kotlin|java)/.*\.kt$|(^|/)src/main/resources/.*[Mm]apper.*\.xml$|(^|/)src/aiTest/kotlin/.*\.kt$'
if ! grep -qE "$TRIGGER_RE" "$changed_file"; then
  echo "$NAME: no main Kotlin/mapper/aiTest diff — OK"
  exit 0
fi

# --- 모듈 -----------------------------------------------------------------------
# 모듈 = Gradle 프로젝트 경로(콜론 구분, 앞 콜론 없음). 디렉터리 = 콜론을 / 로. 루트 단일 모듈은 "."
MODULES="$(cfg '.modules // [] | .[]' | xargs)"
if [ -z "$MODULES" ]; then
  MODULES="$(git ls-files -co --exclude-standard -- '*build.gradle.kts' 2>/dev/null | while IFS= read -r f; do
    grep -qF "$MARKER" "$f" 2>/dev/null || continue
    d="$(dirname "$f")"
    if [ "$d" = "." ]; then echo "."; else echo "${d//\//:}"; fi
  done | sort -u | xargs)"
fi
[ -n "$MODULES" ] || MODULES="."
LIBRARIES="$(cfg '.libraryModules // {} | to_entries[] | "\(.key)=\(.value | join(","))"' | xargs)"

mod_dir() { if [ "$1" = "." ]; then echo ""; else echo "${1//://}/"; fi; }
mod_task() { if [ "$1" = "." ]; then echo "$2"; else echo ":$1:$2"; fi; }

kt_package() { sed -nE 's/^[[:space:]]*package[[:space:]]+([A-Za-z0-9_.`]+).*/\1/p' "$1" 2>/dev/null | head -1 | tr -d '`'; }
# @RestController · @Controller 가 붙은 클래스 이름 (쉼표 구분). 파일 이름과 클래스 이름이 달라도 된다
kt_controllers() {
  awk '
  /@([A-Za-z0-9_]+\.)*(Rest)?Controller([^A-Za-z0-9_]|$)/ { pending = 1 }
  pending && match($0, /class[ \t]+[A-Za-z0-9_]+/) { s = substr($0, RSTART, RLENGTH); sub(/class[ \t]+/, "", s); print s; pending = 0 }
  ' "$1" 2>/dev/null | paste -sd, -
}

# 소유 모듈|own·library|경로 — 가장 긴 디렉터리 접두가 이기는 모듈, 없으면 라이브러리 → 소비 모듈마다
awk -v mods="$MODULES" -v libs="$LIBRARIES" '
function dir_of(m) { if (m == ".") return ""; gsub(/:/, "/", m); return m "/" }
function owner(f, list, n,    i, d, best, bl) {
  best = ""; bl = -1
  for (i = 1; i <= n; i++) {
    d = dir_of(list[i])
    if ((index(f, d "src/main/kotlin/") == 1 || index(f, d "src/main/java/") == 1) && length(d) > bl) { best = list[i]; bl = length(d) }
  }
  return best
}
BEGIN {
  nm = split(mods, mod, " ")
  nl = split(libs, pair, " ")
  for (i = 1; i <= nl; i++) { split(pair[i], kv, "="); lib[i] = kv[1]; consumers[i] = kv[2] }
}
/\.kt$/ && /src\/main\/(kotlin|java)\// {
  f = $0
  m = owner(f, mod, nm)
  if (m != "") { print m "|own|" f; next }
  l = owner(f, lib, nl)
  if (l == "") next
  for (i = 1; i <= nl; i++) if (lib[i] == l) { nc = split(consumers[i], c, ","); for (j = 1; j <= nc; j++) print c[j] "|library|" f }
}
' "$changed_file" | sort -u > "$tmp/owners"

# 엔트리: 소비 모듈|패키지|Controller 이름(쉼표)|경로
while IFS='|' read -r mod own f; do
  ctrl=""
  [ "$own" = "own" ] && ctrl="$(kt_controllers "$f")"
  echo "$mod|$(kt_package "$f")|$ctrl|$f"
done < "$tmp/owners" > "$entries_file"

entry_count="$(awk 'END { print NR }' "$entries_file")"

has_aitest() { # $1=모듈 $2=클래스 이름 — aiTest 본문에 단어로, 또는 <이름>…AiTest 식별자로 나오면 있다
  local dir; dir="$(mod_dir "$1")$AITEST_DIR"
  [ -d "$dir" ] || return 1
  grep -rqwE --include='*.kt' -- "$2|$2[A-Za-z0-9_]*AiTest[A-Za-z0-9_]*" "$dir" 2>/dev/null
}

module_of_test() { # $1=aiTest 파일 → 모듈 (없으면 빈 값)
  local m d best="" bl=-1
  for m in $MODULES; do
    d="$(mod_dir "$m")"
    case "$1" in "${d}$AITEST_DIR/"*) [ "${#d}" -gt "$bl" ] && { best="$m"; bl="${#d}"; } ;; esac
  done
  echo "$best"
}

if [ "$entry_count" -gt 0 ]; then
  missing=""
  while IFS='|' read -r mod pkg ctrls src; do
    [ -n "$ctrls" ] || continue
    for c in ${ctrls//,/ }; do
      has_aitest "$mod" "$c" || missing="${missing}  $mod: ${pkg:+$pkg.}$c ($src) 을 다루는 aiTest 가 없음"$'\n'
    done
  done < "$entries_file"
  if [ -n "$missing" ]; then
    echo "$NAME: FAIL — 변경 Controller 에 @AiTest 가 없습니다:" >&2
    printf '%s' "$missing" >&2
    echo "  → <module>/$AITEST_DIR/ 에 그 Controller 이름이 나오는 @AiTest · @AiWebTest 작성" >&2
    exit 1
  fi
  cut -d'|' -f1 "$entries_file" | sort -u > "$modules_file"
else
  { grep -E "(^|/)$AITEST_DIR/.*\.kt$" "$changed_file" || true; } | while IFS= read -r f; do
    module_of_test "$f"
  done | awk 'NF' | sort -u > "$modules_file"
fi

module_count="$(awk 'END { print NR }' "$modules_file")"
if [ "$module_count" -eq 0 ]; then
  echo "$NAME: no verifiable module diff — OK"
  exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
  echo "$NAME: check-only OK — @AiTest 존재만 확인 ($entry_count file(s), $module_count module(s))"
  echo "$NAME: aiTest · JaCoCo 는 돌지 않았다. 완료 게이트는 $0 ${ALSO:+--also $ALSO }$BASE 가 필요하다"
  exit 0
fi

# aiTest 를 돌릴 JDK — javap 도 이 JDK 의 것을 쓴다
jdk_version="$(cfg '.jdkVersion // empty')"
if [ -n "$jdk_version" ] && [ -x /usr/libexec/java_home ]; then
  JAVA_HOME="$(/usr/libexec/java_home -v "$jdk_version" 2>/dev/null || echo "${JAVA_HOME:-}")"
  export JAVA_HOME
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
    echo "  → $0 ${ALSO:+--also $ALSO }$BASE 로 aiTest 를 실행해 리포트를 갱신" >&2
    exit 1
  fi
  if [ "$entry_count" -eq 0 ]; then
    echo "$NAME: report-only PASS (aiTest-only diff, $module_count module(s))"
    exit 0
  fi
else
  # --- aiTest 실행 ------------------------------------------------------------
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
    # 리포트는 환경 블록의 finalizedBy 가 만든다 — --tests 는 바로 앞 태스크에 붙으므로 aiTest 가 마지막이어야 한다
    set -- "$@" "$(mod_task "$mod" compileAiTestKotlin)" "$(mod_task "$mod" aiTest)"
    # main 변경(자기 모듈 · 라이브러리)이 있으면 전체, aiTest 만 바뀌었으면 그 파일의 최상위 클래스만
    if grep -q "^$mod|" "$entries_file"; then
      echo "  → $(mod_task "$mod" aiTest) (full — main Kotlin changed)"
      continue
    fi
    d="$(mod_dir "$mod")"
    while IFS= read -r t; do
      [ "$(module_of_test "$t")" = "$mod" ] || continue
      pkg="$(kt_package "$t")"
      for cls in $(sed -nE 's/^(((public|internal|open|abstract|data|sealed)[[:space:]]+)*)class[[:space:]]+([A-Za-z0-9_]+).*/\4/p' "$t"); do
        set -- "$@" --tests "${pkg:+$pkg.}$cls"
        echo "  → $(mod_task "$mod" aiTest) --tests ${pkg:+$pkg.}$cls"
      done
    done < <(grep -E "^${d}$AITEST_DIR/.*\.kt$" "$changed_file" || true)
  done < "$modules_file"
  ./gradlew "$@"

  if [ "$entry_count" -eq 0 ]; then
    echo "$NAME: PASS (aiTest-only diff, $module_count module(s))"
    exit 0
  fi
fi

# --- 변경 메서드 커버리지 -------------------------------------------------------
ok=""; skip=""; bad=""; broken=""
while IFS='|' read -r mod _pkg _ctrls src; do
  xml="$(mod_dir "$mod")$REPORT_REL"
  rc=0
  out="$("$SCRIPT_DIR/method-coverage-get.sh" "$BASE" "$xml" "$src" "$mod" 2>&1)" || rc=$?
  case "$rc" in
    0) if printf '%s\n' "$out" | grep -q '^OK '; then ok="${ok}${out}"$'\n'; else skip="${skip}${out}"$'\n'; fi ;;
    2) broken="${broken}${out}"$'\n' ;;
    *) bad="${bad}${out}"$'\n' ;;
  esac
done < "$entries_file"

[ -z "$ok" ] || { echo "$NAME: changed method coverage OK:"; printf '%s' "$ok" | sed '/^$/d; s/^/  /'; }
[ -z "$skip" ] || { echo "$NAME: changed method coverage skipped:"; printf '%s' "$skip" | sed '/^$/d; s/^/  /'; }
if [ -n "$bad" ]; then
  echo "$NAME: FAIL — changed method JaCoCo below 100%:" >&2
  printf '%s' "$bad" | sed '/^$/d; s/^/  /' >&2
  echo "  → 변경 메서드를 100% 덮도록 @AiTest 보강 후 재실행 (최대 3회)" >&2
  echo "  → 리포트: <module>/build/reports/jacoco/aiTestReport/html/" >&2
fi
if [ -n "$broken" ]; then
  echo "$NAME: FAIL — 변경 메서드를 판정할 수 없습니다 (C-09):" >&2
  printf '%s' "$broken" | sed '/^$/d; s/^/  /' >&2
  echo "  → JDK(javap)를 맞추고 $0 ${ALSO:+--also $ALSO }$BASE 로 클래스 파일 · 리포트를 다시 만든다" >&2
  exit 2
fi
[ -z "$bad" ] || exit 1

echo "$NAME: PASS ($entry_count file(s), $module_count module(s), changed method coverage 100%)"
exit 0
