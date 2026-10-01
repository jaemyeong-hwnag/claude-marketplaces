#!/usr/bin/env bash
# scripts/express-stress-config-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/express-stress-config-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/express-stress-tc.XXXXXX")"
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
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1 </dev/null)"; CODE=$?; }
run_hook() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# --- 픽스처 ------------------------------------------------------------------
# 규칙을 지키는 프로젝트를 만들고, TC 마다 한 곳만 깨뜨린다
proj() { # → 새 프로젝트 경로 ($(...) 안에서 불리므로 카운터 대신 mktemp)
  local d; d="$(mktemp -d "$TMP/p.XXXXXX")"
  mkdir -p "$d/src"
  printf '%s\n' '{"name":"shop","scripts":{"start":"node src/server.js","dev":"nodemon --inspect src/server.js"},"dependencies":{"express":"^5.1.0","prom-client":"^15.1.3"}}' > "$d/package.json"
  printf 'FROM node:22-slim\nENV NODE_ENV=production\nCMD ["node", "src/server.js"]\n' > "$d/Dockerfile"
  cat > "$d/src/server.js" <<'JS'
const express = require('express');
const fs = require('node:fs');
const client = require('prom-client');
const duration = new client.Histogram({ name: 'http_server_request_duration_seconds', help: 'x' });
const app = express();
app.set('view engine', 'pug');
app.get('/orders', async (req, res) => res.json(await fs.promises.readFile('orders.json', 'utf8')));
app.listen(3000);
JS
  printf '%s' "$d"
}
set_json() { # $1=dir $2=jq 식
  local t; t="$(jq "$2" "$1/package.json")" && printf '%s\n' "$t" > "$1/package.json"
}
bash_payload() { jq -n --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'; }

echo "node-express-stress-test 회귀 테스트"

# --- A. CLI ------------------------------------------------------------------
tc TC-E01 "규칙을 지킨 프로젝트는 조용히 통과한다"
d="$(proj)"; run "$d"; expect_code 0; expect_no_out

tc TC-E02 "express 가 없는 프로젝트는 보지 않는다"
d="$(proj)"; set_json "$d" 'del(.dependencies.express)'; printf 'ENV NODE_ENV=development\n' >> "$d/Dockerfile"
run "$d"; expect_code 0; expect_no_out

tc TC-E03 "package.json 이 없으면 통과하고, 디렉터리가 아니면 오류다"
mkdir -p "$TMP/empty"; run "$TMP/empty"; expect_code 0; expect_no_out
run "$TMP/none"; expect_code 1

tc TC-E04 "start 스크립트의 NODE_ENV=development 를 막는다 (NEX-01)"
d="$(proj)"; set_json "$d" '.scripts.start = "NODE_ENV=development node src/server.js"'
run "$d"; expect_code 2; expect_out "NEX-01 package.json:scripts.start"

tc TC-E05 "Dockerfile ENV · compose environment 의 non-production 을 막는다 (NEX-01)"
d="$(proj)"; printf 'FROM node:22\nENV NODE_ENV development\nCMD ["node","src/server.js"]\n' > "$d/Dockerfile"
printf 'services:\n  api:\n    environment:\n      - NODE_ENV=staging\n' > "$d/docker-compose.yml"
run "$d"; expect_code 2; expect_out "NEX-01 Dockerfile:2"; expect_out "NEX-01 docker-compose.yml:4"; expect_out "NODE_ENV=staging"

tc TC-E06 "dev · local · test 변형 파일과 dev 스크립트는 보지 않는다 (NEX-01 · NEX-03 과잉 탐지 방지)"
d="$(proj)"; printf 'services:\n  api:\n    environment:\n      - NODE_ENV=development\n    command: nodemon src/server.js\n' > "$d/docker-compose.dev.yml"
printf 'FROM node:22\nENV NODE_ENV=test\n' > "$d/Dockerfile.test"
run "$d"; expect_code 0; expect_no_out

tc TC-E07 "NODE_ENV=production 이 어디에도 없으면 경고만 한다 (NEX-02)"
d="$(proj)"; printf 'FROM node:22\nCMD ["node","src/server.js"]\n' > "$d/Dockerfile"
run "$d"; expect_code 0; expect_out "NEX-02"; expect_not "❌"

tc TC-E08 "PM2 ecosystem 의 NODE_ENV production 으로 NEX-02 가 풀리고, env 의 development 는 위반으로 보지 않는다"
d="$(proj)"; rm "$d/Dockerfile"
printf "module.exports = { apps: [{ script: 'src/server.js', env: { NODE_ENV: 'development' }, env_production: { NODE_ENV: 'production' } }] };\n" > "$d/ecosystem.config.js"
run "$d"; expect_code 0; expect_no_out

tc TC-E09 "start 의 nodemon · node --watch · tsx watch 를 막는다 (NEX-03)"
d="$(proj)"; set_json "$d" '.scripts.start = "nodemon src/server.js" | .scripts.prod = "node --watch src/server.js" | .scripts.serve = "tsx watch src/server.ts"'
run "$d"; expect_code 2; expect_out "NEX-03 package.json:scripts.start"; expect_out "NEX-03 package.json:scripts.prod"; expect_out "NEX-03 package.json:scripts.serve"

tc TC-E10 "Dockerfile CMD · Procfile · PM2 watch: true 의 자동 리로드를 막는다 (NEX-03)"
d="$(proj)"; printf 'FROM node:22\nENV NODE_ENV=production\nCMD ["npx", "nodemon", "src/server.js"]\n' > "$d/Dockerfile"
printf 'web: node --watch src/server.js\n' > "$d/Procfile"
printf "module.exports = { apps: [{ script: 'src/server.js', watch: true }] };\n" > "$d/ecosystem.config.js"
run "$d"; expect_code 2; expect_out "NEX-03 Dockerfile:3"; expect_out "NEX-03 Procfile:1"; expect_out "NEX-03 ecosystem.config.js:1"

tc TC-E11 "--watch 와 비슷한 이름 · watch: false 는 막지 않는다 (NEX-03 과잉 탐지 방지)"
d="$(proj)"; set_json "$d" '.scripts.start = "node --watchdog-off src/server.js && echo nodemonitor"'
printf "module.exports = { apps: [{ script: 'src/server.js', watch: false, env: { NODE_ENV: 'production' } }] };\n" > "$d/ecosystem.config.js"
run "$d"; expect_code 0; expect_no_out

tc TC-E12 "프로파일러 · 추적 플래그를 막는다 (NEX-04)"
d="$(proj)"; set_json "$d" '.scripts.start = "node --cpu-prof src/server.js" | .scripts.prod = "clinic flame -- node src/server.js"'
printf 'FROM node:22\nENV NODE_ENV=production\nCMD ["node", "--trace-sync-io", "src/server.js"]\n' > "$d/Dockerfile"
run "$d"; expect_code 2; expect_out "NEX-04 package.json:scripts.start"; expect_out "NEX-04 package.json:scripts.prod"; expect_out "NEX-04 Dockerfile:3"

tc TC-E13 "--inspect 는 경고만 한다 (NEX-05)"
d="$(proj)"; set_json "$d" '.scripts.start = "node --inspect=0.0.0.0:9229 src/server.js"'
run "$d"; expect_code 0; expect_out "NEX-05 package.json:scripts.start"; expect_not "❌"

tc TC-E14 "dev 스크립트의 --inspect · 비슷한 플래그는 보지 않는다 (NEX-04 · NEX-05 과잉 탐지 방지)"
d="$(proj)"; set_json "$d" '.scripts.start = "node --profile-dir=x --inspector-off src/server.js"'
run "$d"; expect_not "NEX-04"; expect_not "NEX-05"

tc TC-E15 "DEBUG=express:* · router · * 를 막는다 (NEX-06)"
d="$(proj)"; printf 'FROM node:22\nENV NODE_ENV=production\nENV DEBUG=express:*\nCMD ["node","src/server.js"]\n' > "$d/Dockerfile"
printf 'services:\n  api:\n    environment:\n      DEBUG: "router"\n' > "$d/compose.yaml"
set_json "$d" '.scripts.start = "DEBUG=* node src/server.js"'
run "$d"; expect_code 2; expect_out "NEX-06 Dockerfile:3"; expect_out "NEX-06 compose.yaml:4"; expect_out "NEX-06 package.json:scripts.start"

tc TC-E16 "앱 네임스페이스만 켠 DEBUG 는 막지 않는다 (NEX-06 과잉 탐지 방지)"
d="$(proj)"; printf 'FROM node:22\nENV NODE_ENV=production\nENV DEBUG=shop:payment\nCMD ["node","src/server.js"]\n' > "$d/Dockerfile"
run "$d"; expect_code 0; expect_no_out

tc TC-E17 "view cache 를 끄면 막는다 (NEX-07)"
d="$(proj)"; printf "const express = require('express');\nconst app = express();\napp.disable('view cache');\napp.set(\"view cache\", false);\n" > "$d/src/views.js"
run "$d"; expect_code 2; expect_out "NEX-07 src/views.js:3"; expect_out "NEX-07 src/views.js:4"

tc TC-E18 "view cache 를 켜거나 주석에 쓴 것은 막지 않는다 (NEX-07 과잉 탐지 방지)"
d="$(proj)"; printf "const app = require('express')();\napp.enable('view cache');\n// app.disable('view cache');\n" > "$d/src/views.js"
run "$d"; expect_code 0; expect_no_out

tc TC-E19 "prom-client Summary 를 경고한다 (NEX-08)"
d="$(proj)"; printf "const client = require('prom-client');\nconst s = new client.Summary({ name: 'lat', help: 'x' });\nimport { Summary } from 'prom-client';\nconst t = new Summary({ name: 'b', help: 'b' });\n" > "$d/src/metrics.js"
run "$d"; expect_code 0; expect_out "NEX-08 src/metrics.js:2"; expect_out "NEX-08 src/metrics.js:4"

tc TC-E20 "prom-client 가 아닌 Summary 클래스는 경고하지 않는다 (NEX-08 과잉 탐지 방지)"
d="$(proj)"; printf "class Summary {}\nconst s = new Summary();\n" > "$d/src/report.js"
run "$d"; expect_code 0; expect_no_out

tc TC-E21 "라우트 파일의 *Sync 호출을 경고한다 (NEX-09)"
d="$(proj)"; printf "const fs = require('fs');\nconst router = require('express').Router();\nrouter.get('/a', (req, res) => res.send(fs.readFileSync('a.txt')));\n" > "$d/src/routes.js"
run "$d"; expect_code 0; expect_out "NEX-09 src/routes.js:3"; expect_out "readFileSync()"

tc TC-E22 "라우트가 없는 파일 · 테스트 · node_modules 의 *Sync 는 보지 않는다 (NEX-09 과잉 탐지 방지)"
d="$(proj)"; printf "const fs = require('fs');\nmodule.exports = JSON.parse(fs.readFileSync('c.json'));\n" > "$d/src/config.js"
mkdir -p "$d/test" "$d/node_modules/x"
printf "app.get('/', () => fs.readFileSync('x'));\n" > "$d/test/a.js"
printf "app.get('/', () => fs.readFileSync('x'));\n" > "$d/src/a.test.js"
printf "app.get('/', () => fs.readFileSync('x'));\napp.disable('view cache');\n" > "$d/node_modules/x/index.js"
run "$d"; expect_code 0; expect_no_out

tc TC-E23 "위반과 경고가 함께 있으면 둘 다 보고하고 2 로 끝난다"
d="$(proj)"; set_json "$d" '.scripts.start = "nodemon --inspect src/server.js"'
run "$d"; expect_code 2; expect_out "❌ NEX-03"; expect_out "⚠️  NEX-05"; expect_out "위반 1 · 경고 1"

# --- B. 훅 -------------------------------------------------------------------
BAD="$(proj)"; set_json "$BAD" '.scripts.start = "nodemon src/server.js"'
GOOD="$(proj)"

tc TC-E30 "k6 run 이면 위반을 additionalContext 로 알리고 막지 않는다"
run_hook "$BAD" "$(bash_payload 'k6 run load.js')"; expect_code 0
expect_out '"additionalContext"'; expect_out "NEX-03"; expect_not '"permissionDecision"'

tc TC-E31 "부하 도구 여러 형태를 알아본다 (docker grafana/k6 · npx autocannon · 환경 변수 · 경로 · 체인)"
for c in 'docker run --rm -i grafana/k6 run - < s.js' 'npx autocannon -c 50 http://localhost:3000' 'K6_OUT=json k6 run s.js' \
         './bin/wrk -t2 -c50 http://localhost:3000' 'cd perf && vegeta attack -rate=100 < t.txt' 'ab -n 1000 -c 10 http://x/' \
         'hey -z 10s http://x/' 'oha http://x/' 'locust -f l.py' 'jmeter -n -t plan.jmx' 'artillery run a.yml' 'mvn gatling:test'; do
  run_hook "$BAD" "$(bash_payload "$c")"
  [ "$TC_ON" = 1 ] && { printf '%s' "$OUT" | grep -qF "NEX-03" || fail_tc "부하 명령으로 못 봄: $c"; }
done

tc TC-E32 "부하 도구가 아닌 명령은 조용히 통과한다"
for c in 'npm test' 'echo hey there' 'grep -r k6 .' 'git log --grep wrk' 'cat ab.txt' 'k6 version' 'docker run node:22 node app.js'; do
  run_hook "$BAD" "$(bash_payload "$c")"
  [ "$TC_ON" = 1 ] && { [ "$CODE" = 0 ] && [ -z "$OUT" ] || fail_tc "조용히 통과해야 함: $c → $OUT"; }
done

tc TC-E33 "부하 명령이어도 프로젝트가 규칙을 지키면 조용하다"
run_hook "$GOOD" "$(bash_payload 'k6 run load.js')"; expect_code 0; expect_no_out

tc TC-E34 "빈 입력 · Bash 가 아닌 도구 · PostToolUse 는 통과한다"
run_hook "$BAD" ''; expect_code 0; expect_no_out
run_hook "$BAD" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"k6 run"}}'; expect_code 0; expect_no_out
run_hook "$BAD" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"k6 run a.js"}}'; expect_code 0; expect_no_out
run_hook "$BAD" 'not json'; expect_code 0; expect_no_out

tc TC-E35 "경고만 있는 프로젝트도 알린다"
W="$(proj)"; set_json "$W" '.scripts.start = "node --inspect src/server.js"'
run_hook "$W" "$(bash_payload 'k6 run load.js')"; expect_code 0; expect_out "경고 NEX-05"

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
