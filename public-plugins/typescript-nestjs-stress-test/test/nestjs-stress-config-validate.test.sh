#!/usr/bin/env bash
# scripts/nestjs-stress-config-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/nestjs-stress-config-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nestjs-stress-tc.XXXXXX")"
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
# 규칙을 지키는 프로젝트. TC 마다 새로 깔고 한 곳만 깨뜨린다
N=0
project() {
  N=$((N+1)); P="$TMP/p$N"; mkdir -p "$P/src"
  cat > "$P/package.json" <<'EOF'
{
  "name": "orders",
  "scripts": {
    "build": "nest build",
    "start": "nest start",
    "start:dev": "nest start --watch",
    "start:debug": "nest start --debug --watch",
    "start:prod": "node dist/main"
  },
  "dependencies": { "@nestjs/core": "^12.1.2", "@nestjs/common": "^12.1.2", "@willsoto/nestjs-prometheus": "^6.1.1", "prom-client": "^15.1.3" },
  "devDependencies": { "@nestjs/cli": "^12.0.8", "typescript": "^6.0.3" }
}
EOF
  printf 'FROM node:22-slim\nWORKDIR /app\nCOPY . .\nRUN npm ci && npx nest build\nCMD ["node", "dist/main"]\n' > "$P/Dockerfile"
  cat > "$P/src/main.ts" <<'EOF'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: ['error', 'warn', 'log'] });
  await app.listen(3000);
}
bootstrap();
EOF
  cat > "$P/src/app.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { PrometheusModule, makeGaugeProvider, makeHistogramProvider } from '@willsoto/nestjs-prometheus';

@Module({
  imports: [PrometheusModule.register()],
  providers: [
    makeHistogramProvider({ name: 'http_server_request_duration_seconds', help: 'd', labelNames: ['route'] }),
    makeGaugeProvider({ name: 'http_server_requests_in_flight', help: 'i' }),
  ],
})
export class AppModule {}
EOF
  cat > "$P/src/order.service.ts" <<'EOF'
import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class OrderService {
  private readonly logger = new Logger(OrderService.name);
  find(id: string) {
    this.logger.debug(`find ${id}`);
    return { id };
  }
}
EOF
}
put() { mkdir -p "$(dirname "$P/$1")"; printf '%b' "$2" > "$P/$1"; }
hook_bash() { jq -n --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'; }

echo "typescript-nestjs-stress-test 회귀 테스트"

# --- A. CLI ------------------------------------------------------------------
tc TC-N01 "이 저장소 전체가 통과한다 (NestJS 프로젝트가 아니다)"
run "$REPO_ROOT"; expect_code 0; expect_no_out

tc TC-N02 "규칙을 지킨 프로젝트는 조용히 통과한다"
project; run "$P"; expect_code 0; expect_no_out

tc TC-N03 "Dockerfile 이 npm run start:dev 로 띄우면 막는다 — 스크립트를 풀어 nest start 를 본다 (NST-01)"
project; put Dockerfile 'FROM node:22-slim\nCMD ["npm", "run", "start:dev"]\n'; run "$P"; expect_code 2; expect_out "NST-01 Dockerfile:2"

tc TC-N04 "배포 설정과 start:prod 가 없고 start 가 nest start 면 막는다 (NST-01)"
project; rm "$P/Dockerfile"; jq 'del(.scripts["start:prod"])' "$P/package.json" > "$P/p.json" && mv "$P/p.json" "$P/package.json"
run "$P"; expect_code 2; expect_out "NST-01 package.json:scripts.start"

tc TC-N05 "배포 설정이 없으면 start:prod 를 본다 — 기본 스타터의 start · start:dev 로는 막지 않는다 (NST-01 과잉 차단 방지)"
project; rm "$P/Dockerfile"; run "$P"; expect_code 0; expect_no_out

tc TC-N06 "compose command 의 nest start --debug 도 막는다 (NST-01)"
project; put docker-compose.yml 'services:\n  api:\n    build: .\n    command: npx nest start --debug 0.0.0.0:9229\n'; run "$P"; expect_code 2; expect_out "NST-01 docker-compose.yml:4"

tc TC-N07 "이름에 dev · local · test 가 있는 compose 는 운영 기동으로 보지 않는다 (NST-01 과잉 차단 방지)"
project; put docker-compose.dev.yml 'services:\n  api:\n    command: npm run start:dev\n'; run "$P"; expect_code 0; expect_no_out

tc TC-N08 "ts-node · tsx 로 .ts 를 직접 실행하면 경고한다 (NST-02)"
project; put Dockerfile 'FROM node:22-slim\nCMD ["npx", "ts-node", "src/main.ts"]\n'; run "$P"; expect_code 0; expect_out "NST-02 Dockerfile:2"
put Dockerfile 'FROM node:22-slim\nCMD node -r ts-node/register src/main\n'; run "$P"; expect_out "NST-02"

tc TC-N09 "node dist/main.js 는 경고하지 않는다 (NST-02 과잉 경고 방지)"
project; put Dockerfile 'FROM node:22-slim\nCMD ["node", "--enable-source-maps", "dist/main.js"]\n'; run "$P"; expect_code 0; expect_no_out

tc TC-N10 "logger 옵션에 debug · verbose 가 있으면 경고한다 (NST-03)"
project; sed -i.bak "s/\['error', 'warn', 'log'\]/['error', 'warn', 'log', 'debug']/" "$P/src/main.ts"; run "$P"; expect_code 0; expect_out "NST-03 src/main.ts:5"

tc TC-N11 "logger 옵션이 없고 코드에 .debug() 가 있으면 기본 레벨 6개로 찍힌다고 경고한다 (NST-03)"
project; sed -i.bak "s/, { logger: \['error', 'warn', 'log'\] }//" "$P/src/main.ts"; rm "$P/src/main.ts.bak"; run "$P"; expect_code 0
expect_out "NST-03 src/main.ts"; expect_out "src/order.service.ts:7"

tc TC-N12 "logger 옵션이 없어도 .debug() 호출이 없거나 useLogger 가 있으면 경고하지 않는다 (NST-03 과잉 경고 방지)"
project; sed -i.bak "s/, { logger: \['error', 'warn', 'log'\] }//" "$P/src/main.ts"; rm "$P/src/main.ts.bak" "$P/src/order.service.ts"; run "$P"; expect_code 0; expect_no_out
project; sed -i.bak "s/, { logger: \['error', 'warn', 'log'\] }/, { bufferLogs: true }/; s/await app.listen/app.useLogger(app.get(MyLogger));\n  await app.listen/" "$P/src/main.ts"; rm "$P/src/main.ts.bak"; run "$P"; expect_not "NST-03"

tc TC-N13 "logger 옵션이 없을 때 NEST_LOG_LEVEL 이 debug 를 켜면 경고하고, warn · >debug 면 조용하다 (NST-03)"
project; sed -i.bak "s/, { logger: \['error', 'warn', 'log'\] }//" "$P/src/main.ts"; rm "$P/src/main.ts.bak"
put docker-compose.yml 'services:\n  api:\n    environment:\n      NEST_LOG_LEVEL: debug\n'; run "$P"; expect_code 0; expect_out "NST-03 docker-compose.yml:4"
put docker-compose.yml 'services:\n  api:\n    environment:\n      - NEST_LOG_LEVEL=">=verbose"\n'; run "$P"; expect_out "NST-03 docker-compose.yml:4"
put docker-compose.yml 'services:\n  api:\n    environment:\n      NEST_LOG_LEVEL: warn\n'; run "$P"; expect_no_out
put docker-compose.yml 'services:\n  api:\n    environment:\n      NEST_LOG_LEVEL: ">debug"\n'; run "$P"; expect_no_out

tc TC-N13b "logger 옵션을 명시하면 NEST_LOG_LEVEL 은 무시된다 (NST-03 과잉 경고 방지)"
project; put docker-compose.yml 'services:\n  api:\n    environment:\n      NEST_LOG_LEVEL: debug\n'; run "$P"; expect_no_out

tc TC-N14 "FastifyAdapter 에 logger 를 켜면 경고한다 — 여러 줄 옵션도 본다 (NST-04)"
project; put src/main.ts "import { NestFactory } from '@nestjs/core';\nimport { FastifyAdapter } from '@nestjs/platform-fastify';\n\nasync function bootstrap() {\n  const app = await NestFactory.create(AppModule, new FastifyAdapter({\n    logger: true,\n  }), { logger: ['error'] });\n  await app.listen(3000, '0.0.0.0');\n}\n"
run "$P"; expect_code 0; expect_out "NST-04 src/main.ts:5"; expect_not "NST-05"

tc TC-N15 "disableRequestLogging: true 거나 logger 를 켜지 않으면 경고하지 않는다 (NST-04 과잉 경고 방지)"
project; put src/main.ts "const app = await NestFactory.create(AppModule, new FastifyAdapter({ logger: true, disableRequestLogging: true }), { logger: ['error'] });\nawait app.listen(3000, '0.0.0.0');\n"
run "$P"; expect_code 0; expect_no_out
put src/main.ts "const app = await NestFactory.create(AppModule, new FastifyAdapter(), { logger: ['error'] });\nawait app.listen({ port: 3000, host: '0.0.0.0' });\n"; run "$P"; expect_no_out

tc TC-N16 "Fastify 어댑터에서 listen 에 호스트가 없으면 경고한다 (NST-05)"
project; put src/main.ts "const app = await NestFactory.create(AppModule, new FastifyAdapter(), { logger: ['error'] });\nawait app.listen(process.env.PORT ?? 3000);\n"
run "$P"; expect_code 0; expect_out "NST-05 src/main.ts:2"

tc TC-N17 "Express 어댑터의 listen(3000) 은 경고하지 않는다 (NST-05 과잉 경고 방지)"
project; run "$P"; expect_not "NST-05"

tc TC-N18 "makeSummaryProvider · new Summary 를 경고하고 주석은 보지 않는다 (NST-06)"
project; put src/metrics.ts "import { makeSummaryProvider } from '@willsoto/nestjs-prometheus';\n// makeSummaryProvider({ name: 'old' })\nexport const p = makeSummaryProvider({ name: 'latency', help: 'l' });\nexport const s = new client.Summary({ name: 'x', help: 'x' });\n"
run "$P"; expect_code 0; expect_out "NST-06 src/metrics.ts:3"; expect_out "NST-06 src/metrics.ts:4"; expect_not "src/metrics.ts:2"

tc TC-N19 "지연 히스토그램이 없으면 NST-07, in-flight 게이지가 없으면 NST-08 을 경고한다"
project; put src/app.module.ts "import { Module } from '@nestjs/common';\n@Module({})\nexport class AppModule {}\n"
run "$P"; expect_code 0; expect_out "NST-07"; expect_out "NST-08"

tc TC-N20 "new Histogram · new Gauge 로 직접 만들어도 인정하고, OpenTelemetry SDK 를 쓰면 보지 않는다 (NST-07 · NST-08 과잉 경고 방지)"
project; put src/app.module.ts "import { Gauge, Histogram } from 'prom-client';\nexport const h = new Histogram<string>({ name: 'h', help: 'h' });\nexport const g = new Gauge({ name: 'g', help: 'g' });\n"
run "$P"; expect_no_out
project; put src/app.module.ts "export class AppModule {}\n"
jq '.dependencies["@opentelemetry/sdk-node"] = "^0.200.0"' "$P/package.json" > "$P/p.json" && mv "$P/p.json" "$P/package.json"; run "$P"; expect_no_out

tc TC-N21 "Scope.REQUEST 프로바이더를 경고한다 (NST-09)"
project; put src/tenant.service.ts "import { Injectable, Scope } from '@nestjs/common';\n\n@Injectable({ scope: Scope.REQUEST })\nexport class TenantService {}\n"
run "$P"; expect_code 0; expect_out "NST-09 src/tenant.service.ts:3"

tc TC-N22 "durable: true 인 요청 스코프와 Scope.TRANSIENT 는 경고하지 않는다 (NST-09 과잉 경고 방지)"
project; put src/tenant.service.ts "@Injectable({\n  scope: Scope.REQUEST,\n  durable: true,\n})\nexport class TenantService {}\n@Injectable({ scope: Scope.TRANSIENT })\nexport class Helper {}\n"
run "$P"; expect_no_out

tc TC-N23 "@nestjs/core 가 없는 프로젝트는 보지 않는다"
project; jq 'del(.dependencies["@nestjs/core"])' "$P/package.json" > "$P/p.json" && mv "$P/p.json" "$P/package.json"
put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'; run "$P"; expect_code 0; expect_no_out

tc TC-N24 "node_modules · dist · *.spec.ts 는 보지 않는다"
project; put node_modules/x/index.ts "new Summary({})\n"; put dist/main.js "makeSummaryProvider({})\n"; put src/a.spec.ts "@Injectable({ scope: Scope.REQUEST })\n"
run "$P"; expect_no_out

tc TC-N25 "디렉터리가 아니면 오류 (종료 1)"
run "$TMP/none"; expect_code 1

tc TC-N26 "loadtest · perftest 처럼 단어 안에 dev · local · test 가 든 compose · Dockerfile 은 본다 (NST-01)"
project; put docker-compose.loadtest.yml 'services:\n  api:\n    command: npx nest start --watch\n'
put Dockerfile.perftest 'FROM node:22-slim\nCMD ["npm", "run", "start:dev"]\n'; put docker-compose.local-db.yml 'services:\n  api:\n    command: npx nest start --watch\n'
run "$P"; expect_code 2; expect_out "NST-01 docker-compose.loadtest.yml:3"; expect_out "NST-01 Dockerfile.perftest:2"; expect_not "local-db"

tc TC-N27 "compose · Dockerfile 의 빈칸 없는 exec 형식 배열도 읽는다 (NST-01)"
project; put docker-compose.yml 'services:\n  api:\n    command: ["nest","start","--watch"]\n'; run "$P"; expect_code 2; expect_out "NST-01 docker-compose.yml:3"
project; put Dockerfile 'FROM node:22-slim\nCMD ["npm","run","start:dev"]\n'; run "$P"; expect_code 2; expect_out "NST-01 Dockerfile:2"
project; put Dockerfile 'FROM node:22-slim\nCMD ["node","dist/main"]\n'; run "$P"; expect_code 0; expect_no_out

# --- B. 훅 -------------------------------------------------------------------
tc TC-N30 "k6 run 이면 프로젝트를 검사해 additionalContext 로 알리고 막지 않는다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
run_hook "$P" "$(hook_bash 'k6 run --summary-export out.json load.js')"; expect_code 0
expect_out '"additionalContext"'; expect_out "NST-01"; expect_not "permissionDecision"

tc TC-N31 "docker run grafana/k6 · autocannon · 환경 변수 접두어도 부하 명령으로 본다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
run_hook "$P" "$(hook_bash 'docker run --rm -i grafana/k6 run - < s.js')"; expect_out "NST-01"
run_hook "$P" "$(hook_bash 'K6_X=1 npx autocannon -c 64 http://localhost:3000')"; expect_out "NST-01"
run_hook "$P" "$(hook_bash 'cd load && k6 run s.js')"; expect_out "NST-01"

tc TC-N32 "부하 명령이 아니면 조용히 통과한다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
run_hook "$P" "$(hook_bash 'npm test')"; expect_code 0; expect_no_out
run_hook "$P" "$(hook_bash 'echo k6 run s.js')"; expect_no_out
run_hook "$P" "$(hook_bash 'grep -r wrk .')"; expect_no_out

tc TC-N33 "부하 명령이어도 프로젝트가 깨끗하면 조용하다"
project; run_hook "$P" "$(hook_bash 'k6 run s.js')"; expect_code 0; expect_no_out

tc TC-N34 "빈 입력 · Bash 가 아닌 도구 · PostToolUse 는 통과한다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
run_hook "$P" ""; expect_code 0; expect_no_out
run_hook "$P" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"a","content":"k6 run"}}'; expect_no_out
run_hook "$P" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"k6 run s.js"}}'; expect_no_out

tc TC-N35 "래퍼(uv run · poetry run · python -m · timeout · sh -c) · 한 줄 루프 · if 안의 부하 명령도 알린다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
for c in 'uv run locust -f locustfile.py --headless' 'poetry run locust --headless' 'python -m locust --headless' \
         'timeout 60 k6 run s.js' "sh -c 'k6 run s.js'" 'for r in 50 100; do k6 run s.js; done' 'if true; then k6 run s.js; fi'; do
  run_hook "$P" "$(hook_bash "$c")"; expect_code 0; expect_out "NST-01"
done

tc TC-N36 "래퍼 뒤가 부하 도구가 아니거나 heredoc 본문의 부하 명령은 조용히 통과한다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
for c in 'uv run pytest' 'poetry run python manage.py migrate' 'python -m http.server' 'timeout 5 curl http://x' "sh -c 'echo k6 run'" "$(printf 'cat > note.md <<EOF\nk6 run s.js\nEOF')"; do
  run_hook "$P" "$(hook_bash "$c")"; expect_code 0; expect_no_out
done

tc TC-N37 "래퍼 nice · ionice · stdbuf · xargs · watch · caffeinate 뒤의 부하 명령도 알린다 — 값을 받는 옵션은 값까지 건너뛴다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
for c in 'nice k6 run s.js' 'nice -n 10 k6 run s.js' 'ionice -c 2 -n 7 k6 run s.js' 'stdbuf -oL k6 run s.js' 'stdbuf -o L k6 run s.js' \
         'echo s.js | xargs -n1 k6 run' 'xargs -I {} k6 run {} < list.txt' "watch -n 5 'hey http://localhost:8080/'" 'caffeinate -i -t 600 k6 run s.js'; do
  run_hook "$P" "$(hook_bash "$c")"; expect_code 0; expect_out "NST-01"
done

tc TC-N38 "래퍼 뒤가 부하 도구가 아니면 조용히 통과한다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
for c in 'nice -n 10 make build' 'ionice -c 3 du -sh .' 'stdbuf -oL tail -f app.log' 'echo a | xargs -n1 rm' 'watch -n 5 kubectl get pods' 'caffeinate -t 60 sleep 60'; do
  run_hook "$P" "$(hook_bash "$c")"; expect_code 0; expect_no_out
done

tc TC-N39 "워크스페이스 루트에서도 명령이 도는 하위 앱(cwd · 앞머리 cd)부터 위로 가장 가까운 @nestjs/core 프로젝트를 본다"
project; put Dockerfile 'CMD ["npm", "run", "start:dev"]\n'
M="$TMP/mono"; mkdir -p "$M/apps"; printf '{"private":true,"workspaces":["apps/*"]}\n' > "$M/package.json"; mv "$P" "$M/apps/api"
run_hook "$M" "$(hook_bash 'cd apps/api && k6 run s.js')"; expect_code 0; expect_out "NST-01"
run_hook "$M" "$(jq -n --arg d "$M/apps/api/load" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: "k6 run s.js"}, cwd: $d}')"; expect_out "NST-01"
run_hook "$M" "$(hook_bash 'k6 run s.js')"; expect_code 0; expect_no_out

flush_tc
echo
echo "통과 $PASS · 실패 $FAIL · 건너뜀 $SKIP"
[ "$FAIL" = 0 ]
