# NestJS 계측 · 마이크로벤치마크 레시피

규칙은 [`nestjs-stress-rules.md`](nestjs-stress-rules.md) (`NST-*`). 아래 코드는 Nest 12.1.2 · prom-client 15.1.3 · @willsoto/nestjs-prometheus 6.1.1 · fastify 5.12 로 실제로 돌려 `/metrics` 출력을 확인했다.

## 1. 서버 측 계측

### 1.1 설치

```bash
npm i @willsoto/nestjs-prometheus prom-client
```

`PrometheusModule.register()` 는 `/metrics` 를 열고 기본 지표(`process_*` · `nodejs_*`, 이벤트 루프 지연 포함)를 낸다. 경로는 `path` 로 바꾼다.

### 1.2 Express 어댑터 — 미들웨어

```ts
// app.module.ts
import { MiddlewareConsumer, Module, NestModule, RequestMethod } from '@nestjs/common';
import { PrometheusModule, makeGaugeProvider, makeHistogramProvider } from '@willsoto/nestjs-prometheus';
import { MetricsMiddleware } from './metrics.middleware';

@Module({
  imports: [PrometheusModule.register()],
  providers: [
    makeHistogramProvider({
      name: 'http_server_request_duration_seconds',
      help: 'HTTP 요청 처리 시간',
      labelNames: ['method', 'route', 'status'],
      // SLO 근처를 촘촘히 — 기본 버킷은 0.005 · 0.01 · 0.025 · 0.05 · 0.1 · 0.25 · 0.5 · 1 · 2.5 · 5 · 10
      buckets: [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3, 0.5, 1, 2.5, 5, 10],
    }),
    makeGaugeProvider({ name: 'http_server_requests_in_flight', help: '처리 중인 요청 수' }),
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(MetricsMiddleware)
      .exclude({ path: 'metrics', method: RequestMethod.GET })
      .forRoutes({ path: '{*splat}', method: RequestMethod.ALL });  // '*' 로는 404 가 빠졌다
  }
}
```

```ts
// metrics.middleware.ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { InjectMetric } from '@willsoto/nestjs-prometheus';
import { Gauge, Histogram } from 'prom-client';

@Injectable()
export class MetricsMiddleware implements NestMiddleware {
  constructor(
    @InjectMetric('http_server_request_duration_seconds') private readonly duration: Histogram<string>,
    @InjectMetric('http_server_requests_in_flight') private readonly inFlight: Gauge<string>,
  ) {}

  use(req: any, res: any, next: () => void) {
    const start = process.hrtime.bigint();
    this.inFlight.inc();
    let done = false;
    const end = () => {
      if (done) return;
      done = true;
      this.inFlight.dec();
      // 미들웨어 시점엔 라우트가 정해지지 않아 끝날 때 읽는다
      const route = req.route?.path ?? 'unmatched';
      this.duration.observe(
        { method: req.method, route, status: String(res.statusCode) },
        Number(process.hrtime.bigint() - start) / 1e9,
      );
    };
    res.once('finish', end);
    res.once('close', end);   // 클라이언트가 끊은 요청도 게이지를 내린다
    next();
  }
}
```

- 인터셉터가 아니라 미들웨어다 (`NST-10`). 가드에서 거절된 401 · 403, 파이프에서 거절된 400 도 잰다
- `route` 는 Express 가 매칭 뒤 채우는 `req.route.path` (템플릿, 예 `/orders/:id`). 404 는 `/{*splat}` 로 묶인다

### 1.3 Fastify 어댑터 — Fastify 훅

Fastify 어댑터에서 Nest 미들웨어는 원시 `req` · `res` 를 받아 라우트 템플릿을 모른다 (실측: 모든 요청이 `unmatched`). Fastify 훅으로 잰다.

```ts
// main.ts
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { getToken } from '@willsoto/nestjs-prometheus';
import { Gauge, Histogram } from 'prom-client';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter(), {
    logger: ['error', 'warn', 'log'],
  });
  const duration = app.get<Histogram<string>>(getToken('http_server_request_duration_seconds'));
  const inFlight = app.get<Gauge<string>>(getToken('http_server_requests_in_flight'));
  const fastify = app.getHttpAdapter().getInstance();
  fastify.addHook('onRequest', async (req) => { if (req.url !== '/metrics') inFlight.inc(); });
  fastify.addHook('onResponse', async (req, reply) => {
    if (req.url === '/metrics') return;
    inFlight.dec();
    duration.observe(
      { method: req.method, route: req.routeOptions.url ?? 'unmatched', status: String(reply.statusCode) },
      reply.elapsedTime / 1000,   // ms → s
    );
  });
  await app.listen(3000, '0.0.0.0');   // NST-05
}
bootstrap();
```

이때 1.2 의 미들웨어는 걸지 않는다 (두 번 센다).

### 1.4 확인

```bash
curl -s localhost:3000/orders/1 >/dev/null
curl -s localhost:3000/metrics | grep -E '^http_server_(request_duration_seconds_(bucket|count)|requests_in_flight)'
```

`http_server_request_duration_seconds_bucket{le="…",method="GET",route="/orders/:id",status="200"}` 와 `http_server_requests_in_flight 0` 이 나와야 한다.

### 1.5 쿼리

```promql
# p99 — 인스턴스를 합친 뒤 한 번만 분위수 (ST-31)
histogram_quantile(0.99, sum by (le, route) (rate(http_server_request_duration_seconds_bucket{status!~"5.."}[1m])))
# 처리량 · 에러율
sum(rate(http_server_request_duration_seconds_count[1m]))
sum(rate(http_server_request_duration_seconds_count{status=~"5.."}[1m])) / sum(rate(http_server_request_duration_seconds_count[1m]))
# Little 의 L — 게이지 평균과 서버 측 X·W 가 같아야 한다
avg_over_time(http_server_requests_in_flight[1m])
sum(rate(http_server_request_duration_seconds_sum[1m]))
# USE
rate(process_cpu_seconds_total[1m])
nodejs_eventloop_lag_p99_seconds
```

- 서버 측 `rate(_sum)` 은 서버가 본 L 이다. 부하기의 X·W 가 이보다 크면 그 차이는 서버 앞(소켓 대기 · LB · 네트워크)에 있다
- 실측: 포화 단계에서 부하기 X·W 가 게이지의 약 10배였다 — 요청이 미들웨어에 오기 전에 이벤트 루프 · 소켓에서 기다렸다

## 2. 마이크로벤치마크

### 2.1 tinybench

```ts
import 'reflect-metadata';
import { Bench } from 'tinybench';
import { IsInt, IsString, Min, validateSync } from 'class-validator';
import { plainToInstance } from 'class-transformer';

class OrderDto {
  @IsString() id!: string;
  @IsInt() @Min(1) qty!: number;
}
const body = { id: 'o-1', qty: 3 };

const bench = new Bench({ time: 1000, warmupTime: 500 });
bench
  .add('class-validator', () => { validateSync(plainToInstance(OrderDto, body)); })
  .add('manual', () => { typeof body.id === 'string' && Number.isInteger(body.qty) && body.qty >= 1; });
await bench.run();
console.table(bench.table());
```

빌드한 JS 로 돌린다 (`tsc` 후 `node bench.js`). ts-node 로 돌리면 첫 반복에 컴파일이 섞인다.

### 2.2 mitata

```ts
import { bench, do_not_optimize, run, summary } from 'mitata';
summary(() => {
  bench('class-validator', () => validateSync(plainToInstance(OrderDto, body)));
  bench('manual', () => do_not_optimize(typeof body.id === 'string' && Number.isInteger(body.qty) && body.qty >= 1));
});
await run();
```

`summary` 는 가장 빠른 것 대비 배수를 낸다. 결과를 쓰지 않는 식은 JIT 가 지운다 — `do_not_optimize()` 로 감싼다 (3절).

### 2.3 판정

1. 한 프로세스의 한 번 실행은 JIT · GC 상태 하나의 표본이다. 프로세스를 새로 띄워 10회 이상 반복한다
2. 매회 각 구현의 평균(또는 중앙값)을 모은다 — `bench.tasks[i].result.latency.mean` (ms)
3. 두 분포를 `common-stress-test` 의 `stress-regression-validate.sh` 로 비교한다 (Mann-Whitney U · Cliff's delta)
4. `rme` 가 수 % 를 넘으면 그 회차는 노이즈가 크다. 다른 부하가 없는 머신 · 고정 CPU 에서 다시 잰다

## 3. 무효 설정 · 손잡이 실측

Docker 컨테이너 `--cpus=1`, `/fast`(바로 응답)에 k6 closed 64 VU 10 ~ 15 초로 최대 처리량을 쟀다. 다른 부하가 같이 돌던 공유 머신이라 같은 설정도 회차마다 2배까지 흔들렸다 — 그래서 변형마다 8회 반복하고 `stress-regression-validate.sh` (Mann-Whitney U · Cliff's delta) 로 운영 설정과 비교했다.

| 변형 | 처리량 중앙값 (rps) | 운영 대비 | p (양측) | Cliff δ | 메모리 (기동 직후) | 판정 |
|---|---|---|---|---|---|---|
| 운영 — `node dist/main`, `logger: ['error','warn','log']` | 6,622 | — | — | — | 64 MiB | 기준 |
| Fastify 어댑터 | 12,218 | +85% | 0.002 | +0.88 | - | 유의 (문서의 "두 배 가까이" 와 맞다) |
| `Scope.REQUEST` 컨트롤러 (같은 컨테이너에서 10회 번갈아) | 6,088 vs 7,604 | −20% | 0.043 | −0.54 | - | 유의. 문서의 "~5% 이내" 보다 크다 — 핸들러가 비어 있어 생성 비용 비중이 크다 |
| 로그 레벨 기본(6개) + 인터셉터가 요청마다 `debug` | 4,673 | −29% | 0.23 | −0.38 | - | 노이즈와 구분 못 함 |
| `ts-node src/main.ts` | 4,606 | −30% | 0.23 | −0.38 | 351 MiB | 처리량은 노이즈와 구분 못 함, 메모리 5.5배 |
| `node --inspect` (디버거 연결 없음) | 5,006 | −24% | 0.51 | −0.22 | - | 노이즈와 구분 못 함 |
| `nest start --watch` | 6,392 | −3.5% | 0.96 | +0.03 | 407 MiB | 처리량 차이 없음 (자식이 같은 `node dist/main`), 메모리 6.4배 |

- `nest start --watch` · ts-node 의 비용은 처리량보다 **메모리**에서 보인다. 컨테이너 메모리 한도 · USE 의 메모리 이용률을 왜곡한다
- 단계 부하(open 모델 50 → 380 rps, `/work` = 20 ms 대기 + CPU 2 ms)에서도 debug 로그 변형과 운영 설정의 차이는 노이즈 안이었다
- 차이를 못 잡은 항목은 "영향 없음" 이 아니라 "이 환경에서 8회로는 못 가른다" 다. 조용한 머신에서 다시 잰다

### 마이크로벤치마크 출력 (실행 확인)

tinybench 6.2.0 `console.table(bench.table())` — 지연은 ns, `±` 는 상대 오차(rme).

```
│ 'class-validator' │ '1757.2 ± 1.95%' │ '1541.0 ± 41.00' │ '632345 ± 0.03%'   │ ... │ 569100   │
│ 'manual'          │ '56.02 ± 0.56%'  │ '42.00 ± 1.00'   │ '20235134 ± 0.01%' │ ... │ 17851924 │
```

`bench.tasks[i].result.latency` 의 `mean` · `p99` 는 ms 단위다.

mitata 1.0.34 — 결과를 쓰지 않는 식은 `!` 와 "benchmark was likely optimized out (dead code elimination)" 를 낸다. `do_not_optimize(값)` 으로 감싸면 경고가 사라진다 (실측 121 ps → 250 ps). tinybench 는 이 경고를 내지 않는다.

```ts
import { bench, do_not_optimize } from 'mitata';
bench('manual', () => do_not_optimize(check(body)));
```
