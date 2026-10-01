---
name: express-stress-test-apply
description: Node.js · Express 앱을 부하 측정할 수 있게 준비한다 — prom-client 지연 히스토그램 · in-flight 게이지 계측, NODE_ENV · nodemon · DEBUG 같은 무효 설정 제거, cluster 워커 · UV_THREADPOOL_SIZE 확인, tinybench · mitata 벤치. Express 서버의 부하 · 스트레스 테스트를 준비하거나 성능을 잴 때 사용한다. 트리거 — "express 부하", "node 성능 측정", "prom-client", "이벤트 루프 지연".
---

# Express 부하 측정 준비

규칙 원본: [`references/express-stress-rules.md`](../../references/express-stress-rules.md) (`NEX-01` ~ `NEX-24`)
계측 코드: [`references/express-instrumentation.md`](../../references/express-instrumentation.md)
마이크로벤치마크: [`references/node-microbenchmark.md`](../../references/node-microbenchmark.md)
기계 검증: [`scripts/express-stress-config-validate.sh`](../../scripts/express-stress-config-validate.sh)

이 스킬은 **Express 쪽 준비**만 한다. 부하 시나리오 작성은 `common-stress-test` 의 `stress-test-create`, 결과 판정(포화점 · Little 검증 · 회귀 통계)은 `stress-result-review` 에 넘긴다.

## 1. 무효 설정부터 없앤다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/express-stress-config-validate.sh" .
```

종료 코드 2 면 측정하지 않는다. 위반을 고치고 다시 돌린다.

| 조항 | 고치는 법 |
|---|---|
| `NEX-01` · `NEX-02` | 기동 환경에 `NODE_ENV=production` (Dockerfile `ENV` · systemd `Environment=` · 매니페스트) |
| `NEX-03` | `start` 를 `node dist/server.js` 처럼 직접 실행으로. nodemon · `--watch` 는 `dev` 스크립트에만 |
| `NEX-04` · `NEX-05` | 프로파일러 · `--inspect` 를 기동 명령에서 뺀다. 원인 분석 실행은 따로 하고 수치를 섞지 않는다 |
| `NEX-06` | `DEBUG` 를 비우거나 앱 네임스페이스만 남긴다 |
| `NEX-07` | `view cache` 를 끄는 줄을 지운다 (production 이면 Express 가 켠다) |
| `NEX-08` | Summary → Histogram |
| `NEX-09` | 요청 경로의 `*Sync` 를 비동기 API 로. 기동 시 1회 읽기면 그대로 둔다 |

`NODE_ENV` 는 Express 코어에서 **뷰 캐시와 오류 응답 본문만** 바꾼다. JSON API 에서 큰 차이를 기대하지 않는다 — 템플릿 렌더링(`res.render`)이나 `NODE_ENV` 를 읽는 의존 라이브러리가 있을 때 차이가 난다. "3배" 는 템플릿 앱 사례다.

## 2. 계측을 붙인다

`express-instrumentation.md` 2절 코드를 앱 초기화에 넣는다.

1. `http_server_request_duration_seconds` Histogram — 라벨 `method` · `route`(패턴) · `status_code`. 버킷에 SLO 경계를 넣는다
2. `http_server_requests_in_flight` Gauge — 미들웨어 `inc`, `res.on('close')` 에서 `dec`. `/metrics` 는 뺀다
3. `collectDefaultMetrics()` — CPU · 힙 · GC · `nodejs_eventloop_lag_*`
4. 워커가 여럿이면 `AggregatorRegistry` 를 primary 와 **워커 양쪽에** 만든다 (6절)
5. `curl /metrics` 로 세 가지가 나오는지 확인한다

**in-flight 게이지의 한계를 판정 쪽에 알린다** (`NEX-11`): 동기 핸들러의 대기열은 JS 가 보기 전에 쌓이므로 게이지에 안 잡힌다. Little 검증은 부하기 쪽 L(처리량 × 평균 지연)을 기준으로 하고 게이지와의 차이를 "JS 밖 대기" 로 해석한다.

## 3. 용량 손잡이를 적어 둔다

측정 전에 아래를 기록한다. 값이 바뀌면 다른 실험이다.

| 손잡이 | 확인할 곳 | 판단 |
|---|---|---|
| 워커 수 (`NEX-20`) | cluster 코드 · PM2 `instances` · 컨테이너 복제 수 · CPU 한도 | CPU 핸들러가 있으면 워커 1 의 상한 ≈ 1 / CPU 서비스 시간. 실측: 2 CPU 에서 워커 1 은 170 rps 에서 무너지고 워커 2 는 300 rps 까지 버텼다 |
| `UV_THREADPOOL_SIZE` (`NEX-21`) | 기동 환경 변수 (기본 4) | `fs` · `crypto` · `zlib` · `dns.lookup` 이 많으면 풀 크기가 L 상한이다. 늘릴 때는 CPU 수와 같이 본다 |
| keep-alive (`NEX-22` · `NEX-23`) | `server.keepAliveTimeout`(기본 5 s) · 하류 호출 `http.Agent` | 부하기 · LB · 서버의 연결 재사용 조건을 같게 둔다 |
| 이벤트 루프 블로킹 (`NEX-24`) | `nodejs_eventloop_lag_p99_seconds` | 단계마다 기록한다. 200 ms 블로킹 1 rps 만 섞여도 다른 요청 p99 가 81 → 228 ms 가 됐다 |

## 4. 코드 단위로 비교할 때

핸들러 안 한 조각만 바꾼 경우 HTTP 부하보다 마이크로벤치마크가 싸고 정확하다. `node-microbenchmark.md` 절차대로:

1. tinybench(`warmupTime` · `time` 명시, rme 확인) 또는 mitata(`summary` · `do_not_optimize` · `--expose-gc`)
2. CPU 고정, 새 프로세스 5회 이상 번갈아 실행
3. 프로세스별 중앙값으로 차이를 내고 통계 판정은 `common-stress-test` 로

## 5. 넘긴다

- 부하 스크립트(open 모델 · 단계 · 시간): `stress-test-create`
- 결과 CSV(`load,throughput,p50_ms,p95_ms,p99_ms,max_ms,error_rate,inflight`) 판정: `stress-result-review`
- 부하 명령(k6 · wrk · autocannon …)을 실행하면 이 플러그인의 훅이 1절 검사를 다시 돌려 알린다. 막지는 않는다
