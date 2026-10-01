---
name: nestjs-stress-test-apply
description: NestJS 서버를 부하 · 스트레스 측정할 수 있게 준비한다 — 지연 히스토그램 · in-flight 게이지 계측, nest start · ts-node · debug 로그 제거, 어댑터 · 요청 스코프 · DB 풀 확인, tinybench 비교. NestJS 앱 성능 측정 · 부하 테스트 준비 때 사용한다. 트리거 — "nest 부하", "NestJS 성능", "nestjs-prometheus", "Scope.REQUEST 느려", "Fastify 어댑터".
---

# NestJS 부하 측정 준비

규칙 원본: [`references/nestjs-stress-rules.md`](../../references/nestjs-stress-rules.md) (`NST-*`)
레시피: [`references/nestjs-stress-recipes.md`](../../references/nestjs-stress-recipes.md)
기계 검증: [`scripts/nestjs-stress-config-validate.sh`](../../scripts/nestjs-stress-config-validate.sh)

이 스킬은 **서버 쪽**만 맡는다. 부하 스크립트 작성(open 모델 · 단계 · thresholds)은 `common-stress-test` 의 `stress-test-create`,
결과 판정(knee · Little · 회귀 통계)은 `stress-result-review` 에 넘긴다.

## 1. 무효 설정부터 걷어낸다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/nestjs-stress-config-validate.sh" .
```

종료 코드 `2` 면 그 상태로 잰 수치는 버린다. 경고는 하나씩 확인한다.

| 조항 | 볼 것 | 고치는 법 |
|---|---|---|
| `NST-01` | Dockerfile · compose · `start:prod` 가 `nest start`(`--watch` · `--debug`) | `nest build` 후 `node dist/main` |
| `NST-02` | `ts-node` · `tsx` 로 `src/main.ts` 실행 | 빌드 산출물로 띄운다 |
| `NST-03` | `logger` 옵션 없음(기본 6레벨 전부) + 요청 경로의 `logger.debug()` · `NEST_LOG_LEVEL=debug` | `NestFactory.create(AppModule, { logger: ['error', 'warn', 'log'] })` |
| `NST-04` | `new FastifyAdapter({ logger: true })` | 끄거나 요청 로그를 끈다 |
| `NST-05` | Fastify 어댑터의 `listen(port)` | `listen(port, '0.0.0.0')` — 기본은 127.0.0.1 |

`NODE_ENV` 는 Nest 자체가 읽지 않는다. Express 어댑터일 때만 Express 가 읽는다 — `production` 으로 두는 것은 Node · Express 공통 사항이다.

## 2. 계측을 붙인다

레시피 1절을 그대로 쓴다. 확인할 것:

1. 지연은 **Histogram** 으로 (`NST-06`). Summary 의 분위수는 인스턴스 사이에 합칠 수 없다
2. 버킷이 SLO 근처를 촘촘히 덮는다. prom-client 기본 버킷 `0.005 … 10` 은 SLO 가 200 ms 면 `0.1 · 0.25` 사이가 비어 있다
3. **in-flight 게이지**가 있다 (`NST-08`) — Little's Law 검증용. `/metrics` 요청은 빼고 센다
4. 측정 위치는 **미들웨어**(`res.on('finish')`)다 (`NST-10`). 인터셉터는 가드 · 파이프에서 거절된 요청을 못 보고, 예외 필터 뒤를 못 본다
5. 미들웨어는 `forRoutes({ path: '{*splat}', method: RequestMethod.ALL })` 로 건다 — `'*'` 로는 404 가 빠졌다 (실측)
6. Fastify 어댑터면 Nest 미들웨어가 라우트 템플릿을 모른다 → Fastify `onRequest` · `onResponse` 훅으로 잰다 (레시피 1.3)
7. `curl -s localhost:3000/metrics | grep -E 'http_server_(request_duration_seconds_bucket|requests_in_flight)'` 로 실제로 나오는지 본다
8. 기본 지표의 `nodejs_eventloop_lag_p99_seconds` · `process_cpu_seconds_total` 을 USE 의 포화 · 이용률로 같이 본다

## 3. 손잡이를 확인한다

포화점을 바꾸는 값을 측정 전에 적어 둔다. 측정 보고에 같이 싣는다.

| 손잡이 | 기본 | 보는 법 |
|---|---|---|
| 프로세스 수 (`NST-12`) | 1 (이벤트 루프 하나 ≈ 코어 하나) | 레플리카 · 클러스터 수. 프로세스 1개 결과를 머신 용량으로 쓰지 않는다 |
| 어댑터 (`NST-11`) | Express | Fastify 와 같은 엔드포인트로 비교해 잰다. 실측 빈 핸들러에서 +85% |
| 요청 스코프 (`NST-09`) | 싱글턴 | `Scope.REQUEST` 가 컨트롤러로 번졌는지 본다. `durable: true` 로 줄일 수 있는지. 실측 빈 핸들러에서 처리량 −20% |
| DB 풀 (`NST-13`) | pg · mysql2 10, Prisma 7 은 드라이버 어댑터 기본값 | 풀 크기가 동시 쿼리 상한 = Little 의 L 상한이다. 풀 대기 시간을 계측한다 |

포화점 예측: 풀 크기 ÷ 평균 쿼리 시간(s) = DB 경유 처리량 상한. 예: 풀 10 · 쿼리 20 ms → 500 rps.

## 4. 코드 수준 비교 — 마이크로벤치마크

엔드포인트 전체가 아니라 함수 하나(직렬화 · 검증 · 매핑)를 비교할 때 쓴다 (`NST-20`). 레시피 2절.

1. tinybench (`new Bench({ time, warmupTime })`) 나 mitata 로 두 구현을 같은 프로세스에서 번갈아 잰다. 빌드한 JS 로 돌린다
2. 결과를 쓰지 않는 식은 JIT 가 지운다 — mitata 의 `do_not_optimize()` 로 감싼다. mitata 가 `!` (dead code elimination) 를 내면 그 수치는 버린다
3. 한 번 실행으로 판정하지 않는다 — 프로세스를 새로 띄워 10회 이상 반복하고 평균 · 중앙값 분포를 모은다
4. 분포 비교는 `common-stress-test` 의 `stress-regression-validate.sh` (Mann-Whitney U · Cliff's delta) 에 넘긴다
5. `rme`(상대 오차)가 크면(수 % 이상) 그 실행은 노이즈가 많은 것이다. 다른 부하가 없는 머신에서 다시 잰다

## 5. 보고

- 버전: Node · `@nestjs/core` · 어댑터 · prom-client
- 실행 명령 (`node dist/main` 과 환경 변수)
- 1절 스크립트 출력 (위반 0 이어야 한다)
- 3절 손잡이 값
- 단계 결과와 판정은 `stress-result-review` 형식으로
