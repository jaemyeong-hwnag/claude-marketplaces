#!/usr/bin/env bash
# scripts/fastapi-stress-config-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/fastapi-stress-config-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/fastapi-stress-tc.XXXXXX")"
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
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1 < /dev/null)"; CODE=$?; }
# 프로젝트 디렉터리를 지정해 훅을 부른다
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_count() { [ "$TC_ON" = 1 ] || return 0; local n; n="$(printf '%s\n' "$OUT" | grep -cF -- "$1")"; [ "$n" = "$2" ] || fail_tc "'$1' $n 건 (기대 $2)"; }

# --- 픽스처 ------------------------------------------------------------------
# 규칙을 지키는 FastAPI 프로젝트. TC 마다 한 곳만 깨뜨린다
CLEAN_MAIN='import asyncio
import time

from fastapi import FastAPI
from prometheus_client import Histogram
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(
    title="order",
    debug=False,
)
Instrumentator(
    should_instrument_requests_inprogress=True,
    excluded_handlers=["/metrics"],
).instrument(app).expose(app)
LATENCY = Histogram("order_duration_seconds", "주문 지연")


@app.get("/orders")
def orders():
    time.sleep(0.01)
    return []


@app.get("/stream")
async def stream():
    await asyncio.sleep(0.01)
    return {}
'
proj() { # 새 프로젝트 디렉터리 → 경로
  local d; d="$(mktemp -d "$TMP/p.XXXXXX")"
  mkdir -p "$d/app"
  printf 'fastapi[standard]\nprometheus-fastapi-instrumentator\n' > "$d/requirements.txt"
  printf '%s' "$CLEAN_MAIN" > "$d/app/main.py"
  printf 'FROM python:3.13-slim\nCMD ["fastapi", "run", "app/main.py", "--workers", "1"]\n' > "$d/Dockerfile"
  printf '%s' "$d"
}
put() { mkdir -p "$(dirname "$1")"; printf '%b' "$2" > "$1"; }
bash_payload() { jq -n --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'; }

echo "python-fastapi-stress-test 회귀 테스트"

# --- A. CLI 조항 -------------------------------------------------------------
tc TC-F01 "규칙을 지킨 프로젝트는 조용히 통과한다"
d="$(proj)"; run "$d"; expect_code 0; expect_no_out

tc TC-F02 "FastAPI 프로젝트가 아니면 보지 않는다"
d="$TMP/flask"; put "$d/requirements.txt" 'flask\n'; put "$d/Dockerfile" 'CMD uvicorn app:app --reload\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F03 "Dockerfile exec 형식의 fastapi dev 를 막는다 (FAS-01)"
d="$(proj)"; put "$d/Dockerfile" 'FROM python:3.13-slim\nCMD ["fastapi", "dev", "app/main.py", "--host", "0.0.0.0"]\n'
run "$d"; expect_code 2; expect_out "❌ FAS-01 Dockerfile:2"

tc TC-F04 "uvicorn --reload · uvicorn.run(reload=True) · gunicorn --reload · 셸의 fastapi dev 를 막는다 (FAS-01)"
d="$(proj)"
put "$d/docker-compose.yml" 'services:\n  api:\n    command: uvicorn app.main:app --host 0.0.0.0 --reload\n'
put "$d/app/serve.py" 'import uvicorn\nuvicorn.run("app.main:app", host="0.0.0.0", reload=True)\n'
put "$d/Procfile" 'web: gunicorn app.main:app -k uvicorn_worker.UvicornWorker --reload\n'
put "$d/start.sh" 'exec fastapi dev app/main.py\n'
run "$d"; expect_code 2
expect_out "FAS-01 docker-compose.yml:3"; expect_out "FAS-01 app/serve.py:2"; expect_out "FAS-01 Procfile:1"; expect_out "FAS-01 start.sh:1"

tc TC-F05 "주석 · reload=False · fastapi run · 문서 속 명령은 막지 않는다 (FAS-01 과잉 차단 방지)"
d="$(proj)"
put "$d/Dockerfile" 'FROM python:3.13-slim\n# 개발: fastapi dev app/main.py\nCMD ["fastapi", "run", "app/main.py"]\n'
put "$d/app/serve.py" 'import uvicorn\nuvicorn.run("app.main:app", reload=False)\n'
put "$d/README.md" 'uvicorn app.main:app --reload\n'
put "$d/start.sh" 'fastapi-devtools check\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F06 "워커가 여럿이고 prometheus 를 쓰는데 PROMETHEUS_MULTIPROC_DIR 가 없으면 막는다 (FAS-02)"
d="$(proj)"
put "$d/Dockerfile" 'CMD ["fastapi", "run", "app/main.py", "--workers", "4"]\n'
put "$d/run.sh" 'gunicorn app.main:app -w 8 -k uvicorn_worker.UvicornWorker\n'
put "$d/k8s.yaml" 'env:\n  - name: WEB_CONCURRENCY\n    value: "4"\n'
put "$d/.env" 'WEB_CONCURRENCY=12\n'
put "$d/gunicorn.conf.py" 'import multiprocessing\nworkers = multiprocessing.cpu_count() * 2 + 1\n'
run "$d"; expect_code 2
expect_out "FAS-02 Dockerfile:1"; expect_out "FAS-02 run.sh:1"; expect_out "FAS-02 .env:1"; expect_out "FAS-02 gunicorn.conf.py:2"

tc TC-F07 "멀티프로세스 디렉터리가 있거나 · 워커 1 · prometheus 없음이면 막지 않는다 (FAS-02 과잉 차단 방지)"
d="$(proj)"; put "$d/Dockerfile" 'ENV PROMETHEUS_MULTIPROC_DIR=/tmp/mp\nCMD ["fastapi", "run", "app/main.py", "--workers", "4"]\n'
run "$d"; expect_code 0; expect_not "FAS-02"
d="$(proj)"; put "$d/start.sh" 'uvicorn app.main:app --workers 1\nuvicorn app.main:app --workers "$WORKERS"\n'
run "$d"; expect_code 0; expect_not "FAS-02"
d="$TMP/noprom"; put "$d/requirements.txt" 'fastapi\n'; put "$d/app/main.py" 'from fastapi import FastAPI\nfrom opentelemetry import trace\napp = FastAPI()\n'
put "$d/Dockerfile" 'CMD ["fastapi", "run", "app/main.py", "--workers", "4"]\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F08 "Gunicorn + 멀티프로세스인데 mark_process_dead 가 없으면 경고한다 (FAS-03)"
d="$(proj)"; put "$d/run.sh" 'export PROMETHEUS_MULTIPROC_DIR=/tmp/mp\ngunicorn app.main:app -w 4 -k uvicorn_worker.UvicornWorker\n'
run "$d"; expect_code 0; expect_out "⚠️ FAS-03 run.sh:2"; expect_not "FAS-02"

tc TC-F09 "child_exit 에서 mark_process_dead 를 부르면 경고하지 않는다 (FAS-03 과잉 경고 방지)"
d="$(proj)"; put "$d/run.sh" 'export PROMETHEUS_MULTIPROC_DIR=/tmp/mp\ngunicorn app.main:app -c gunicorn.conf.py -w 4 -k uvicorn_worker.UvicornWorker\n'
put "$d/gunicorn.conf.py" 'from prometheus_client import multiprocess\n\ndef child_exit(server, worker):\n    multiprocess.mark_process_dead(worker.pid)\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F10 "FastAPI(debug=True) 한 줄 · 여러 줄 · app.debug = True 를 경고한다 (FAS-04)"
d="$(proj)"; put "$d/app/a.py" 'from fastapi import FastAPI\napp = FastAPI(debug=True)\n'
put "$d/app/b.py" 'from fastapi import FastAPI\napi = FastAPI(\n    title="b",\n    debug=True,\n)\n'
put "$d/app/c.py" 'from app.main import app\napp.debug = True\n'
run "$d"; expect_code 0; expect_out "FAS-04 app/a.py:2"; expect_out "FAS-04 app/b.py:4"; expect_out "FAS-04 app/c.py:2"

tc TC-F11 "debug=False · 변수 · 다른 호출의 debug=True 는 경고하지 않는다 (FAS-04 과잉 경고 방지)"
d="$(proj)"; put "$d/app/a.py" 'from fastapi import FastAPI\napp = FastAPI(debug=settings.debug)\nlogging.basicConfig(debug=True)\nx = FastAPI(title="x")\nconfigure(debug=True)\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F12 "로그 레벨 debug · trace 를 경고한다 (FAS-05)"
d="$(proj)"
put "$d/start.sh" 'uvicorn app.main:app --log-level debug\n'
put "$d/Dockerfile" 'CMD ["uvicorn", "app.main:app", "--log-level", "trace"]\n'
put "$d/app/serve.py" 'uvicorn.run(app, log_level="DEBUG")\n'
put "$d/.env.prod" 'UVICORN_LOG_LEVEL=debug\n'
put "$d/gunicorn.conf.py" 'loglevel = "debug"\n'
run "$d"; expect_code 0
expect_out "FAS-05 start.sh:1"; expect_out "FAS-05 Dockerfile:1"; expect_out "FAS-05 app/serve.py:1"; expect_out "FAS-05 .env.prod:1"; expect_out "FAS-05 gunicorn.conf.py:1"

tc TC-F13 "로그 레벨 info · warning 과 debug 라는 단어는 경고하지 않는다 (FAS-05 과잉 경고 방지)"
d="$(proj)"; put "$d/start.sh" 'uvicorn app.main:app --log-level warning\n'
put "$d/app/serve.py" 'uvicorn.run(app, log_level="info")\nlogger.debug("debug")\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F14 "uvicorn.workers.UvicornWorker 를 경고한다 (FAS-06)"
d="$(proj)"; put "$d/Procfile" 'web: gunicorn app.main:app -k uvicorn.workers.UvicornWorker\n'
run "$d"; expect_code 0; expect_out "⚠️ FAS-06 Procfile:1"

tc TC-F15 "uvicorn_worker.UvicornWorker 는 경고하지 않는다 (FAS-06 과잉 경고 방지)"
d="$(proj)"; put "$d/Procfile" 'web: gunicorn app.main:app -k uvicorn_worker.UvicornWorker\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F16 "async def 안의 time.sleep · requests · urlopen 을 경고한다 (FAS-07)"
d="$(proj)"; put "$d/app/slow.py" 'import time, requests\n\n@app.get("/a")\nasync def a():\n    time.sleep(0.1)\n    if True:\n        r = requests.get("http://x")\n    return urllib.request.urlopen("http://y")\n'
run "$d"; expect_code 0; expect_out "FAS-07 app/slow.py:5"; expect_out "FAS-07 app/slow.py:7"; expect_out "FAS-07 app/slow.py:8"

tc TC-F17 "def 엔드포인트 · async 안의 중첩 def · 블록 밖 · 테스트 파일 · 주석은 경고하지 않는다 (FAS-07 과잉 경고 방지)"
d="$(proj)"; put "$d/app/ok.py" 'import time\n\nasync def a():\n    def work():\n        time.sleep(1)\n    # time.sleep(1)\n    await asyncio.sleep(0.1)\n    return await run_in_threadpool(work)\n\ntime.sleep(0)\n\ndef b():\n    time.sleep(0.1)\n    session.requests.get("x")\n'
put "$d/tests/test_api.py" 'async def test_a():\n    time.sleep(0.1)\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F18 "계측이 없거나 instrumentator 에 in-flight 가 꺼져 있으면 경고한다 (FAS-08)"
d="$TMP/nometric"; put "$d/pyproject.toml" '[project]\ndependencies = ["fastapi"]\n'; put "$d/app/main.py" 'from fastapi import FastAPI\napp = FastAPI()\n'
run "$d"; expect_code 0; expect_out "⚠️ FAS-08 ."
d="$(proj)"; put "$d/app/main.py" 'from fastapi import FastAPI\nfrom prometheus_fastapi_instrumentator import Instrumentator\napp = FastAPI()\nInstrumentator().instrument(app).expose(app)\n'
run "$d"; expect_code 0; expect_out "FAS-08 app/main.py:4"; expect_out "should_instrument_requests_inprogress"

tc TC-F19 "prometheus_client · OpenTelemetry 를 직접 쓰면 계측 없음으로 보지 않는다 (FAS-08 과잉 경고 방지)"
d="$TMP/direct"; put "$d/requirements.txt" 'fastapi\nprometheus-client\n'; put "$d/app/main.py" 'from fastapi import FastAPI\nfrom prometheus_client import Gauge\napp = FastAPI()\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F20 "지연을 Summary 로 재면 경고한다 (FAS-09)"
d="$(proj)"; put "$d/app/m.py" 'from prometheus_client import Summary\nREQ = Summary("request_latency_seconds", "지연")\nDB = Summary( "db_query_duration", "x")\n'
run "$d"; expect_code 0; expect_out "FAS-09 app/m.py:2"; expect_out "FAS-09 app/m.py:3"

tc TC-F21 "Histogram · 크기를 재는 Summary 는 경고하지 않는다 (FAS-09 과잉 경고 방지)"
d="$(proj)"; put "$d/app/m.py" 'REQ = Histogram("request_latency_seconds", "지연")\nSIZE = Summary("response_size_bytes", "크기")\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F22 ".venv · node_modules · site-packages · build 아래는 보지 않는다"
d="$(proj)"
put "$d/.venv/lib/x.py" 'uvicorn.run(app, reload=True)\n'
put "$d/node_modules/x/run.sh" 'fastapi dev a.py\n'
put "$d/lib/site-packages/y.py" 'app = FastAPI(debug=True)\n'
put "$d/build/Dockerfile" 'CMD fastapi dev a.py\n'
run "$d"; expect_code 0; expect_no_out

tc TC-F23 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
d="$TMP/.claude/worktrees/1-x"; mkdir -p "$d"; cp -R "$(proj)/." "$d/"
put "$d/start.sh" 'fastapi dev app/main.py\n'
run "$d"; expect_code 2; expect_out "FAS-01 start.sh:1"

tc TC-F24 "없는 디렉터리는 오류 1"
run "$TMP/nope"; expect_code 1

tc TC-F25 "이 저장소 전체가 통과한다"
run "$REPO_ROOT"; expect_code 0

# --- B. 훅 -------------------------------------------------------------------
BAD="$(proj)"; put "$BAD/Dockerfile" 'CMD ["fastapi", "dev", "app/main.py"]\n'
GOOD="$(proj)"

tc TC-F30 "부하 명령이면 위반을 additionalContext 로 알리고 막지 않는다"
run_hook "$BAD" "$(bash_payload 'k6 run --summary-export out.json load.js')"; expect_code 0
expect_out '"additionalContext"'; expect_out "FAS-01"; expect_out '"PreToolUse"'

tc TC-F31 "부하 도구를 모두 알아본다 (docker grafana/k6 · 경로 · 환경 변수 · 파이프 뒤 포함)"
for c in 'docker run --rm -i --network host grafana/k6 run - < s.js' 'locust -f locustfile.py --headless' 'jmeter -n -t plan.jmx' \
         './gatling.sh -s Sim' 'wrk -t4 -c64 http://x' 'wrk2 -R 100 http://x' 'echo "GET http://x" | vegeta attack -rate 100' \
         'hey -z 10s http://x' 'ab -n 100 http://x/' 'oha -z 10s http://x' 'npx artillery run a.yml' 'autocannon -c 10 http://x' \
         'cd load && K6_WEB_DASHBOARD=true ./bin/k6 run a.js' 'sudo k6 run a.js'; do
  run_hook "$BAD" "$(bash_payload "$c")"; expect_code 0; expect_out "FAS-01"
done

tc TC-F32 "부하 도구가 아닌 명령은 조용히 통과한다"
for c in 'ls -la' 'grep ab notes.txt' 'echo hey' 'pip install locust' 'k6 version' 'docker run --rm python:3.13-slim python -V' 'git log --oneline'; do
  run_hook "$BAD" "$(bash_payload "$c")"; expect_code 0; expect_no_out
done

tc TC-F33 "규칙을 지킨 프로젝트에서는 부하 명령도 조용히 통과한다"
run_hook "$GOOD" "$(bash_payload 'k6 run load.js')"; expect_code 0; expect_no_out

tc TC-F34 "FastAPI 프로젝트가 아니면 부하 명령도 조용히 통과한다"
run_hook "$TMP/flask" "$(bash_payload 'k6 run load.js')"; expect_code 0; expect_no_out

tc TC-F35 "Bash 가 아닌 도구 · PostToolUse 는 보지 않는다"
run_hook "$BAD" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"a","content":"k6 run a.js"}}'; expect_code 0; expect_no_out
run_hook "$BAD" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"k6 run a.js"}}'; expect_code 0; expect_no_out

tc TC-F36 "빈 입력 · 명령 없는 입력은 통과한다"
run_hook "$BAD" ''; expect_code 0; expect_no_out
run_hook "$BAD" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}'; expect_code 0; expect_no_out

tc TC-F37 "CLAUDE_PROJECT_DIR 가 없으면 입력의 cwd 를 검사한다"
if [ "$TC_ON" = 1 ]; then
  OUT="$(jq -n --arg d "$BAD" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, tool_input: {command: "k6 run a.js"}}' \
    | env -u CLAUDE_PROJECT_DIR "$SCRIPT" 2>&1)"; CODE=$?
fi
expect_code 0; expect_out "FAS-01"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
