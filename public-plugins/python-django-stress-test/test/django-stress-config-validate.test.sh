#!/usr/bin/env bash
# scripts/django-stress-config-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/django-stress-config-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/django-stress-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1)"; CODE=$?; }
# 프로젝트 디렉터리를 지정해 훅을 부른다
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# --- 픽스처 ------------------------------------------------------------------
# 규칙을 모두 지킨 Django 프로젝트. TC 마다 한 곳만 깨뜨린다
# $(mkproj) 는 서브셸이라 카운터 대신 mktemp 로 디렉터리를 나눈다
mkproj() {
  local d; d="$(mktemp -d "$TMP/p.XXXXXX")"
  mkdir -p "$d/myproject"
  printf 'Django==6.0\ngunicorn==26.2\ndjango-prometheus==2.5\n' > "$d/requirements.txt"
  cat > "$d/myproject/settings.py" <<'PY'
DEBUG = False
INSTALLED_APPS = ["django.contrib.contenttypes", "django_prometheus"]
MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "myproject.inflight.InFlightMiddleware",
    "django.middleware.common.CommonMiddleware",  # 공통
    "django_prometheus.middleware.PrometheusAfterMiddleware",
]
DATABASES = {"default": {"ENGINE": "django.db.backends.postgresql", "CONN_MAX_AGE": 60}}
LOGGING = {"version": 1, "root": {"handlers": [], "level": "INFO"}}
PY
  cat > "$d/myproject/inflight.py" <<'PY'
from prometheus_client import Gauge
IN_FLIGHT = Gauge("django_http_requests_in_flight", "In-flight", multiprocess_mode="livesum")
PY
  cat > "$d/gunicorn.conf.py" <<'PY'
from prometheus_client import multiprocess
workers = 4
threads = 4

def child_exit(server, worker):
    multiprocess.mark_process_dead(worker.pid)
PY
  printf '#!/bin/sh\nexport PROMETHEUS_MULTIPROC_DIR=/tmp/prom\nexec gunicorn -c gunicorn.conf.py myproject.wsgi:application\n' > "$d/start.sh"
  printf 'FROM python:3.13-slim\nCMD ["./start.sh"]\n' > "$d/Dockerfile"
  printf '%s' "$d"
}
put() { mkdir -p "$(dirname "$1/$2")"; printf '%b' "$3" > "$1/$2"; }   # $1=프로젝트 $2=상대 경로 $3=내용
payload_bash() { jq -n --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'; }

echo "python-django-stress-test 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-D01 "규칙을 지킨 프로젝트는 조용히 통과한다"
p="$(mkproj)"; run "$p"; expect_code 0; expect_no_out

tc TC-D02 "Django 프로젝트가 아니면 보지 않는다"
p="$TMP/plain"; put "$p" requirements.txt 'flask\n'; put "$p" Dockerfile 'CMD python manage.py runserver\n'; run "$p"; expect_code 0; expect_no_out

tc TC-D03 "Dockerfile · compose · 스크립트의 runserver 를 막는다 (DJ-01)"
p="$(mkproj)"; put "$p" Dockerfile 'CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]\n'
put "$p" docker-compose.yml 'services:\n  web:\n    command: django-admin runserver 0.0.0.0:8000\n'
run "$p"; expect_code 2; expect_out "DJ-01 Dockerfile:1"; expect_out "DJ-01 docker-compose.yml:3"

tc TC-D04 "dev 파일 · Makefile · 주석의 runserver 는 보지 않는다 (DJ-01 과잉 차단 방지)"
p="$(mkproj)"; put "$p" docker-compose.dev.yml 'command: python manage.py runserver\n'; put "$p" Makefile 'dev:\n\tpython manage.py runserver\n'
put "$p" Dockerfile.local 'CMD python manage.py runserver\n'; put "$p" start.sh '# python manage.py runserver\nexport PROMETHEUS_MULTIPROC_DIR=/tmp/p\nexec gunicorn -c gunicorn.conf.py myproject.wsgi:application\n'
run "$p"; expect_code 0; expect_no_out

tc TC-D05 "운영 설정의 DEBUG = True 를 막는다 (DJ-02)"
p="$(mkproj)"; sed -i.bak 's/^DEBUG = False/DEBUG = True  # 임시/' "$p/myproject/settings.py"; rm -f "$p/myproject/settings.py.bak"
run "$p"; expect_code 2; expect_out "DJ-02 myproject/settings.py:1"

tc TC-D06 "dev 설정 · 환경 변수 · 주석 · 다른 이름의 DEBUG 는 보지 않는다 (DJ-02 과잉 차단 방지)"
p="$(mkproj)"; put "$p" myproject/settings/dev.py 'DEBUG = True\n'; put "$p" local_settings.py 'DEBUG = True\n'
put "$p" myproject/prod.py 'DEBUG = env.bool("DEBUG", default=False)\n# DEBUG = True\nTEMPLATE_DEBUG = True\nDEBUG = Trueish\n'
put "$p" tests/settings.py 'DEBUG = True\n'
run "$p"; expect_code 0; expect_no_out

tc TC-D07 "Gunicorn · Uvicorn 자동 리로드를 막는다 (DJ-03)"
p="$(mkproj)"; put "$p" start.sh 'export PROMETHEUS_MULTIPROC_DIR=/tmp/p\nexec gunicorn --reload -c gunicorn.conf.py myproject.wsgi:application\n'
printf 'reload = True\n' >> "$p/gunicorn.conf.py"; put "$p" run_asgi.sh 'uvicorn myproject.asgi:application --reload\n'
run "$p"; expect_code 2; expect_out "DJ-03 start.sh:2"; expect_out "DJ-03 gunicorn.conf.py:"; expect_out "DJ-03 run_asgi.sh:1"

tc TC-D08 "reload = False · --reload-extra-file · dev 파일의 --reload 는 보지 않는다 (DJ-03 과잉 차단 방지)"
p="$(mkproj)"; printf 'reload = False\n' >> "$p/gunicorn.conf.py"; put "$p" run-dev.sh 'gunicorn --reload myproject.wsgi:application -w 2\n'
put "$p" serve.sh 'exec gunicorn --reload-extra-file x.html -c gunicorn.conf.py myproject.wsgi:application\n'
run "$p"; expect_code 0; expect_no_out

tc TC-D09 "운영 설정의 debug_toolbar 를 경고한다 (DJ-04)"
p="$(mkproj)"; printf 'INSTALLED_APPS += ["debug_toolbar"]\nMIDDLEWARE.insert(0, "debug_toolbar.middleware.DebugToolbarMiddleware")\n' >> "$p/myproject/settings.py"
run "$p"; expect_code 0; expect_out "⚠️ DJ-04 myproject/settings.py:11"; expect_out "DJ-04 myproject/settings.py:12"

tc TC-D10 "local 설정의 debug_toolbar · 다른 이름은 경고하지 않는다 (DJ-04 과잉 경고 방지)"
p="$(mkproj)"; put "$p" myproject/settings_local.py 'INSTALLED_APPS = ["debug_toolbar"]\n'; printf 'X = "debug_toolbar_extra"\n' >> "$p/myproject/settings.py"
run "$p"; expect_code 0; expect_no_out

tc TC-D11 "로그 레벨 DEBUG 를 경고한다 (DJ-05)"
p="$(mkproj)"; printf 'LOGGING["loggers"] = {"django.db.backends": {"level": "DEBUG"}}\n' >> "$p/myproject/settings.py"
put "$p" start.sh 'export PROMETHEUS_MULTIPROC_DIR=/tmp/p\nexec gunicorn --log-level debug -c gunicorn.conf.py myproject.wsgi:application\n'
printf 'loglevel = "debug"\n' >> "$p/gunicorn.conf.py"
run "$p"; expect_code 0; expect_out "DJ-05 myproject/settings.py:11"; expect_out "DJ-05 start.sh:2"; expect_out "DJ-05 gunicorn.conf.py:"

tc TC-D12 "INFO 레벨 · DEBUG 키 · dev 파일은 경고하지 않는다 (DJ-05 과잉 경고 방지)"
p="$(mkproj)"; printf 'FLAGS = {"DEBUG": False, "level": "WARNING"}\n' >> "$p/myproject/settings.py"
put "$p" myproject/dev.py 'LOGGING = {"root": {"level": "DEBUG"}}\n'
run "$p"; expect_code 0; expect_no_out

tc TC-D13 "멀티 워커 + prometheus 인데 멀티프로세스 모드가 없으면 막는다 (DJ-06)"
p="$(mkproj)"; put "$p" start.sh 'exec gunicorn -c gunicorn.conf.py myproject.wsgi:application\n'
run "$p"; expect_code 2; expect_out "DJ-06 gunicorn.conf.py:2"
p="$(mkproj)"; put "$p" start.sh 'exec gunicorn --workers 3 myproject.wsgi:application\n'; rm "$p/gunicorn.conf.py"
run "$p"; expect_code 2; expect_out "DJ-06 start.sh:1"

tc TC-D14 "포트 범위 방식 · 워커 1개는 막지 않는다 (DJ-06 과잉 차단 방지)"
p="$(mkproj)"; put "$p" start.sh 'exec gunicorn -c gunicorn.conf.py myproject.wsgi:application\n'
printf 'PROMETHEUS_METRICS_EXPORT_PORT_RANGE = range(8001, 8050)\n' >> "$p/myproject/settings.py"
run "$p"; expect_code 0; expect_not "DJ-06"
p="$(mkproj)"; put "$p" start.sh 'exec gunicorn --workers 1 myproject.wsgi:application\n'; rm "$p/gunicorn.conf.py"
run "$p"; expect_code 0; expect_not "DJ-06"

tc TC-D15 "멀티프로세스 모드인데 mark_process_dead 가 없으면 경고한다 (DJ-07)"
p="$(mkproj)"; printf 'workers = 4\n' > "$p/gunicorn.conf.py"
run "$p"; expect_code 0; expect_out "⚠️ DJ-07"

tc TC-D16 "서버 측 계측이 없으면 경고한다 (DJ-08)"
p="$TMP/noinst"; put "$p" requirements.txt 'Django\n'; put "$p" app/settings.py 'DEBUG = False\n'
run "$p"; expect_code 0; expect_out "DJ-08 ."; expect_out "서버 측 계측이 없다"

tc TC-D17 "django-prometheus 만 있고 in-flight 게이지가 없으면 경고한다 (DJ-08)"
p="$(mkproj)"; rm "$p/myproject/inflight.py"; sed -i.bak '/InFlightMiddleware/d' "$p/myproject/settings.py"; rm -f "$p/myproject/settings.py.bak"
run "$p"; expect_code 0; expect_out "DJ-08"; expect_out "in-flight 게이지가 없다"

tc TC-D18 "Before 가 처음이 아니거나 After 가 마지막이 아니면 경고한다 (DJ-09)"
p="$(mkproj)"; cat > "$p/myproject/settings.py" <<'PY'
DEBUG = False
MIDDLEWARE = [
    "myproject.inflight.InFlightMiddleware",
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",
    'django.middleware.common.CommonMiddleware',
]
PY
run "$p"; expect_code 0; expect_out "DJ-09 myproject/settings.py:2"; expect_out "PrometheusBeforeMiddleware 가"; expect_out "PrometheusAfterMiddleware 가"

tc TC-D19 "한 줄 목록 · 튜플 · 주석 처리한 항목에서 순서가 맞으면 경고하지 않는다 (DJ-09 과잉 경고 방지)"
p="$(mkproj)"; cat > "$p/myproject/settings.py" <<'PY'
DEBUG = False
MIDDLEWARE = ("django_prometheus.middleware.PrometheusBeforeMiddleware", "myproject.inflight.InFlightMiddleware", "django_prometheus.middleware.PrometheusAfterMiddleware")
OTHER = [
    # "x.Middleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",
    "y",
]
PY
run "$p"; expect_code 0; expect_no_out

tc TC-D20 "Gunicorn 워커 수를 정하지 않으면 경고한다 (DJ-11)"
p="$(mkproj)"; rm "$p/gunicorn.conf.py"; put "$p" start.sh 'exec gunicorn myproject.wsgi:application -b 0.0.0.0:8000\n'
run "$p"; expect_code 0; expect_out "DJ-11 start.sh:1"

tc TC-D21 "WEB_CONCURRENCY · conf 의 workers · 설치 명령만 있으면 경고하지 않는다 (DJ-11 과잉 경고 방지)"
p="$(mkproj)"; run "$p"; expect_not "DJ-11"
p="$(mkproj)"; rm "$p/gunicorn.conf.py"; put "$p" start.sh 'exec gunicorn myproject.wsgi:application\n'; put "$p" .env 'WEB_CONCURRENCY=1\n'
run "$p"; expect_not "DJ-11"
p="$(mkproj)"; rm "$p/gunicorn.conf.py" "$p/start.sh"; put "$p" Dockerfile 'RUN pip install gunicorn myproject.wsgi:application\n'
run "$p"; expect_not "DJ-11"

tc TC-D22 "ASGI 인데 CONN_MAX_AGE 가 0 이 아니면 경고한다 (DJ-12)"
p="$(mkproj)"; put "$p" start.sh 'export PROMETHEUS_MULTIPROC_DIR=/tmp/p\nexec gunicorn -c gunicorn.conf.py myproject.asgi:application -k uvicorn_worker.UvicornWorker\n'
printf 'DATABASES["default"]["CONN_MAX_AGE"] = None\n' >> "$p/myproject/settings.py"
run "$p"; expect_code 0; expect_out "DJ-12 myproject/settings.py:9"; expect_out "DJ-12 myproject/settings.py:11"

tc TC-D23 "WSGI 의 CONN_MAX_AGE · ASGI 의 CONN_MAX_AGE 0 은 경고하지 않는다 (DJ-12 과잉 경고 방지)"
p="$(mkproj)"; run "$p"; expect_not "DJ-12"
p="$(mkproj)"; put "$p" start.sh 'export PROMETHEUS_MULTIPROC_DIR=/tmp/p\nexec uvicorn myproject.asgi:application --workers 4\n'
sed -i.bak 's/"CONN_MAX_AGE": 60/"CONN_MAX_AGE": 0/' "$p/myproject/settings.py"; rm -f "$p/myproject/settings.py.bak"
run "$p"; expect_not "DJ-12"

tc TC-D24 ".venv · site-packages · tests · 테스트 파일은 보지 않는다"
p="$(mkproj)"; put "$p" .venv/lib/x/settings.py 'DEBUG = True\n'; put "$p" lib/site-packages/a/settings.py 'DEBUG = True\n'
put "$p" myproject/test_settings_case.py 'DEBUG = True\n'; put "$p" myproject/conftest.py 'DEBUG = True\n'; put "$p" tests/run.sh 'python manage.py runserver\n'
run "$p"; expect_code 0; expect_no_out

tc TC-D25 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
p="$TMP/repo/.claude/worktrees/w1"; mkdir -p "$p"; cp -R "$(mkproj)/." "$p/"
sed -i.bak 's/^DEBUG = False/DEBUG = True/' "$p/myproject/settings.py"; rm -f "$p/myproject/settings.py.bak"
run "$p"; expect_code 2; expect_out "DJ-02"

tc TC-D26 "디렉터리가 아니면 오류 1"
run "$TMP/none"; expect_code 1

# --- B. 훅 -------------------------------------------------------------------
BAD="$(mkproj)"; sed -i.bak 's/^DEBUG = False/DEBUG = True/' "$BAD/myproject/settings.py"; rm -f "$BAD/myproject/settings.py.bak"
CLEAN="$(mkproj)"

tc TC-D30 "k6 run 이면 additionalContext 로 알리고 막지 않는다"
run_hook "$BAD" "$(payload_bash 'k6 run --summary-export out.json load.js')"; expect_code 0
expect_out '"additionalContext"'; expect_out "DJ-02"; expect_not '"deny"'

tc TC-D31 "docker run … grafana/k6 · 환경 변수 접두 · 경로 · 다른 부하 도구도 알린다"
for c in 'docker run --rm -i grafana/k6 run - <load.js' 'BASE_URL=http://localhost:8000 k6 run load.js' 'cd perf && ./bin/k6 run a.js' 'locust -f locustfile.py --headless' 'wrk -t2 -c50 -d30s http://localhost:8000/' 'hey -z 10s http://localhost:8000/' 'echo x; ab -n 100 http://localhost:8000/' 'vegeta attack -rate=50 < t.txt' 'oha -z 10s http://localhost:8000/'; do
  run_hook "$BAD" "$(payload_bash "$c")"; expect_code 0; expect_out "DJ-02"
done

tc TC-D32 "부하 도구가 아닌 명령은 조용히 통과한다"
for c in 'ls -la' 'echo k6 run load.js' 'cat locustfile.py' 'python manage.py runserver' 'grep -r hey .' 'pip install locust'; do
  run_hook "$BAD" "$(payload_bash "$c")"; expect_code 0; expect_no_out
done

tc TC-D33 "규칙을 지킨 프로젝트면 부하 명령이어도 조용하다"
run_hook "$CLEAN" "$(payload_bash 'k6 run load.js')"; expect_code 0; expect_no_out

tc TC-D34 "빈 입력은 통과한다"
run_hook "$BAD" ""; expect_code 0; expect_no_out

tc TC-D35 "PostToolUse · Bash 가 아닌 도구는 보지 않는다"
run_hook "$BAD" "$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: "k6 run a.js"}}')"; expect_code 0; expect_no_out
run_hook "$BAD" "$(jq -n '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: "k6 run"}}')"; expect_code 0; expect_no_out

tc TC-D36 "CLAUDE_PROJECT_DIR 가 없으면 입력의 cwd 를 본다"
if [ "$TC_ON" = 1 ]; then
  OUT="$(jq -n --arg d "$BAD" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, tool_input: {command: "k6 run a.js"}}' | env -u CLAUDE_PROJECT_DIR "$SCRIPT" 2>&1)"; CODE=$?
fi
expect_code 0; expect_out "DJ-02"

flush_tc
echo ""
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
