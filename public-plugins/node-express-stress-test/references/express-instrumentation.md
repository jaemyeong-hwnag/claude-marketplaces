# Express 서버 측 계측 레시피

규칙: [`express-stress-rules.md`](express-stress-rules.md) `NEX-10` ~ `NEX-13`. prom-client 15.1.3 · Express 5.2.1 · Node.js 22 에서 돌려 본 코드다.

## 1. 설치

```bash
npm install prom-client
```

## 2. 지연 히스토그램 · in-flight 게이지 · 기본 지표

```js
const express = require('express');
const client = require('prom-client');

client.collectDefaultMetrics(); // process_cpu_* · nodejs_heap_* · nodejs_eventloop_lag_* · nodejs_gc_duration_seconds

const duration = new client.Histogram({
  name: 'http_server_request_duration_seconds',
  help: 'HTTP 요청 처리 시간',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});
const inflight = new client.Gauge({
  name: 'http_server_requests_in_flight',
  help: '처리 중인 요청 수',
});

const app = express();
app.use((req, res, next) => {
  if (req.path === '/metrics') return next();
  inflight.inc();
  const end = duration.startTimer({ method: req.method });
  // 'finish' 는 클라이언트가 먼저 끊으면 오지 않는다
  res.on('close', () => {
    inflight.dec();
    end({ route: req.route ? req.baseUrl + req.route.path : 'unmatched', status_code: res.statusCode });
  });
  next();
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

- **라벨은 라우트 패턴**(`/orders/:id`)으로 한다. `req.url` 을 쓰면 시계열이 요청 수만큼 늘어난다. `req.route` 는 핸들러가 정해진 뒤에만 있으므로 `close` 시점에 읽는다
- 버킷은 SLO 경계(예: 200 ms)가 버킷 경계와 맞도록 고른다. 경계 사이 값은 `histogram_quantile` 이 선형 보간한다
- `/metrics` 자신은 게이지 · 히스토그램에서 뺀다 — 샘플러가 읽을 때마다 in-flight 가 1 늘어난다
- **Summary 를 쓰지 않는다** (`NEX-08`) — 분위수를 앱이 계산하므로 워커 · 인스턴스 사이에 합칠 수 없다

## 3. 확인

```bash
curl -s localhost:3000/metrics | grep -E '^(http_server_|nodejs_eventloop_lag_(seconds|p99)|process_cpu_seconds_total)'
```

나와야 할 것:

```
http_server_request_duration_seconds_bucket{le="0.005",method="GET",route="/cpu",status_code="200"} 0
…
http_server_request_duration_seconds_sum{…} …
http_server_request_duration_seconds_count{…} …
http_server_requests_in_flight 0
nodejs_eventloop_lag_seconds …
nodejs_eventloop_lag_p99_seconds …
process_cpu_seconds_total …
```

PromQL:

```promql
histogram_quantile(0.99, sum by (le, route) (rate(http_server_request_duration_seconds_bucket[1m])))
avg_over_time(http_server_requests_in_flight[1m])
```

## 4. in-flight 게이지가 보지 못하는 것

Node.js 는 한 스레드가 소켓을 읽고 · 파싱하고 · 핸들러를 돈다. 핸들러가 동기로 끝나면 `inc` 와 `dec` 사이에 다른 요청(게이지를 읽는 `/metrics` 포함)이 끼어들 수 없다.

- 동기 핸들러: 대기열은 커널 소켓 버퍼와 파싱 전 단계에 있다 → 게이지 ≈ 0 (실측: `/view` 900 rps 에서 평균 0.00)
- 비동기 대기가 있는 핸들러(`await db…` · 타이머 · 스레드풀): 대기 중인 요청만 잡힌다 → 실제 L 보다 작다
- 그래서 Little 검증은 **부하기 쪽 L = 처리량 × 평균 지연**과 서버 게이지를 나란히 놓는다. 차이가 곧 "JS 가 보기 전 대기열" 이다

## 5. 이벤트 루프 지표

| 지표 | 출처 | 쓰임 |
|---|---|---|
| `nodejs_eventloop_lag_seconds` | `setImmediate` 지연 1회 표본 | 순간값 — 단계 비교에는 거칠다 |
| `nodejs_eventloop_lag_p50/p90/p99/max/mean/stddev_seconds` | `perf_hooks.monitorEventLoopDelay` (해상도 `eventLoopMonitoringPrecision`, 기본 10 ms) | 블로킹 크기 — 막는 핸들러가 있으면 p99 ≈ 블로킹 시간 |
| ELU | `performance.eventLoopUtilization()` | 루프가 바쁜 비율 — CPU 사용률보다 Node 포화를 잘 보인다 |

ELU 는 prom-client 기본 지표에 없다. 필요하면 게이지로 직접 낸다.

```js
const { performance } = require('node:perf_hooks');
let last = performance.eventLoopUtilization();
new client.Gauge({
  name: 'nodejs_eventloop_utilization_ratio',
  help: '수집 간격 동안 이벤트 루프 사용률',
  collect() { const now = performance.eventLoopUtilization(); this.set(performance.eventLoopUtilization(now, last).utilization); last = now; },
});
```

## 6. cluster · PM2 워커가 여럿일 때

```js
const cluster = require('node:cluster');
const client = require('prom-client');

if (cluster.isPrimary) {
  const agg = new client.AggregatorRegistry();
  require('node:http').createServer(async (req, res) => {
    try {
      const body = await agg.clusterMetrics();
      res.setHeader('Content-Type', agg.contentType);
      res.end(body);
    } catch (e) {
      res.statusCode = 503; // 처리하지 않으면 primary 가 죽어 워커도 같이 내려간다
      res.end(String(e));
    }
  }).listen(9100);
  for (let i = 0; i < require('node:os').availableParallelism(); i++) cluster.fork();
} else {
  new client.AggregatorRegistry(); // 워커 쪽 응답 리스너 등록
  // … 2절의 앱
}
```

- 사용자 지표는 기본 `sum` 으로 합쳐진다 — 히스토그램 버킷 · in-flight 게이지에 맞다
- 이벤트 루프 lag 의 평균 · 분위수는 워커 평균으로 합쳐진다 (README 가 "not perfectly accurate" 라고 적음). 워커별로 보려면 `worker` 라벨을 단다
- PM2 cluster mode 는 primary 를 PM2 가 갖는다. 그때 지표를 합치는 방법은 확인하지 않았다 — 워커마다 `worker` 라벨을 달고 Prometheus 쪽에서 `sum` 한다
