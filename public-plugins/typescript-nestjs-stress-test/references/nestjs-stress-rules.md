# NestJS 스트레스 테스트 규칙 (단일 원본)

NestJS 서버를 부하 측정할 때 **측정을 무효로 만드는 설정**, **서버 측 계측**, **포화점을 정하는 손잡이**를 정한다.
기계 검증은 [`scripts/nestjs-stress-config-validate.sh`](../scripts/nestjs-stress-config-validate.sh), 계측 코드와 마이크로벤치마크 절차는 [`nestjs-stress-recipes.md`](nestjs-stress-recipes.md).

부하 모델 · 지표 · 통계 판정 · 대상 호스트 안전은 `common-stress-test` 의 `stress-test-rules.md` (`ST-*`) 가 맡는다. 여기는 NestJS 에만 해당하는 것을 둔다.
Node 런타임 공통(`NODE_ENV` · 이벤트 루프 · `UV_THREADPOOL_SIZE` · 클러스터)은 4절에 짧게만 둔다.

확인한 버전: Node 22.23 · @nestjs/core · common · platform-express · platform-fastify 12.1.2 · @nestjs/cli 12.0.8 · fastify 5.12 · prom-client 15.1.3 · @willsoto/nestjs-prometheus 6.1.1 · ts-node 10.9.2 · TypeScript 6.0.3 · tinybench 6.2.0 · mitata 1.0.34.

## 1. 조항

판정 — **차단**: CLI 종료 코드 `2`. 훅은 부하 명령을 막지 않고 `additionalContext` 로 알린다. **경고**: CLI `0` + 알림. **AI 판단**: 스크립트가 보지 않고 `nestjs-stress-test-apply` 스킬이 본다.

| 조항 | 내용 | 판정 | 근거 |
|---|---|---|---|
| `NST-01` | 측정 대상을 `nest start` (`--watch` · `--debug` 포함) 로 띄우지 않는다. `nest build` 후 `node dist/main` | 차단 | Nest CLI 문서 "Usage" — `nest start` 는 컴파일 후 실행, `--watch` 는 감시 · 재시작, `--debug` 는 `--inspect`. typescript-starter `package.json` — `start:dev` = `nest start --watch`, `start:prod` = `node dist/main`. 실측: 처리량은 같고 메모리가 6배 (CLI · tsc 감시 프로세스) |
| `NST-02` | `ts-node` · `tsx` 로 `.ts` 를 직접 실행해 측정하지 않는다 | 경고 | ts-node README — 운영은 "pre-compilation for production", 타입 검사 비용은 기동 시 든다. `nest start` 는 ts-node 가 아니라 tsc 빌드다 (CLI 소스 `start.action.ts`) |
| `NST-03` | Nest 로그 레벨에 `debug` · `verbose` 를 켜고 재지 않는다. `logger` 옵션이 없으면 기본이 6레벨 전부다 | 경고 | Nest 문서 "Logger" — `logger: ['error', 'warn']`, 레벨은 `log` · `fatal` · `error` · `warn` · `debug` · `verbose`. 소스 `console-logger.service.ts` `DEFAULT_LOG_LEVELS` 가 6개 전부. `NEST_LOG_LEVEL` 은 소스에만 있고 `logger` 옵션 · `useLogger` 가 앞선다 |
| `NST-04` | `new FastifyAdapter({ logger: true })` 로 재지 않는다 (요청 로그를 끄지 않았으면) | 경고 | Fastify 문서 Server — `logger` 기본 `false`, `disableRequestLogging` 기본 `false` 이고 켜져 있으면 요청마다 수신 · 응답 두 줄을 `info` 로 쓴다. Nest `FastifyAdapter` 는 옵션을 그대로 넘긴다 |
| `NST-05` | Fastify 어댑터면 `listen(port, '0.0.0.0')` 처럼 호스트를 준다 | 경고 | Nest 문서 "Performance (Fastify)" — Fastify 는 기본으로 localhost 에만 듣는다, 다른 호스트는 `'0.0.0.0'`. 측정이 무효가 되기보다 컨테이너 밖 부하기가 붙지 못한다 |
| `NST-06` | 요청 지연은 `Histogram` 으로 잰다. `makeSummaryProvider` · `new Summary` 로 재지 않는다 | 경고 | Prometheus 문서 "Histograms and summaries" — 분위수는 합칠 수 없다 (`avg(...{quantile="0.95"}) // BAD!`). prom-client README — Summary 는 프로세스가 백분위를 계산한다 |
| `NST-07` | 서버 측 지연 히스토그램이 있다 | 경고 | `ST-*` 의 서버 · 부하기 측정 대조. @willsoto/nestjs-prometheus README `makeHistogramProvider` |
| `NST-08` | in-flight 요청 게이지가 있다 | 경고 | `ST-13` (Little's Law). README `makeGaugeProvider` |
| `NST-09` | `Scope.REQUEST` 프로바이더는 비용을 재고 쓴다. `durable: true` 면 경고하지 않는다 | 경고 | Nest 문서 "Injection scopes" Performance — 요청마다 인스턴스를 만들어 평균 응답시간 · 벤치마크 결과가 나빠진다, 잘 설계하면 지연 증가 ~5% 이내. REQUEST 스코프는 주입 체인을 따라 올라간다 (의존하는 컨트롤러도 요청 스코프). 실측 2절 |
| `NST-10` | 지연 · in-flight 는 미들웨어(`res` 의 `finish` · `close`)에서 잰다. 인터셉터에서 재지 않는다 | AI 판단 | Nest 문서 "Request lifecycle" — 미들웨어 → 가드 → 인터셉터(전) → 파이프 → 핸들러 → 인터셉터(후) → 예외 필터. 인터셉터는 가드에서 거절된 요청과 예외 필터 이후를 못 본다 |
| `NST-11` | 어댑터(Express · Fastify)를 측정 조건으로 적고, 바꿀 때는 같은 엔드포인트로 비교해 잰다 | AI 판단 | Nest 문서 "Performance (Fastify)" — Fastify 가 Express 보다 벤치마크 결과가 두 배 가까이 나온다. 실측 2절 |
| `NST-12` | 프로세스 1개 = 이벤트 루프 1개다. 용량은 프로세스(레플리카) 수를 정하고 잰다 | AI 판단 | 4절 |
| `NST-13` | DB 커넥션 풀 크기가 동시 쿼리 상한이다. 풀 대기 시간을 계측한다 | AI 판단 | node-postgres 문서 Pool — `max` 기본 10. TypeORM 은 기본값을 두지 않고 `poolSize` 를 드라이버에 넘긴다 (mysql2 `connectionLimit` 기본 10). Prisma 문서 Connection pool — v6 은 `num_physical_cpus × 2 + 1` · `pool_timeout` 10 s, v7 부터 드라이버 어댑터 기본값 (pg `max` 10, 대기 무제한). @nestjs/typeorm 은 기본값을 두지 않는다 |
| `NST-20` | 함수 수준 비교는 tinybench · mitata 로 하고, 판정은 프로세스를 새로 띄운 반복 분포로 한다 | AI 판단 | tinybench README `Bench` 옵션 `time` · `warmupTime`, `rme`. `ST-20` |

### 예외 — 보지 않는 것

| 경우 | 이유 |
|---|---|
| `//` · `*` 로 시작하는 주석 줄 | 실행되지 않는다 |
| 이름에 `dev` · `local` · `test` 가 있는 Dockerfile · compose | 운영 기동이 아니다 |
| 배포 설정(Dockerfile · compose · Procfile)이 없을 때의 `start` · `start:dev` | 운영 기동은 `start:prod` 다. `start:prod` 가 없을 때만 `start` 를 본다 |
| `node_modules/` · `dist/` · `build/` · `coverage/` · `test/` · `*.spec.*` · `*.test.*` · `*.d.ts` · 루트의 `.claude/` | 의존성 · 산출물 · 테스트다 |
| `@opentelemetry/sdk-node` · `sdk-metrics` 를 쓰는 프로젝트 (`NST-07` · `NST-08`) | OTel HTTP 계측이 지연 히스토그램과 활성 요청 수를 따로 낸다 |
| `durable: true` 인 요청 스코프, `Scope.TRANSIENT` (`NST-09`) | 요청마다 하위 트리를 다시 만들지 않는다 / 위로 번지지 않는다 |
| `@nestjs/core` 가 `package.json` 에 없는 프로젝트 | 대상이 아니다 |

## 2. 실측 (Docker, 컨테이너 `--cpus=1`, k6)

엔드포인트 `/work` = `setTimeout` 20 ms + CPU 2 ms, `/fast` = 바로 응답. 다른 컨테이너 부하가 같이 돌던 공유 머신이라 단계 사이 변동이 크다 — 경향만 쓴다.

| 항목 | 결과 |
|---|---|
| open 모델 단계 (`/work`, 50 → 380 rps) | 지속 용량 ≈ 340 rps. 380 rps 에서 처리량이 목표 아래로 떨어지고 p99 가 수 초로 뛴다 |
| Little (`X·W` vs in-flight 게이지) | 정상 단계는 X·W 가 게이지보다 0 ~ 18% 크다 (부하기의 W 에 네트워크가 들어간다). 포화 단계 · 멈춤이 있던 단계는 5 ~ 10배 — 소켓 · 이벤트 루프에서 기다리는 요청은 미들웨어에 오기 전이라 게이지에 없다 |
| 무효 설정 · 손잡이 비교 | Fastify +85% (유의), `Scope.REQUEST` −20% (유의). debug 로그 · ts-node · `--inspect` · `--watch` 의 처리량 차이는 노이즈 안. `--watch` 407 MiB · ts-node 351 MiB vs 운영 64 MiB. 표는 [`nestjs-stress-recipes.md`](nestjs-stress-recipes.md) 3절 |
| 미들웨어 `forRoutes('*')` | 404 요청이 계측에서 빠졌다. `forRoutes({ path: '{*splat}', method: RequestMethod.ALL })` 은 잡는다 |
| Fastify 어댑터 + Nest 미들웨어 | 원시 `req` 에 라우트 정보가 없어 라우트 라벨을 못 붙인다. Fastify `onResponse` 훅의 `request.routeOptions.url` 로 붙는다 |
| TypeScript 7.0 | `nest build` 가 실패한다 ("does not expose the programmatic compiler API"). 6.x 로 빌드했다 |

## 3. 계측 지표 이름

| 지표 | 타입 | 라벨 | 쓰임 |
|---|---|---|---|
| `http_server_request_duration_seconds` | Histogram | `method` · `route`(템플릿) · `status` | RED 의 Duration · Rate(`_count`) · Errors(`status`) |
| `http_server_requests_in_flight` | Gauge | 없음 | Little 의 L |
| `nodejs_eventloop_lag_p99_seconds` | Gauge (기본 지표) | 없음 | USE 의 포화 — 이벤트 루프가 밀리는 정도 |
| `process_cpu_seconds_total` | Counter (기본 지표) | 없음 | USE 의 이용률 — `rate()` 가 1 에 붙으면 프로세스 포화 |

`route` 에 실제 URL 을 넣지 않는다 — 경로 변수마다 시계열이 생긴다. 라우트 템플릿(`/orders/:id`)을 쓴다.

## 4. Node 런타임 공통 (짧게)

| 항목 | 내용 | 근거 |
|---|---|---|
| `NODE_ENV` | Nest(`@nestjs/core` · `platform-express`)는 읽지 않는다. Express 어댑터일 때 Express 가 읽는다 — `production` 으로 둔다 | Nest 소스 검색. Express 문서 "Production best practices: performance" |
| 이벤트 루프 | 프로세스당 하나다. 동기 CPU 작업이 모든 요청을 막는다 → 포화가 CPU 1코어에서 온다 | Node 문서 "Don't Block the Event Loop" |
| `UV_THREADPOOL_SIZE` | 기본 4 (libuv 상한 1024). `crypto.pbkdf2` · `zlib` · `fs` · `dns.lookup` 이 이 풀을 쓴다 → 이것들이 많은 엔드포인트는 4 가 동시성 상한이다 | Node 문서 CLI `UV_THREADPOOL_SIZE`. libuv 문서 Thread pool |
| `--inspect` | 성능 영향은 문서에 없다. `0.0.0.0` 바인딩은 보안 경고가 있다 | Node 문서 CLI `--inspect` |
