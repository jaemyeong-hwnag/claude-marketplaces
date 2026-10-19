#!/usr/bin/env bash
# FastAPI 서버의 부하 측정을 무효로 만드는 설정을 찾는다 (references/fastapi-stress-rules.md FAS-01 ~ FAS-09).
#
#   fastapi-stress-config-validate.sh [디렉터리]   CLI — 종료 코드 0 없음/경고만 · 2 위반 · 1 오류
#   (stdin 에 훅 JSON)                            PreToolUse(Bash) 가 부하 도구 실행이면 프로젝트를 검사해 알린다. 막지 않는다
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RULES="$PLUGIN_ROOT/references/fastapi-stress-rules.md"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/fastapi-stress.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT

N='[1-9][0-9]+|[2-9]'   # 2 이상
FINDINGS="$TMP/findings"; : > "$FINDINGS"
ERRORS=0

# 조항 판정 메시지
add() { # $1=error|warn $2=조항 $3=위치 $4=메시지
  [ "$1" = error ] && ERRORS=$((ERRORS+1))
  if [ "$1" = error ]; then printf '❌ %s %s — %s\n' "$2" "$3" "$4" >> "$FINDINGS"
  else printf '⚠️ %s %s — %s\n' "$2" "$3" "$4" >> "$FINDINGS"; fi
}

# 개발 · 로컬 · 테스트용 파일 (settings/dev.py · local_settings.py · docker-compose.dev.yml · Dockerfile.local …)과 CI 파일
is_dev() {
  local b
  case "${1#"$ROOT"/}" in .github/*|*/.github/*|.gitlab-ci.yml|.gitlab-ci.yaml|*/.gitlab-ci.yml|*/.gitlab-ci.yaml) return 0 ;; esac
  b="$(printf '%s' "${1##*/}" | tr 'A-Z' 'a-z')"
  printf '%s' "$b" | grep -qE '(^|[._-])(dev|develop|development|local|test|tests|testing)([._-]|$)'
}

# Makefile 의 dev · local · test 대상 안 줄을 뺀다 — 입력 "경로:줄:내용"
drop_dev_targets() {
  local line f n tgt
  while IFS= read -r line; do
    f="${line%%:*}"; n="${line#*:}"; n="${n%%:*}"
    case "${f##*/}" in
      Makefile|makefile|GNUmakefile|*.mk)
        tgt="$(awk -v n="$n" '/^[^\t#][^:=]*:([^=]|$)/ { t = $0; sub(/:.*/, "", t) } NR == n { print t; exit }' "$f" | tr 'A-Z' 'a-z')"
        printf '%s' "$tgt" | grep -qE '(^|[[:space:]._-])(dev|develop|development|local|test|tests|testing)([[:space:]._-]|$)' && continue ;;
    esac
    printf '%s\n' "$line"
  done
}

# 파일 목록 → $TMP/py · $TMP/pyprod · $TMP/cfg · $TMP/cfgprod · $TMP/dep (NUL 구분)
collect() {
  local root="$1"
  find "$root" \( -path "$root/.claude" -o -name .git -o -name node_modules -o -name .venv -o -name venv \
      -o -name .tox -o -name __pycache__ -o -name site-packages -o -name build -o -name dist \) -prune -o -type f -print0 \
    > "$TMP/all"
  : > "$TMP/py"; : > "$TMP/pyprod"; : > "$TMP/cfg"; : > "$TMP/cfgprod"; : > "$TMP/dep"
  local f b
  while IFS= read -r -d '' f; do
    b="${f##*/}"
    case "$b" in
      requirements*.txt|Pipfile|setup.cfg) printf '%s\0' "$f" >> "$TMP/dep" ;;
      pyproject.toml) printf '%s\0' "$f" >> "$TMP/dep"; printf '%s\0' "$f" >> "$TMP/cfg" ;;
      test_*.py|*_test.py|conftest.py) ;;
      *.py)
        printf '%s\0' "$f" >> "$TMP/py"
        is_dev "$f" || printf '%s\0' "$f" >> "$TMP/pyprod" ;;
      Dockerfile*|*.dockerfile|Procfile|Makefile|*.sh|*.yml|*.yaml|*.toml|*.ini|*.cfg|*.conf|*.service|*.env|.env*)
        printf '%s\0' "$f" >> "$TMP/cfg"
        is_dev "$f" || printf '%s\0' "$f" >> "$TMP/cfgprod" ;;
    esac
  done < "$TMP/all"
}

# 목록의 파일에서 정규식을 찾아 "경로:줄:내용" 을 낸다. 주석 줄은 뺀다
scan() { # $1=목록 파일들(공백 구분) $2=ERE [$3=-i]
  local lists="$1" re="$2" opt="${3:-}" l
  for l in $lists; do
    [ -s "$TMP/$l" ] || continue
    xargs -0 grep -nHE $opt -- "$re" /dev/null < "$TMP/$l" 2>/dev/null
  done | awk -F: '{ c = $0; sub(/^[^:]*:[^:]*:/, "", c); if (c !~ /^[ \t]*#/) print }'
}
has() { [ -n "$(scan "$1" "$2" "${3:-}" | head -1)" ]; }
loc() { local p="${1%%:*}" r="${1#*:}"; printf '%s:%s' "${p#"$ROOT"/}" "${r%%:*}"; }

check() {
  ROOT="$1"
  collect "$ROOT"
  # FastAPI 프로젝트가 아니면 보지 않는다
  has dep '(^|[^[:alnum:]_-])fastapi([^[:alnum:]_-]|$)' -i || has py '^[[:space:]]*(from|import)[[:space:]]+fastapi' || return 0

  local line
  # FAS-01 개발 서버 · 자동 리로드
  { scan "cfgprod pyprod" '(^|[^[:alnum:]_.-])fastapi["'\'']?[[:space:],]+["'\'']?dev(["'\''[:space:],]|$)|uvicorn.*--reload|gunicorn.*--reload'
    scan pyprod 'uvicorn\.run\(.*reload[[:space:]]*=[[:space:]]*True|^reload[[:space:]]*=[[:space:]]*True'
  } | drop_dev_targets > "$TMP/f01"
  while IFS= read -r line; do
    add error FAS-01 "$(loc "$line")" "개발 서버 · 자동 리로드로 띄운다. 워커가 1개로 고정되고 감시 프로세스가 붙는다 → fastapi run · uvicorn(리로드 없이)"
  done < "$TMP/f01"

  # FAS-02 · FAS-03 멀티 워커 + prometheus
  scan "cfg py" "--workers[\"']?[[:space:],=]+[\"']?($N)([^0-9]|\$)|gunicorn.*[[:space:]]-w[[:space:]]*[\"']?($N)([^0-9]|\$)|WEB_CONCURRENCY[\"']?[[:space:]]*[:=][[:space:]]*[\"']?($N)([^0-9]|\$)" > "$TMP/workers"
  scan py "(^|[^[:alnum:]_])workers[[:space:]]*=[[:space:]]*(($N)([^0-9]|\$)|.*cpu_count)" >> "$TMP/workers"
  if [ -s "$TMP/workers" ] && has "py dep" 'prometheus[-_]'; then
    if ! has "cfg py dep" 'PROMETHEUS_MULTIPROC_DIR|prometheus_multiproc_dir'; then
      while IFS= read -r line; do
        add error FAS-02 "$(loc "$line")" "워커가 여럿인데 PROMETHEUS_MULTIPROC_DIR 가 없다. 스크레이프마다 다른 워커 하나의 값이 나온다"
      done < "$TMP/workers"
    elif has "cfg py" 'gunicorn' && ! has py 'mark_process_dead'; then
      line="$(scan "cfg py" 'gunicorn' | head -1)"
      add warn FAS-03 "$(loc "$line")" "Gunicorn 설정에 child_exit → multiprocess.mark_process_dead(worker.pid) 가 없다. 죽은 워커의 live 게이지가 남는다"
    fi
  fi

  # FAS-04 debug=True
  { scan py '(^|[^[:alnum:]_])(app|application)\.debug[[:space:]]*=[[:space:]]*True'
    [ -s "$TMP/py" ] && xargs -0 awk '
      FNR == 1 { depth = 0 }
      /^[ \t]*#/ { next }
      {
        if (depth == 0 && match($0, /(FastAPI|Starlette)\(/)) { depth = 1; rest = substr($0, RSTART + RLENGTH) } else if (depth > 0) rest = $0; else next
        if (rest ~ /(^|[^[:alnum:]_])debug[ \t]*=[ \t]*True/) print FILENAME ":" FNR ":" $0
        n = split(rest, ch, ""); for (i = 1; i <= n && depth > 0; i++) { if (ch[i] == "(") depth++; else if (ch[i] == ")") depth-- }
      }' < "$TMP/py"
  } > "$TMP/f04"
  while IFS= read -r line; do
    add warn FAS-04 "$(loc "$line")" "debug=True 다. 에러에 트레이스백을 만들어 돌려준다 — 운영과 같은 값으로 잰다"
  done < "$TMP/f04"

  # FAS-05 로그 레벨 debug · trace
  scan "cfg py" "--log-level[\"']?[[:space:],=]+[\"']?(debug|trace)|log_?level[\"']?[[:space:]]*[:=][[:space:]]*[\"'](debug|trace)[\"']|UVICORN_LOG_LEVEL[\"']?[[:space:]]*[:=][[:space:]]*[\"']?(debug|trace)" -i > "$TMP/f05"
  while IFS= read -r line; do
    add warn FAS-05 "$(loc "$line")" "로그 레벨이 debug · trace 다. 요청마다 로그 비용이 지연에 섞인다 → info 이상"
  done < "$TMP/f05"

  # FAS-06 deprecated 워커 클래스
  scan "cfg py" 'uvicorn\.workers\.UvicornWorker' > "$TMP/f06"
  while IFS= read -r line; do
    add warn FAS-06 "$(loc "$line")" "uvicorn.workers 는 deprecated 다 → uvicorn-worker 패키지의 uvicorn_worker.UvicornWorker"
  done < "$TMP/f06"

  # FAS-07 async def 안의 블로킹 호출
  : > "$TMP/f07"
  [ -s "$TMP/py" ] && xargs -0 awk '
    function ind(s) { match(s, /^[ \t]*/); return RLENGTH }
    FNR == 1 { ai = -1; si = -1 }
    /^[ \t]*($|#)/ { next }
    {
      i = ind($0)
      if (si >= 0 && i <= si) si = -1
      if (ai >= 0 && i <= ai) ai = -1
      if ($0 ~ /^[ \t]*async[ \t]+def[ \t]/) { if (ai < 0) ai = i; next }
      if (ai >= 0 && si < 0 && $0 ~ /^[ \t]*def[ \t]/) { si = i; next }
      if (ai >= 0 && si < 0 && $0 ~ /(^|[^[:alnum:]_.])(time\.sleep|requests\.(get|post|put|patch|delete|head|options|request)|urllib\.request\.urlopen)\(/)
        print FILENAME ":" FNR ":" $0
    }' < "$TMP/py" > "$TMP/f07"
  while IFS= read -r line; do
    add warn FAS-07 "$(loc "$line")" "async def 안의 블로킹 호출이 이벤트 루프를 멈춘다 → await 가능한 API(asyncio.sleep · httpx.AsyncClient) 또는 def 엔드포인트"
  done < "$TMP/f07"

  # FAS-08 서버 측 계측 · in-flight
  if ! has py 'prometheus_client|prometheus_fastapi_instrumentator|starlette_exporter|opentelemetry'; then
    add warn FAS-08 "." "서버 측 계측이 없다. 지연 히스토그램과 in-flight 게이지가 있어야 Little(ST-13) 로 측정을 검증한다"
  elif has py 'Instrumentator\(' && ! has py 'should_instrument_requests_inprogress[[:space:]]*=[[:space:]]*True'; then
    line="$(scan py 'Instrumentator\(' | head -1)"
    add warn FAS-08 "$(loc "$line")" "Instrumentator 에 should_instrument_requests_inprogress=True 가 없다 (기본 False) — http_requests_inprogress 가 나오지 않는다"
  fi

  # FAS-09 지연을 Summary 로
  scan py "Summary\([[:space:]]*[\"'][^\"']*(latency|duration|seconds|_time)" -i > "$TMP/f09"
  while IFS= read -r line; do
    add warn FAS-09 "$(loc "$line")" "지연을 Summary 로 잰다. Python Summary 는 count · sum 만 내고 분위수 · 인스턴스 합산이 안 된다 → Histogram"
  done < "$TMP/f09"
  return 0
}

# --- 부하 도구 명령 판별 (훅) — common-stress-test 의 stress-target-validate.sh 와 같은 규칙 ---------------
# heredoc 본문은 명령이 아니라 데이터다. 셸에 먹이는 heredoc(sh <<EOF)만 명령으로 남긴다
strip_heredoc() {
  awk -v q="'" '
    d != "" { t = $0; if (dash) sub(/^\t+/, "", t); if (t == d) d = ""; else if (keep) print; next }
    { print; s = $0; gsub(/<<</, "\001", s)
      if (match(s, "<<-?[ \t]*[\"" q "]?[A-Za-z_][A-Za-z0-9_]*")) {
        d = substr(s, RSTART, RLENGTH); dash = (d ~ /^<<-/)
        sub(/^<<-?[ \t]*/, "", d); gsub("[\"" q "]", "", d)
        keep = (s ~ /(^|[;&|(][ \t]*)(sudo[ \t]+)?(ba|z|da|k)?sh([ \t]+-[A-Za-z]+)*[ \t]*<</)
      } }'
}

# 부하 도구를 실행하는 구간인가 — 구간의 첫 단어(환경 변수 대입 · 래퍼 제외)나 docker 이미지로 판단한다. 도구 이름은 TOOL 에 남긴다
is_load_segment() {
  local seg="$1" w first="" rest
  TOOL=""
  # shellcheck disable=SC2086
  set -f; set -- $seg; set +f
  while [ "$#" -gt 0 ]; do
    w="${1#[\"\'(\{]}"
    case "$w" in
      *=*|sudo|time|nohup|exec|command|env|npx|bunx|pnpx|uvx|do|then|else|elif|if|while|until|!|-*|'') shift ;;
      uv|poetry|pipenv|pdm|hatch)
        [ "${2:-}" = run ] || { first="$w"; shift; break; }
        shift 2 ;;
      python|python3|python3.*)
        [ "${2:-}" = -m ] || { first="$w"; shift; break; }
        shift 2 ;;
      timeout)
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -s|-k|--signal|--kill-after) shift 2 ;;
            -*) shift ;;
            *) break ;;
          esac
        done
        [ "$#" -gt 0 ] && shift ;;
      sh|bash|zsh|dash|ksh)
        shift
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -*c) shift; break ;;
            -*) shift ;;
            *) set -- ; break ;;
          esac
        done
        [ "$#" -gt 0 ] || { first="$w"; break; } ;;
      *) first="$w"; shift; break ;;
    esac
  done
  rest="$*"
  first="${first##*/}"
  TOOL="$first"
  case "$first" in
    k6) case "$rest" in run*|cloud*) return 0 ;; esac ;;
    locust|jmeter|jmeter.sh|gatling|gatling.sh|wrk|wrk2|hey|oha|ab|autocannon) return 0 ;;
    vegeta) case "$rest" in attack*) return 0 ;; esac ;;
    artillery) case "$rest" in run*|quick*) return 0 ;; esac ;;
    docker|podman|docker-compose)
      printf '%s' "$rest" | grep -qE '(^|[ /])(grafana/k6|locustio/locust|[a-z0-9_.-]*/?jmeter|[a-z0-9_.-]*/?gatling)(:[^ ]*)?( |$)' && return 0
      # compose 서비스 이름으로 부하기를 띄우는 경우
      printf '%s' "$first $rest" | grep -qE '(compose|docker-compose).*( run| up).* (k6|locust|jmeter|gatling)( |$)' && return 0 ;;
    mvn|mvnw|gradle|gradlew) printf '%s' "$rest" | grep -qiE 'gatling' && return 0 ;;
  esac
  return 1
}

# 명령을 && · || · ; · & · | · $( · ` 로 나눈 구간 중 하나라도 부하 도구 실행이면 참
is_load_command() { # $1=명령
  local seg
  while IFS= read -r seg; do
    [ -n "${seg// /}" ] || continue
    is_load_segment "$seg" && return 0
  done < <(printf '%s\n' "$1" | strip_heredoc | sed -E 's/(\|\||&&|[;&|]|\$\(|`)/\n/g')
  return 1
}

hook() {
  local input event tool cmd dir
  input="$(cat)"
  [ -n "$input" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  event="$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null)"
  tool="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)"
  [ "$event" = PreToolUse ] && [ "$tool" = Bash ] || exit 0
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"
  is_load_command "$cmd" || exit 0
  dir="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // ""')}"
  [ -n "$dir" ] && [ -d "$dir" ] || exit 0
  check "$dir"
  [ -s "$FINDINGS" ] || exit 0
  jq -n --arg c "$(printf 'FastAPI 부하 측정 전 설정 점검 (python-fastapi-stress-test) — 측정이 무효가 될 수 있다. 고치고 돌리거나 결과에 함께 적는다.\n%s\n규칙: %s' "$(cat "$FINDINGS")" "$RULES")" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  exit 0
}

if [ "$#" -eq 0 ] && [ ! -t 0 ]; then hook; fi

TARGET="${1:-.}"
[ -d "$TARGET" ] || { echo "fastapi-stress-config-validate: 디렉터리가 아니다: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
check "$TARGET"
if [ -s "$FINDINGS" ]; then
  cat "$FINDINGS"
  echo "규칙: $RULES"
fi
[ "$ERRORS" -gt 0 ] && exit 2
exit 0
