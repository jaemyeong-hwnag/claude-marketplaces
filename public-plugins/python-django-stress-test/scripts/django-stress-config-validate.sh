#!/usr/bin/env bash
# Django 서버의 부하 측정을 무효로 만드는 설정을 찾는다 (references/django-stress-rules.md DJ-01 ~ DJ-12).
#
#   django-stress-config-validate.sh [디렉터리]   CLI — 종료 코드 0 없음/경고만 · 2 위반 · 1 오류
#   (stdin 에 훅 JSON)                           PreToolUse(Bash) 가 부하 도구 실행이면 프로젝트를 검사해 알린다. 막지 않는다
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RULES="$PLUGIN_ROOT/references/django-stress-rules.md"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/django-stress.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT

N='[1-9][0-9]+|[2-9]'   # 2 이상
Q="[\"']"
FINDINGS="$TMP/findings"; : > "$FINDINGS"
ERRORS=0

add() { # $1=error|warn $2=조항 $3=위치 $4=메시지
  if [ "$1" = error ]; then ERRORS=$((ERRORS+1)); printf '❌ %s %s — %s\n' "$2" "$3" "$4" >> "$FINDINGS"
  else printf '⚠️ %s %s — %s\n' "$2" "$3" "$4" >> "$FINDINGS"; fi
}

# 개발 · 로컬 · 테스트용 파일 (settings/dev.py · local_settings.py · docker-compose.dev.yml · Dockerfile.local …)
is_dev() {
  local b
  b="$(printf '%s' "${1##*/}" | tr 'A-Z' 'a-z')"
  printf '%s' "$b" | grep -qE '(^|[._-])(dev|develop|development|local|test|tests|testing)([._-]|$)'
}

# 파일 목록 → $TMP/{py,pyprod,gconf,cfg,cfgprod,dep} (NUL 구분)
collect() {
  local root="$1" f b
  find "$root" \( -path "$root/.claude" -o -name .git -o -name node_modules -o -name .venv -o -name venv \
      -o -name .tox -o -name __pycache__ -o -name site-packages -o -name build -o -name dist -o -name tests \) -prune \
      -o -type f -print0 > "$TMP/all"
  : > "$TMP/py"; : > "$TMP/pyprod"; : > "$TMP/gconf"; : > "$TMP/cfg"; : > "$TMP/cfgprod"; : > "$TMP/dep"
  while IFS= read -r -d '' f; do
    b="${f##*/}"
    case "$b" in
      requirements*.txt|Pipfile|setup.cfg) printf '%s\0' "$f" >> "$TMP/dep" ;;
      pyproject.toml) printf '%s\0' "$f" >> "$TMP/dep"; printf '%s\0' "$f" >> "$TMP/cfg" ;;
      test_*.py|*_test.py|conftest.py) ;;
      *.py)
        printf '%s\0' "$f" >> "$TMP/py"
        case "$b" in *gunicorn*) printf '%s\0' "$f" >> "$TMP/gconf" ;; esac
        is_dev "$f" || printf '%s\0' "$f" >> "$TMP/pyprod" ;;
      Dockerfile*|*.dockerfile|Procfile|*.sh|*.yml|*.yaml|*.toml|*.ini|*.cfg|*.conf|*.service|*.env|.env*)
        printf '%s\0' "$f" >> "$TMP/cfg"
        is_dev "$f" || printf '%s\0' "$f" >> "$TMP/cfgprod" ;;
    esac
  done < "$TMP/all"
}

# 목록의 파일에서 정규식을 찾아 "경로:줄:내용" 을 낸다. 주석 줄은 뺀다
scan() { # $1=목록 이름들(공백 구분) $2=ERE [$3=-i]
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
  # Django 프로젝트가 아니면 보지 않는다
  has dep '(^|[^[:alnum:]_-])django([^[:alnum:]_-]|$)' -i || has py '^[[:space:]]*(from|import)[[:space:]]+django([.[:space:]]|$)' || return 0

  local line
  # DJ-01 runserver
  scan cfgprod "(manage\.py|django-admin)$Q?[[:space:],]+$Q?runserver" > "$TMP/f01"
  while IFS= read -r line; do
    add error DJ-01 "$(loc "$line")" "runserver 는 개발 서버다 (Django 문서: 운영에 쓰지 말 것). 요청마다 스레드를 만들어 동시성 상한이 없고 자동 리로더가 붙는다 → gunicorn · uvicorn"
  done < "$TMP/f01"

  # DJ-02 DEBUG = True
  scan pyprod '^[[:space:]]*DEBUG[[:space:]]*=[[:space:]]*True([^[:alnum:]_]|$)' > "$TMP/f02"
  while IFS= read -r line; do
    add error DJ-02 "$(loc "$line")" "DEBUG = True 다. 모든 SQL 을 기록하고(연결당 최근 9000건) 에러 응답이 기술 페이지가 된다 — 운영과 같은 False 로 잰다"
  done < "$TMP/f02"

  # DJ-03 자동 리로드
  { scan "cfgprod pyprod" '(gunicorn|uvicorn)[^#]*--reload([^-[:alnum:]]|$)|uvicorn\.run\(.*reload[[:space:]]*=[[:space:]]*True'
    scan gconf '^[[:space:]]*reload[[:space:]]*=[[:space:]]*True'
  } | sort -u > "$TMP/f03"
  while IFS= read -r line; do
    add error DJ-03 "$(loc "$line")" "자동 리로드는 개발용이다 (Gunicorn reload 설정 설명). 파일 감시가 CPU 를 쓰고 코드가 바뀌면 워커가 재시작된다"
  done < "$TMP/f03"

  # DJ-04 django-debug-toolbar
  scan pyprod "${Q}debug_toolbar(\.middleware\.DebugToolbarMiddleware)?$Q" > "$TMP/f04"
  while IFS= read -r line; do
    add warn DJ-04 "$(loc "$line")" "django-debug-toolbar 가 운영 설정에 있다. 툴바 문서: 운영용으로 다듬지 않았다 — 측정 대상 설정에서 뺀다"
  done < "$TMP/f04"

  # DJ-05 로그 레벨 DEBUG
  { scan pyprod "${Q}level$Q[[:space:]]*:[[:space:]]*${Q}DEBUG$Q|level[[:space:]]*=[[:space:]]*logging\.DEBUG|^[[:space:]]*loglevel[[:space:]]*=[[:space:]]*${Q}debug$Q"
    scan "cfgprod pyprod" "--log-level$Q?[[:space:],=]+$Q?(debug|trace)([^[:alnum:]]|$)|GUNICORN_CMD_ARGS=.*--log-level[= ]debug" -i
  } | sort -u > "$TMP/f05"
  while IFS= read -r line; do
    add warn DJ-05 "$(loc "$line")" "로그 레벨이 DEBUG 다. 요청마다 로그 비용이 지연에 섞인다 → INFO 이상 (DEBUG=True 면 django.db.backends 가 SQL 도 남긴다)"
  done < "$TMP/f05"

  # 워커 2 이상 지정
  { scan "cfg py" "--workers$Q?[[:space:],=]+$Q?($N)([^0-9]|\$)|gunicorn.*[[:space:]]-w[[:space:]]*$Q?($N)([^0-9]|\$)|WEB_CONCURRENCY$Q?[[:space:]]*[:=][[:space:]]*$Q?($N)([^0-9]|\$)"
    scan gconf "^[[:space:]]*workers[[:space:]]*=[[:space:]]*(($N)([^0-9]|\$)|.*cpu_count)"
  } > "$TMP/workers"

  # DJ-06 · DJ-07 멀티 워커 + prometheus
  if [ -s "$TMP/workers" ] && has "py dep" 'django[-_]prometheus|prometheus[-_]client'; then
    if ! has "cfg py dep" 'PROMETHEUS_MULTIPROC_DIR|prometheus_multiproc_dir|PROMETHEUS_METRICS_EXPORT_PORT_RANGE'; then
      while IFS= read -r line; do
        add error DJ-06 "$(loc "$line")" "워커가 여럿인데 PROMETHEUS_MULTIPROC_DIR(또는 PROMETHEUS_METRICS_EXPORT_PORT_RANGE) 가 없다. 스크레이프마다 워커 하나의 값만 나온다"
      done < "$TMP/workers"
    elif has "cfg py" 'PROMETHEUS_MULTIPROC_DIR|prometheus_multiproc_dir' && has "cfg py" 'gunicorn' && ! has py 'mark_process_dead'; then
      line="$(scan "cfg py" 'gunicorn' | head -1)"
      add warn DJ-07 "$(loc "$line")" "Gunicorn 설정에 child_exit → multiprocess.mark_process_dead(worker.pid) 가 없다. 죽은 워커의 live 게이지가 남는다"
    fi
  fi

  # DJ-08 서버 측 계측 · in-flight
  if ! has py 'django_prometheus|prometheus_client|opentelemetry'; then
    add warn DJ-08 "." "서버 측 계측이 없다. 지연 히스토그램과 in-flight 게이지가 있어야 Little(ST-13) 로 측정을 검증한다 → django-prometheus + in-flight 미들웨어"
  elif ! has py 'track_inprogress|in_?flight|in_?progress' -i; then
    line="$(scan py 'django_prometheus|prometheus_client|opentelemetry' | head -1)"
    add warn DJ-08 "$(loc "$line")" "in-flight 게이지가 없다. django-prometheus 는 in-flight 게이지를 내지 않는다 → Gauge(multiprocess_mode=\"livesum\").track_inprogress() 미들웨어"
  fi

  # DJ-09 django-prometheus 미들웨어 순서
  : > "$TMP/f09"
  [ -s "$TMP/py" ] && xargs -0 awk -v q="'" '
    BEGIN { re = "\"[^\"]*\"|" q "[^" q "]*" q }
    function flush() {
      if (n > 0) {
        for (i = 1; i <= n; i++) {
          if (items[i] ~ /PrometheusBeforeMiddleware/ && i != 1) print FILENAME ":" start ":Before"
          if (items[i] ~ /PrometheusAfterMiddleware/ && i != n) print FILENAME ":" start ":After"
        }
      }
      n = 0; on = 0
    }
    FNR == 1 { on = 0; n = 0 }
    /^[ \t]*#/ { next }
    !on && /^[ \t]*MIDDLEWARE[ \t]*=[ \t]*[\[(]/ { on = 1; start = FNR; n = 0; s = $0; sub(/^[^\[(]*[\[(]/, "", s) }
    on && FNR != start { s = $0 }
    on {
      sub(/#.*/, "", s)
      while (match(s, re)) { items[++n] = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH) }
      if (s ~ /[\])]/) flush()
    }' < "$TMP/py" > "$TMP/f09"
  while IFS= read -r line; do
    case "$line" in
      *:Before) add warn DJ-09 "$(loc "$line")" "PrometheusBeforeMiddleware 가 MIDDLEWARE 의 처음이 아니다. 앞 미들웨어의 시간이 지연 히스토그램에서 빠진다" ;;
      *:After) add warn DJ-09 "$(loc "$line")" "PrometheusAfterMiddleware 가 MIDDLEWARE 의 마지막이 아니다. 뷰 라벨 · 상태 집계가 뒤 미들웨어의 결과를 놓친다" ;;
    esac
  done < "$TMP/f09"

  # DJ-11 Gunicorn 워커 수 미지정 (기본 1)
  scan "cfgprod" "(^|[[:space:]\"'\[,(]|/)gunicorn$Q?[[:space:],]+[^#]*(wsgi|asgi|:application|-c[[:space:]]|--config)" | grep -viE 'pip[0-9]*[[:space:]]+install|poetry[[:space:]]+add|uv[[:space:]]+(add|pip)' > "$TMP/f11"
  if [ -s "$TMP/f11" ] && ! has "cfg py" "--workers|gunicorn.*[[:space:]]-w[[:space:]]*$Q?[0-9]|WEB_CONCURRENCY" && ! has gconf '^[[:space:]]*workers[[:space:]]*='; then
    line="$(head -1 "$TMP/f11")"
    add warn DJ-11 "$(loc "$line")" "Gunicorn 워커 수를 정하지 않았다 (기본 1 · WEB_CONCURRENCY 없을 때). 워커 하나의 결과를 머신 용량으로 쓰지 않는다 → --workers · --threads 를 정하고 잰다"
  fi

  # DJ-12 ASGI + 영속 연결
  if has "cfg py" '(uvicorn|daphne|hypercorn|granian)[^#]*asgi|UvicornWorker'; then
    scan pyprod "${Q}?CONN_MAX_AGE${Q}?\]?[[:space:]]*[:=][[:space:]]*(None|[1-9])" > "$TMP/f12"
    while IFS= read -r line; do
      add warn DJ-12 "$(loc "$line")" "ASGI 로 띄우는데 CONN_MAX_AGE 가 0 이 아니다. Django 문서: ASGI 에서는 영속 연결을 끄고 DB 백엔드의 풀을 쓴다"
    done < "$TMP/f12"
  fi
  return 0
}

LOAD_RE='(^|[;&|(])[[:space:]]*(((sudo|time|npx|uvx|exec)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+))*([^[:space:];&|]*/)?(k6[[:space:]]+run|locust|jmeter|gatling(\.sh)?|wrk2?|vegeta[[:space:]]+attack|hey|ab|oha|artillery|autocannon)([[:space:]]|$)|docker[[:space:]]+run[^;&|]*grafana/k6'

hook() {
  local input event tool cmd dir
  input="$(cat)"
  [ -n "$input" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  event="$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null)"
  tool="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)"
  [ "$event" = PreToolUse ] && [ "$tool" = Bash ] || exit 0
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"
  printf '%s\n' "$cmd" | grep -qE -- "$LOAD_RE" || exit 0
  dir="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // ""')}"
  [ -n "$dir" ] && [ -d "$dir" ] || exit 0
  check "$dir"
  [ -s "$FINDINGS" ] || exit 0
  jq -n --arg c "$(printf 'Django 부하 측정 전 설정 점검 (python-django-stress-test) — 측정이 무효가 될 수 있다. 고치고 돌리거나 결과에 함께 적는다.\n%s\n규칙: %s' "$(cat "$FINDINGS")" "$RULES")" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  exit 0
}

if [ "$#" -eq 0 ] && [ ! -t 0 ]; then hook; fi

TARGET="${1:-.}"
[ -d "$TARGET" ] || { echo "django-stress-config-validate: 디렉터리가 아니다: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
check "$TARGET"
if [ -s "$FINDINGS" ]; then
  cat "$FINDINGS"
  echo "규칙: $RULES"
fi
[ "$ERRORS" -gt 0 ] && exit 2
exit 0
