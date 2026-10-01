#!/usr/bin/env bash
# common-stress-test 스크립트들의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
S="$PLUGIN_ROOT/scripts"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/common-stress-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-7s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-7s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; local s="$1"; shift; OUT="$("$S/$s" "$@" 2>&1)"; CODE=$?; }
run_stdin() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$2" | "$S/$1" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
# 허용(0)/차단(2) 을 명령 여러 개에 대해
target_codes() { # $1=기대 코드, 나머지=명령
  [ "$TC_ON" = 1 ] || return 0
  local want="$1" c; shift
  for c in "$@"; do "$S/stress-target-validate.sh" "$c" >/dev/null 2>&1; [ "$?" = "$want" ] || fail_tc "기대 $want: $c"; done
}
put() { mkdir -p "$(dirname "$TMP/$1")"; printf '%b' "$2" > "$TMP/$1"; printf '%s' "$TMP/$1"; }
bash_hook() { jq -n --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
post_hook() { jq -n --arg p "$1" --arg e "${2:-PostToolUse}" '{hook_event_name:$e,tool_name:"Write",tool_input:{file_path:$p}}'; }

# --- 픽스처 ------------------------------------------------------------------
K6_OPEN="import http from 'k6/http';\nexport const options = {\n  summaryTrendStats: ['avg','p(95)','p(99)'],\n  scenarios: { s: { executor: 'constant-arrival-rate', rate: 100, timeUnit: '1s', duration: '1m', preAllocatedVUs: 100, maxVUs: 1000 } },\n  thresholds: { http_req_failed: ['rate<0.01'], http_req_duration: ['p(99)<300'] },\n};\nexport default function () { http.get('http://app:8080/'); }\n"
K6_CLOSED="import http from 'k6/http';\nimport { sleep } from 'k6';\nexport const options = { vus: 10, duration: '1m' };\nexport default function () { http.get('http://app:8080/'); sleep(1); }\n"
GAT_OPEN='class S extends Simulation {\n  setUp(scn.inject(constantUsersPerSec(50).during(60))).assertions(global().responseTime().percentile(99.0).lt(300));\n}\n'
GAT_CLOSED='class S extends Simulation {\n  setUp(scn.inject(constantConcurrentUsers(10).during(60)));\n}\n'
STEPS_OPEN="load,throughput,avg_ms,p50_ms,p95_ms,p99_ms,max_ms,error_rate,dropped,inflight
50,49.989,21.567,21.388,23.229,25.083,28.732,0,0,
100,99.891,21.487,21.324,22.969,24.712,28.493,0,0,
150,149.847,21.678,21.359,23.787,27.495,43.812,0,0,
180,179.780,21.724,21.394,24.168,27.55,33.321,0,0,
200,188.605,340.148,364.021,552.202,568.952,580.772,0,65,
220,188.411,731.554,731.377,1301.056,1355.507,1381.601,0,214,
260,183.984,1399.344,1531.996,2131.196,2142.227,2151.379,0,747,
"

echo "common-stress-test 회귀 테스트"

echo "A. ST-01 대상 호스트"
tc TC-S01 "명령 안의 공용 호스트 URL 을 막는다"
run stress-target-validate.sh 'k6 run -e BASE_URL=https://api.example.com t.js'
expect_code 2; expect_out "ST-01"; expect_out "api.example.com"; expect_out "STRESS_TEST_ALLOWED_HOSTS"

tc TC-S02 "루프백 · 사설 IP · 점 없는 이름 · 예약 도메인은 허용한다"
target_codes 0 'k6 run -e BASE_URL=http://localhost:8080 t.js' 'hey -n 10 http://127.0.0.1:8080/' 'wrk -c10 http://[::1]:8080/' \
  'oha http://10.1.2.3/' 'ab -n 10 http://172.20.0.5/' 'ab -n 10 http://192.168.0.10/' 'wrk http://app:8080/' \
  'hey http://svc.local/' 'hey http://api.test/' 'hey http://api.internal/' 'hey http://host.docker.internal:8080/' 'hey http://web.localhost/'

tc TC-S03 "172.32 · 공인 IP 는 사설이 아니다"
target_codes 2 'hey http://172.32.0.1/' 'hey http://8.8.8.8/'

tc TC-S04 "스킴 없는 URL · HOST 변수 대입도 본다"
target_codes 2 'BASE_URL=prod.example.com:443 k6 run t.js' 'k6 run -e TARGET_HOST=shop.example.com t.js'
target_codes 0 'BASE_URL=app:8080 k6 run t.js' 'docker compose run --rm -e BASE_URL=app k6'

tc TC-S05 "vegeta 는 파이프 앞의 URL 을 본다"
target_codes 2 'echo "GET https://shop.example.com/" | vegeta attack -rate 100 | vegeta report'

tc TC-S06 "locust --host 와 -f 없는 locustfile.py 를 본다"
target_codes 2 'locust --headless --host https://prod.example.com'
mkdir -p "$TMP/lp"; printf 'from locust import HttpUser\nclass U(HttpUser):\n    host = "https://prod.example.com"\n' > "$TMP/lp/locustfile.py"
if [ "$TC_ON" = 1 ]; then OUT="$(cd "$TMP/lp" && CLAUDE_PROJECT_DIR="$TMP/lp" "$S/stress-target-validate.sh" 'locust --headless -u 10' 2>&1)"; CODE=$?; expect_code 2; fi

tc TC-S07 "명령이 가리키는 스크립트 안의 URL 을 보고, import 줄은 보지 않는다"
F1="$(put s/bad.js "import http from 'k6/http';\nimport { x } from 'https://jslib.k6.io/x.js';\nexport default function () { http.get('https://api.example.com/'); }\n")"
F2="$(put s/ok.js "import http from 'k6/http';\nimport { x } from 'https://jslib.k6.io/x.js';\nexport default function () { http.get('http://app:8080/'); }\n")"
target_codes 2 "k6 run $F1"
target_codes 0 "k6 run $F2"

tc TC-S08 "JMX 의 HTTPSampler.domain 을 본다"
F3="$(put s/plan.jmx '<stringProp name="HTTPSampler.domain">api.example.com</stringProp>\n')"
F4="$(put s/plan2.jmx '<stringProp name="HTTPSampler.domain">${HOST}</stringProp>\n')"
target_codes 2 "jmeter -n -t $F3"
target_codes 0 "jmeter -n -t $F4"

tc TC-S09 "STRESS_TEST_ALLOWED_HOSTS — 정확한 이름 · 앞 와일드카드"
if [ "$TC_ON" = 1 ]; then
  STRESS_TEST_ALLOWED_HOSTS="staging.example.com, *.perf.example.com" "$S/stress-target-validate.sh" 'hey https://staging.example.com/' >/dev/null 2>&1 || fail_tc "정확한 이름이 막혔다"
  STRESS_TEST_ALLOWED_HOSTS="*.perf.example.com" "$S/stress-target-validate.sh" 'hey https://a.perf.example.com/' >/dev/null 2>&1 || fail_tc "와일드카드가 막혔다"
  STRESS_TEST_ALLOWED_HOSTS="*.perf.example.com" "$S/stress-target-validate.sh" 'hey https://perf.example.com.evil.io/' >/dev/null 2>&1 && fail_tc "접미사가 다른 호스트가 통과했다"
fi

tc TC-S10 "부하 도구가 아닌 명령은 보지 않는다"
target_codes 0 'curl https://api.example.com' 'git commit -m "ab test https://x.example.com"' 'echo k6 run https://api.example.com' 'npm run k6:report'

tc TC-S11 "docker 이미지 · compose 서비스 · gatling 빌드 태스크도 부하 명령이다"
target_codes 2 'docker run --rm grafana/k6 run -e BASE_URL=https://api.example.com - <t.js' 'docker compose run --rm -e BASE_URL=api.example.com k6' './gradlew gatlingRun -DbaseUrl=https://api.example.com'

tc TC-S12 "훅 — 위반은 exit 2, 통과는 조용, 빈 입력 · 다른 도구는 통과"
run_stdin stress-target-validate.sh "$(bash_hook 'k6 run -e BASE_URL=https://api.example.com t.js')"
expect_code 2; expect_out "ST-01"
run_stdin stress-target-validate.sh "$(bash_hook 'k6 run -e BASE_URL=http://localhost:8080 t.js')"
expect_code 0; expect_no_out
run_stdin stress-target-validate.sh ""
expect_code 0; expect_no_out
run_stdin stress-target-validate.sh '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"x"}}'
expect_code 0; expect_no_out

echo "B. ST-02 ~ ST-06 부하 스크립트"
tc TC-S20 "규칙을 지킨 k6 스크립트는 경고가 없다"
F="$(put k/open.js "$K6_OPEN")"; run stress-script-validate.sh "$F"
expect_code 0; expect_out "부하 스크립트 1개, 경고 0건"

tc TC-S21 "k6 closed 모델 · thresholds · p99 없음 · closed 표시 주석"
F="$(put k/closed.js "$K6_CLOSED")"; run stress-script-validate.sh "$F"
expect_out "ST-02"; expect_out "ST-03"; expect_out "ST-04"; expect_not "ST-06"
F="$(put k/closed-ok.js "// stress-test: closed-model\n$K6_CLOSED")"; run stress-script-validate.sh "$F"
expect_not "ST-02"; expect_out "ST-03"

tc TC-S22 "k6 arrival-rate 의 maxVUs 없음(ST-05) · sleep(ST-06)"
F="$(put k/nomax.js "$(printf '%b' "$K6_OPEN" | sed 's/, maxVUs: 1000//; s/http.get(.http:\/\/app:8080\/.);/http.get("http:\/\/app:8080\/"); sleep(1);/')")"
run stress-script-validate.sh "$F"
expect_out "ST-05"; expect_out "ST-06"; expect_not "ST-02"

tc TC-S23 "Gatling — closed 주입 · assertions 없음, open + assertions 는 통과"
F="$(put g/Closed.scala "$GAT_CLOSED")"; run stress-script-validate.sh "$F"
expect_out "ST-02"; expect_out "ST-03"
F="$(put g/Open.scala "$GAT_OPEN")"; run stress-script-validate.sh "$F"
expect_out "경고 0건"

tc TC-S24 "Locust · JMeter 는 closed 루프라고 알린다"
F="$(put l/locustfile.py 'from locust import HttpUser, task\n')"; run stress-script-validate.sh "$F"
expect_out "ST-02"; expect_out "locust"
F="$(put j/p.jmx '<jmeterTestPlan/>\n')"; run stress-script-validate.sh "$F"
expect_out "ST-02"; expect_out "jmeter"

tc TC-S25 "부하 스크립트가 아닌 .js · .py · .java 는 보지 않는다"
put n/app.js "const http = require('http');\n" >/dev/null; put n/app.py 'import requests\n' >/dev/null; put n/App.java 'class App {}\n' >/dev/null
run stress-script-validate.sh "$TMP/n"
expect_out "부하 스크립트 0개"

tc TC-S26 "디렉터리 검사는 node_modules 를 건너뛴다"
put d/node_modules/x/t.js "$K6_CLOSED" >/dev/null; put d/load/t.js "$K6_OPEN" >/dev/null
run stress-script-validate.sh "$TMP/d"
expect_out "부하 스크립트 1개, 경고 0건"

tc TC-S27 "--strict 는 경고가 있으면 exit 2"
F="$(put k/strict.js "$K6_CLOSED")"; run stress-script-validate.sh --strict "$F"
expect_code 2

tc TC-S28 "훅 — PostToolUse 에서 additionalContext 로 알린다. PreToolUse · 비대상 파일은 조용"
F="$(put h/t.js "$K6_CLOSED")"
run_stdin stress-script-validate.sh "$(post_hook "$F")"
expect_code 0; expect_out '"additionalContext"'; expect_out "ST-02"
run_stdin stress-script-validate.sh "$(post_hook "$F" PreToolUse)"
expect_code 0; expect_no_out
F="$(put h/ok.js "$K6_OPEN")"; run_stdin stress-script-validate.sh "$(post_hook "$F")"
expect_code 0; expect_no_out
F="$(put h/readme.md '# x\n')"; run_stdin stress-script-validate.sh "$(post_hook "$F")"
expect_code 0; expect_no_out

echo "C. 결과 → 단계 CSV"
tc TC-S40 "k6 --summary-export"
F="$(put r/k6.json '{"metrics":{"http_reqs":{"count":2935,"rate":188.6},"http_req_duration":{"avg":340.1,"p(50)":364.0,"p(95)":552.2,"p(99)":568.9,"max":580.7},"http_req_failed":{"passes":0,"fails":2935,"value":0},"dropped_iterations":{"count":65}}}')"
run stress-step-generate.sh --load 200 "$F"
expect_code 0; expect_out "200,188.6,340.1,364.0,552.2,568.9,580.7,0,65,"

tc TC-S41 "k6 handleSummary 형식(.values) · p(50) 없으면 med"
F="$(put r/hs.json '{"metrics":{"http_reqs":{"values":{"rate":99.9}},"http_req_duration":{"values":{"avg":1.5,"med":1.2,"p(95)":2.5,"p(99)":11.5,"max":53}},"http_req_failed":{"values":{"rate":0.002}}}}')"
run stress-step-generate.sh --load 100 --inflight 0.2 "$F"
expect_out "100,99.9,1.5,1.2,2.5,11.5,53,0.002,0,0.2"

tc TC-S42 "Locust stats.csv 의 Aggregated 줄"
F="$(put r/out_stats.csv 'Type,Name,Request Count,Failure Count,Median Response Time,Average Response Time,Min Response Time,Max Response Time,Average Content Size,Requests/s,Failures/s,50%,66%,75%,80%,90%,95%,98%,99%,99.9%,99.99%,100%\nGET,/work,704,7,150,153.2,27.6,294.4,2.0,50.1,0.0,150,200,220,230,260,270,280,290,290,290,290\n,Aggregated,704,7,150,153.2,27.6,294.4,2.0,50.1,0.0,150,200,220,230,260,270,280,290,290,290,290\n')"
run stress-step-generate.sh --load 50 "$F"
expect_out "50,50.1,153.2,150,270,290,294.4,0.00994318"

tc TC-S43 "JMeter statistics.json 의 Total (errorPct 는 % 단위)"
F="$(put r/statistics.json '{"Total":{"sampleCount":1744,"errorCount":17,"errorPct":0.97,"meanResTime":21.9,"medianResTime":22.0,"maxResTime":49.0,"pct1ResTime":23.0,"pct2ResTime":24.0,"pct3ResTime":28.0,"throughput":175.3}}')"
run stress-step-generate.sh --load 4 "$F"
expect_out "4,175.3,21.9,22.0,24.0,28.0,49.0,0.0097,"

tc TC-S44 "Gatling 3.2 콘솔 형식"
F="$(put r/g32.txt '---- Global Information ----\n> request count                                        500 (OK=490    KO=10     )\n> max response time                                  14729 (OK=14729  KO=-     )\n> mean response time                                 12025 (OK=12025  KO=-     )\n> response time 50th percentile                      12409 (OK=12409  KO=-     )\n> response time 95th percentile                      13722 (OK=13722  KO=-     )\n> response time 99th percentile                      14398 (OK=14398  KO=-     )\n> mean requests/sec                                 21.739 (OK=21.739 KO=-     )\n')"
run stress-step-generate.sh --load 50 --tool gatling "$F"
expect_out "50,21.739,12025,12409,13722,14398,14729,0.02,"

tc TC-S45 "Gatling 3.16 콘솔 형식 (표 · 단위 표기)"
F="$(put r/g316.txt '---- Global Information ----|---Total---|-----OK----|----KO-----\n> request count                       |       500 |       490 |        10\n> max response time (ms)              |       180 |       180 |       150\n> mean response time (ms)             |        25 |        25 |        30\n> response time 50th percentile (ms)  |        22 |        22 |        25\n> response time 95th percentile (ms)  |        40 |        40 |        60\n> response time 99th percentile (ms)  |        90 |        90 |       140\n> mean throughput (rps)               |     49.95 |     48.95 |         1\n')"
run stress-step-generate.sh --load 50 --tool gatling "$F"
expect_out "50,49.95,25,22,40,90,180,0.02,"

tc TC-S46 "--load 없음 · 모르는 형식은 오류(1)"
run stress-step-generate.sh "$TMP/r/k6.json"
expect_code 1
F="$(put r/x.json '{"a":1}')"; run stress-step-generate.sh --load 1 "$F"
expect_code 1

echo "D. 단계 판정"
STEPS="$(put p/open.csv "$STEPS_OPEN")"
tc TC-S50 "실측 open 7단계 — 용량 · 처리량 knee · p99 knee 가 180"
run stress-report-generate.sh --model open --slo-p99 200 "$STEPS"
expect_code 0; expect_out "**180** (rps)"; expect_out "처리량 곡선의 knee: load **180**"; expect_out "p99 곡선의 knee: load **180**"; expect_out "❌ p99✗ 미달✗ dropped✗"

tc TC-S51 "--target — 합격 단계는 0, 불합격 2, 없는 단계 1"
run stress-report-generate.sh --slo-p99 200 --target 180 "$STEPS"; expect_code 0; expect_out "✅ 목표 부하 180 합격"
run stress-report-generate.sh --slo-p99 200 --target 200 "$STEPS"; expect_code 2
run stress-report-generate.sh --slo-p99 200 --target 999 "$STEPS"; expect_code 1

tc TC-S52 "dropped 단계를 경고한다 (ST-12)"
run stress-report-generate.sh "$STEPS"
expect_out "ST-12 load 200 에서 dropped 65"

tc TC-S53 "6단계 미만이면 knee · USL 을 계산하지 않는다 (ST-11)"
F="$(put p/few.csv "$(printf '%s\n' "$STEPS_OPEN" | head -5)")"
run stress-report-generate.sh "$F"
expect_out "ST-11"; expect_not "knee: load"

tc TC-S54 "USL — 알려진 계수(α 0.05 · β 0.001)를 되찾는다"
F="$(put p/usl.csv "$(awk 'BEGIN { print "load,throughput"; split("1 2 4 8 16 24 32 48 64", n, " "); for (i = 1; i <= 9; i++) { N = n[i]; printf "%d,%.4f\n", N, 100 * N / (1 + 0.05 * (N - 1) + 0.001 * N * (N - 1)) } }')")"
run stress-report-generate.sh --model closed "$F"
expect_out "α(경합) = 0.05"; expect_out "β(일관성) = 0.0010"; expect_out "N_max = √((1−α)/β) = **30.8**"; expect_not "R² 가 낮다"

tc TC-S55 "USL — 고정 상한처럼 모양이 다르면 R² 경고"
F="$(put p/cap.csv 'load,throughput,avg_ms\n1,44.8,22.1\n2,89.8,22.1\n3,132.5,22.4\n4,179.0,22.2\n6,185.9,32.1\n8,186.7,42.7\n12,185.5,64.4\n16,186.3,85.6\n24,186.3,128.2\n32,186.7,170.3\n')"
run stress-report-generate.sh --model closed "$F"
expect_out "R² 가 낮다"; expect_out "처리량 곡선의 knee: load **4**"

tc TC-S56 "Little — closed 실측은 맞고(경고 없음), in-flight 가 어긋나면 ST-13"
run stress-report-generate.sh --model closed "$TMP/p/cap.csv"
expect_out "## Little"; expect_not "ST-13"
F="$(put p/little.csv 'load,throughput,avg_ms,inflight\n100,100,20,2.0\n200,200,20,8.0\n')"
run stress-report-generate.sh --model open "$F"
expect_out "ST-13 Little 불일치 1단계"
F="$(put p/zero.csv 'load,throughput,avg_ms,inflight\n100,100,20,0\n')"
run stress-report-generate.sh --model open "$F"
expect_out "| ∞ |"; expect_out "ST-13 Little 불일치 1단계"

tc TC-S57 "열 순서가 달라도 이름으로 읽고, load · throughput 이 없으면 오류"
F="$(put p/order.csv 'p99_ms,throughput,load\n20,50,50\n')"
run stress-report-generate.sh --slo-p99 100 "$F"
expect_code 0; expect_out "| 50 | 50.0 |"
F="$(put p/bad.csv 'x,y\n1,2\n')"; run stress-report-generate.sh "$F"
expect_code 1

echo "E. ST-20 회귀 판정"
A="$(put m/a1 '101\n99\n103\n98\n100\n102\n97\n104\n')"; B="$(put m/b1 '108\n110\n107\n112\n109\n106\n111\n105\n')"
tc TC-S60 "명확한 회귀 — 정확 검정 p 가 scipy 와 같다 (0.0001554)"
run stress-regression-validate.sh "$A" "$B"
expect_code 2; expect_out "p=0.0001554 (정확"; expect_out "Cliff delta=+1.000 (큼)"; expect_out "ST-20"

tc TC-S61 "차이 없음은 0"
B2="$(put m/b2 '100\n101\n99\n103\n98\n102\n104\n97\n')"
run stress-regression-validate.sh "$A" "$B2"
expect_code 0; expect_out "유의한 회귀 없음"

tc TC-S62 "동률이 있으면 정규 근사 — scipy 와 같다 (U=3 · p=0.0181)"
A3="$(put m/a3 '10\n10\n11\n12\n12\n13\n')"; B3="$(put m/b3 '12\n13\n13\n14\n15\n15\n')"
run stress-regression-validate.sh "$A3" "$B3"
expect_code 2; expect_out "U=3 · p=0.0181 (정규 근사"

tc TC-S63 "--higher-is-better — 처리량 감소는 회귀, 증가는 개선"
run stress-regression-validate.sh --higher-is-better "$B" "$A"
expect_code 2
run stress-regression-validate.sh --higher-is-better "$A" "$B"
expect_code 0; expect_out "개선"

tc TC-S64 "유의해도 효과 크기가 작으면 회귀가 아니다"
run stress-regression-validate.sh --min-effect 1.1 "$A" "$B"
expect_code 0; expect_out "효과 크기가 1.1 미만"

tc TC-S65 "표본 5개 미만 · 숫자가 아닌 값은 오류(1)"
F="$(put m/few '1\n2\n3\n')"; run stress-regression-validate.sh "$F" "$B"
expect_code 1; expect_out "5개 이상"
F="$(put m/nan '1\n2\nx\n4\n5\n')"; run stress-regression-validate.sh "$F" "$B"
expect_code 1

flush_tc
echo ""
echo "통과 $PASS · 실패 $FAIL · 건너뜀 $SKIP"
[ "$FAIL" = 0 ]
