# Gin 서버 계측 레시피

부하 측정에 필요한 서버 측 신호 — 지연 **히스토그램**, in-flight 게이지(Little 의 L), 자원(USE) — 를 Gin 앱에 붙인다.
확인 버전: Gin v1.12.0 · prometheus/client_golang v1.24.1 · Go 1.25. 이 레시피로 만든 앱에서 `/metrics` 출력을 실제로 확인했다.

## 1. 의존성

```bash
go get github.com/prometheus/client_golang@latest
```

## 2. 코드

```go
var (
	inFlight = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "http_server_requests_in_flight",
		Help: "In-flight requests.",
	})
	duration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_server_request_duration_seconds",
		Help:    "Request latency.",
		Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5}, // SLO 경계를 버킷 경계로 넣는다
		NativeHistogramBucketFactor: 1.1, // 선택 — protobuf 로 긁을 때만 native 로 나간다
	}, []string{"method", "route", "code"})
)

func metrics(c *gin.Context) {
	start := time.Now()
	c.Next()
	route := c.FullPath() // 원시 URL.Path 는 라벨 카디널리티를 터뜨린다 (GIN-11)
	if route == "" {
		route = "unmatched"
	}
	duration.WithLabelValues(c.Request.Method, route, strconv.Itoa(c.Writer.Status())).
		Observe(time.Since(start).Seconds())
}

func main() {
	gin.SetMode(gin.ReleaseMode) // GIN-01 · GIN-02
	prometheus.MustRegister(inFlight, duration)

	r := gin.New()
	r.Use(gin.Recovery(), metrics) // 접근 로그가 운영에도 있으면 그때만 gin.Logger() (GIN-03)

	admin := http.NewServeMux() // 메트릭은 앱 라우터와 다른 포트
	admin.Handle("/metrics", promhttp.Handler())
	go func() { log.Fatal(http.ListenAndServe(":9090", admin)) }()

	dbg := http.NewServeMux() // pprof 는 루프백 전용 mux (GIN-04)
	dbg.HandleFunc("/debug/pprof/", pprof.Index)
	dbg.HandleFunc("/debug/pprof/profile", pprof.Profile)
	go func() { log.Fatal(http.ListenAndServe("127.0.0.1:6060", dbg)) }()

	srv := &http.Server{ // GIN-08 — r.Run() 은 타임아웃이 없다
		Addr:              ":8080",
		Handler:           promhttp.InstrumentHandlerInFlight(inFlight, r),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
```

- `promhttp.InstrumentHandlerInFlight` 는 감싼 핸들러가 처리 중인 요청 수를 게이지로 둔다. Gin 엔진 전체를 감싸면 미들웨어 · 404 까지 센다
- `promhttp.InstrumentHandlerDuration` 도 쓸 수 있지만 라벨은 `code` · `method` 만 허용한다 (다른 라벨이면 panic). 라우트별로 보려면 위처럼 Gin 미들웨어에서 `c.FullPath()` 를 쓴다
- `net/http/pprof` 를 `_` 로 import 하면 `DefaultServeMux` 에 붙는다. 앱이 `DefaultServeMux` 를 공개 포트로 열면 프로파일이 공개된다 — 위처럼 함수를 별도 mux 에 직접 등록한다

## 3. 히스토그램 vs Summary

| | Histogram | Summary (`Objectives`) |
|---|---|---|
| 분위수 계산 | 서버(PromQL `histogram_quantile`) | 앱 안에서 미리 계산 |
| 인스턴스 합치기 | 버킷을 `sum` 한 뒤 한 번 계산 — 된다 | 분위수 평균은 통계적으로 무의미 — 안 된다 |
| 미리 정할 것 | 버킷 경계 (native 는 해상도) | 분위수 · 시간 창 (나중에 못 바꾼다) |

Prometheus 문서는 가능하면 native histogram 을 권한다. client_golang 에서 native 는 아직 실험 기능이고, 텍스트 노출(`/metrics` 기본)에는 classic 버킷만 보인다 — Prometheus 가 protobuf 로 긁어야 native 로 들어간다.

## 4. PromQL

```promql
# 라우트별 p99 — 버킷을 먼저 합친다
histogram_quantile(0.99, sum by (le, route) (rate(http_server_request_duration_seconds_bucket[1m])))

# 처리량 · 에러율
sum by (route) (rate(http_server_request_duration_seconds_count[1m]))
sum(rate(http_server_request_duration_seconds_count{code=~"5.."}[1m])) / sum(rate(http_server_request_duration_seconds_count[1m]))

# Little 검사 — L 과 λ·W 를 같은 창으로
avg_over_time(http_server_requests_in_flight[1m])
sum(rate(http_server_request_duration_seconds_sum[1m]))   # = λ·W (초)
```

`rate(_sum)` 이 λ·W 다 (단위 시간당 누적 체류 시간). in-flight 평균과 비교한다 (`GIN-24`).

## 5. 자원 (USE) — 기본 수집기가 내는 것

`promhttp.Handler()` 의 기본 레지스트리에 Go · 프로세스 수집기가 들어 있다. 실제 출력에서 확인한 이름:

| 자원 | U (이용률) | S (포화) | E |
|---|---|---|---|
| CPU | `rate(process_cpu_seconds_total[1m])` / `go_sched_gomaxprocs_threads` | 컨테이너 `cpu.stat` 의 `nr_throttled` · `throttled_usec` | - |
| 메모리 | `process_resident_memory_bytes` · `go_memstats_heap_inuse_bytes` | GC 빈도 `rate(go_gc_duration_seconds_count[1m])` | OOM kill (오케스트레이터) |
| 고루틴 | `go_goroutines` | in-flight 대비 고루틴 증가 | - |
| DB 풀 | `go_sql_in_use_connections` / `go_sql_max_open_connections` | `rate(go_sql_wait_count_total[1m])` · `go_sql_wait_duration_seconds_total` | - |

DB 풀 지표는 `collectors.NewDBStatsCollector(db, "main")` 를 등록해야 나온다 (`database/sql` `DBStats` 를 옮긴 것).

요청당 CPU = `rate(process_cpu_seconds_total[1m]) / sum(rate(http_server_request_duration_seconds_count[1m]))`. 설정 하나를 바꿔 비교할 때 지연보다 노이즈에 강하다 (`GIN-26`).

CFS 스로틀은 컨테이너 안에서 읽는다.

```bash
docker exec <앱> cat /sys/fs/cgroup/cpu.stat    # nr_periods · nr_throttled · throttled_usec
```

## 6. 부하 중 CPU 프로파일

정상 상태 구간에서 받는다 (`GIN-23`). pprof 가 루프백에만 있으면 앱의 네트워크 네임스페이스로 들어가 받는다.

```bash
# Docker — 앱 컨테이너의 네트워크를 공유하는 curl
docker run --rm --network container:<앱> -v "$PWD":/o curlimages/curl \
  -s -o /o/cpu.pprof '127.0.0.1:6060/debug/pprof/profile?seconds=10'
# k8s
kubectl port-forward pod/<파드> 6060:6060 &
curl -s -o cpu.pprof '127.0.0.1:6060/debug/pprof/profile?seconds=10'

go tool pprof -top -nodecount=15 cpu.pprof
```

`seconds` 를 빼면 30초다. 프로파일 구간이 부하 단계 안에 들어가게 단계 길이를 잡는다.
