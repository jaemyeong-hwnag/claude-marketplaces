# Express 부하 측정 규칙 (단일 원본)

Node.js · Express 앱을 부하 측정할 때 **그 프레임워크에만 해당하는 것**을 정한다.
부하 모델 · 지표 정의 · 통계 판정 · 대상 호스트 안전은 `common-stress-test` 가 맡는다.

기계 검증: [`scripts/express-stress-config-validate.sh`](../scripts/express-stress-config-validate.sh) — `NEX-01` ~ `NEX-09`.
계측 코드: [`express-instrumentation.md`](express-instrumentation.md) · 마이크로벤치마크: [`node-microbenchmark.md`](node-microbenchmark.md).

확인 버전: Node.js 22.23 · Express 5.2.1 (4.x 소스도 대조) · prom-client 15.1.3 · tinybench 4.1.0 · mitata 1.0.34.

## 1. 측정을 무효로 만드는 설정 — 스크립트가 본다

| 조항 | 탐지 | 판정 | 근거 |
|---|---|---|---|
| `NEX-01` | 운영 기동 설정(`package.json` 의 `start` · `start:prod` · `prod` · `serve`, `Dockerfile`, `compose*.yml`, `Procfile`)에 `NODE_ENV` 가 `production` 이 아닌 값 | 위반 | Express 소스 `lib/application.js` `defaultConfiguration` · finalhandler `getErrorMessage` |
| `NEX-02` | 위 파일 어디에도 `NODE_ENV=production` 이 없다 | 경고 | 같은 소스 — 미설정 기본값이 `development` |
| `NEX-03` | 운영 기동이 `nodemon` · `node --watch` · `tsx watch` · `ts-node-dev` 이거나 PM2 `watch: true` | 위반 | Node.js CLI 문서 `--watch` (재시작 시 진행 중 I/O 중단) · nodemon README (개발 도구) |
| `NEX-04` | 운영 기동에 `--prof` · `--cpu-prof` · `--heap-prof` · `--trace-sync-io` · `--trace-gc` · `0x` · `clinic` | 위반 | Express 성능 문서 "--trace-sync-io 는 운영에서 쓰지 않는다" · 프로파일러는 측정 대상 실행 모드를 바꾼다 |
| `NEX-05` | 운영 기동에 `--inspect` · `--inspect-brk` | 경고 | Node.js CLI 문서 — 공개 IP 바인딩은 원격 코드 실행 위험. 클라이언트가 안 붙으면 실측 차이는 노이즈 안 |
| `NEX-06` | `DEBUG` 가 `express:*` · `router` · `*` 를 켠다 | 위반 | Express 문서 "Debugging Express" — 요청마다 `router dispatching …` 를 stderr 로 쓴다. Node.js `process` 문서 — stderr 가 파일 · TTY 면 동기 쓰기. 실측(요청당 3줄, 파일)에서는 차이가 노이즈 안이었다 — 운영과 다른 디버그 모드라서 위반이다 |
| `NEX-07` | 소스에서 `app.disable('view cache')` · `app.set('view cache', false)` | 위반 | Express 소스 `app.render` — `view cache` 가 꺼지면 요청마다 템플릿을 찾고 컴파일한다 |
| `NEX-08` | `prom-client` 를 쓰는 파일에서 `new Summary(` | 경고 | Prometheus 문서 "Histograms and summaries" — 분위수는 합칠 수 없다 · prom-client README "Summaries calculate percentiles" |
| `NEX-09` | 라우트를 정의한 파일에서 `*Sync(` 호출 | 경고 | Express 성능 문서 "Don't use synchronous functions" — 기동 시 1회는 무관하므로 경고 |

- 검사 대상은 `package.json` 에 `express` 가 있는 디렉터리다. 없으면 조용히 통과한다
- `*dev*` · `*local*` · `*test*` 가 이름에 든 compose · Dockerfile 은 운영 기동이 아니므로 보지 않는다. `package.json` 의 `dev` 스크립트도 보지 않는다
- `.env` 는 보지 않는다 — 개발용인 경우가 많다. 실제 기동 환경 변수는 배포 설정(쿠버네티스 매니페스트 · systemd `Environment=`)에 있을 수 있으므로 `NEX-02` 는 경고다
- PM2 `ecosystem.config.*` 는 `env` · `env_production` 을 나눠 쓰므로 `NODE_ENV` 값으로 위반을 내지 않는다 (`production` 이 있으면 `NEX-02` 만 해소)

### NODE_ENV 가 실제로 바꾸는 것

Express 코어(4.x · 5.x 동일)에서 `NODE_ENV` 가 바꾸는 것은 둘뿐이다.

1. `production` 이면 `view cache` 를 켠다 — `res.render` 가 템플릿을 한 번만 컴파일한다
2. finalhandler 가 `production` 이 아니면 오류 응답 본문에 스택을 싣는다

Express 문서의 "3배 빨라진다" 는 2015년 Dynatrace 블로그(Jade 템플릿 렌더링 앱, `ab -c 100`)가 출처이고, 같은 글 본문은 "처리량이 약 2/3 늘었다" 고 적었다.
**JSON 만 내는 API 는 코어 기준으로 달라질 것이 없다.** 의존 라이브러리(템플릿 엔진 · ORM · React SSR 등)가 `NODE_ENV` 를 따로 읽으면 달라진다.

실측(Express 5.2.1, 1 CPU, 순차 요청 2,000회 2반복 중앙값):

| 엔드포인트 | production | development | 미설정 |
|---|---|---|---|
| `/view` (pug 50행) | 0.54 · 0.61 ms | 2.41 · 2.02 ms | 4.34 · 1.38 ms |
| `/cpu` (JSON, 4 ms CPU) | 4.74 · 4.91 ms | 5.24 · 4.56 ms | 4.45 · 4.82 ms |

open 부하 단계에서 `/view` 는 development 가 450 rps 에서 무너졌고(처리량 373, p99 6.6 s) production 은 900 rps 까지 p99 16 ms 였다.

## 2. 계측 — AI 가 판단한다

| 조항 | 내용 | 근거 |
|---|---|---|
| `NEX-10` | 요청 지연은 prom-client **Histogram** 으로 낸다 (`http_server_request_duration_seconds`). 기본 버킷 `[0.005 … 10]` 이 SLO 경계를 포함하는지 본다 | prom-client 15.1.3 `lib/histogram.js` 기본값 |
| `NEX-11` | in-flight 게이지를 미들웨어에서 `inc` · `res.on('close')` 에서 `dec` 한다. **동기 핸들러는 이 게이지에 거의 잡히지 않는다** — 대기열이 JS 밖(소켓 버퍼 · 파싱 전)에 있다. Little 검증은 부하기 측 L(처리량 × 평균 지연)과 함께 본다 | 실측: 동기 `/view` 는 900 rps 포화 근처에서도 게이지 평균 0.00 |
| `NEX-12` | 이벤트 루프 지표를 같이 남긴다 — `collectDefaultMetrics()` 의 `nodejs_eventloop_lag_seconds` · `nodejs_eventloop_lag_p99_seconds` (`monitorEventLoopDelay`, 기본 해상도 10 ms) · ELU(`performance.eventLoopUtilization`) | prom-client `lib/metrics/eventLoopLag.js` · Node.js `perf_hooks` 문서 |
| `NEX-13` | cluster · PM2 로 워커를 여럿 띄우면 `/metrics` 는 워커 하나의 값이다. primary 에서 `AggregatorRegistry.clusterMetrics()` 로 합치고, **워커에서도 `new AggregatorRegistry()` 를 만들어야** 응답한다. 워커가 5초 안에 답하지 않으면 `Operation timed out` 으로 실패한다 | prom-client README "Usage with Node.js's cluster module" · `lib/cluster.js` (리스너 등록 · 5000 ms 타임아웃) |

- event loop lag 의 `min` 은 해상도(10 ms)를 포함한 값이 나온다 (실측 `nodejs_eventloop_lag_min_seconds` ≈ 0.010). 절대값보다 **부하 단계 사이의 변화**를 본다
- 이벤트 루프 지연은 대기열 길이가 아니다. 대기열이 쌓여도 루프 한 바퀴가 짧으면 lag 은 낮다

## 3. 용량 손잡이 — AI 가 판단한다

| 조항 | 손잡이 | 기본값 | 포화점에 미치는 영향 | 근거 |
|---|---|---|---|---|
| `NEX-20` | 프로세스 수 (`cluster` · PM2 `-i max` · 컨테이너 복제) | 1 | JS 실행은 프로세스당 한 스레드다. CPU 를 쓰는 핸들러의 처리량 상한 ≈ 워커 수 / CPU 서비스 시간. 측정 전에 워커 수와 CPU 한도를 같이 적는다 | Node.js `cluster` 문서 (`SCHED_RR` 기본, Windows 제외) · PM2 cluster mode 문서 · Express 성능 문서 |
| `NEX-21` | `UV_THREADPOOL_SIZE` | 4 (최대 1024, 기동 시 1회 읽음) | `fs` · `crypto`(pbkdf2 · scrypt 등) · `zlib` · `dns.lookup` 이 같은 풀을 쓴다. 풀 크기가 이 작업들의 동시 처리 L 상한이다 | Node.js CLI 문서 `UV_THREADPOOL_SIZE` · `dns` 문서 "Implementation considerations" · libuv threadpool 문서 |
| `NEX-22` | `server.keepAliveTimeout` · `headersTimeout` · `requestTimeout` | 5,000 ms · min(requestTimeout, 60,000) · 300,000 ms | keep-alive 가 끊기면 연결 수립 비용이 지연에 들어간다. 앞단 LB 의 유휴 타임아웃과의 대소는 배포 환경에서 확인한다 | Node.js `http` 문서 |
| `NEX-23` | 아웃바운드 `http.Agent` | 사용자 `new Agent()` 는 `keepAlive: false`, `http.globalAgent` 는 v19 부터 `keepAlive: true` · 5 s | 하류 호출이 연결을 매번 열면 그 비용이 상류 지연에 더해진다 | Node.js `http` 문서 `http.globalAgent` · `new Agent` |
| `NEX-24` | 이벤트 루프를 막는 핸들러 | - | 한 요청의 동기 작업이 **다른 모든 요청**의 꼬리 지연이 된다. 원인 후보는 `*Sync` API · 큰 `JSON.parse/stringify` · 정규식 · 동기 로깅 | Express 성능 문서 · Node.js `process` 문서 "A note on process I/O" |

실측(1 CPU 고정 · 2 CPU 고정, 단계 15~20 s, 노이즈가 큰 공유 호스트):

| 실험 | 결과 |
|---|---|
| `NEX-20` 2 CPU 에 워커 1 vs 2 (`/mixed` = 20 ms 대기 + 4 ms CPU) | 워커 1: 200 rps 에서 처리량 170, p99 5.6 s. 워커 2: 300 rps 까지 p99 91 ms, 400 rps 에서 꺾임 |
| `NEX-21` pbkdf2 100,000회 (`/hash`), 8 CPU | 풀 4: 200 rps 에서 처리량 178, in-flight 282. 풀 8: 400 rps 에서 처리량 381 (300 단계는 호스트 노이즈로 무너짐) |
| `NEX-24` `/mixed` 80 rps 에 200 ms 블로킹 요청 1 rps 를 섞음 | `/mixed` p99 81 ms → 228 ms (중앙값은 그대로 28 ms), `nodejs_eventloop_lag_p99_seconds` 0.034 → 0.211 |
| `NEX-22` k6 `noConnectionReuse` (800 rps, `/view`) | 2반복이 서로 엇갈려 차이를 판정하지 못했다 |

## 4. 마이크로벤치마크

코드 단위 비교는 tinybench 또는 mitata 로 한다. 절차와 출력 읽는 법은 [`node-microbenchmark.md`](node-microbenchmark.md).
CPU 프로파일링(0x · clinic flame)은 원인을 찾을 때만 쓰고, 그 실행의 수치를 성능 결과로 보고하지 않는다 (`NEX-04`).

## 5. 다른 플러그인에 넘기는 것

| 할 일 | 담당 |
|---|---|
| 부하 시나리오(open/closed · 단계 · 시간) 작성 | `common-stress-test` 의 `stress-test-create` |
| 결과 판정(포화점 · Little 검증 · 회귀 통계) | `common-stress-test` 의 `stress-result-review` |
