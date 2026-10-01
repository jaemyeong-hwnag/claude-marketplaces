# Go · Gin 스트레스 테스트 규칙 (단일 원본)

Go · Gin 서버를 부하 측정할 때 **측정을 무효로 만드는 설정**, **계측**, **용량 손잡이**를 정한다.
부하 모델 · 지표 · 통계 판정 · 대상 호스트 안전은 `common-stress-test` 의 `stress-test-rules.md` (`ST-xx`) 가 맡는다.

기계 검증: [`scripts/gin-stress-config-validate.sh`](../scripts/gin-stress-config-validate.sh) — CLI 는 차단 조항이 있으면 종료 2, 훅은 부하 도구 실행 전에 **경고만** 한다.
확인 버전: Go 1.25.14 · Gin v1.12.0 · prometheus/client_golang v1.24.1 · k6 v2.3.0.

## 1. 기계 판정 조항

| 조항 | 내용 | 판정 | 근거 |
|---|---|---|---|
| `GIN-01` | debug 모드로 띄우지 않는다 — 코드 `gin.SetMode(gin.DebugMode)` · 배포 파일 `GIN_MODE=debug` | **차단** | Gin 소스 `mode.go` · `gin.go` `LoadHTMLGlob` · `render/html.go` `HTMLDebug` — 실측 2 |
| `GIN-02` | release 모드를 코드나 배포 파일 어딘가에서 지정한다 | 경고 | Gin 소스 `mode.go` `SetMode("")` → debug |
| `GIN-03` | 요청마다 접근 로그를 쓰는 `gin.Default()` · `gin.Logger*()` 는 운영과 같은 설정일 때만 쓴다 | 경고 | Gin 소스 `gin.go` `Default` (Logger · Recovery 부착) · `logger.go` |
| `GIN-04` | pprof 를 공개 주소에 열지 않는다 — `_ "net/http/pprof"` + 루프백 아닌 `ListenAndServe(addr, nil)` 은 차단, 주소가 변수면 · gin-contrib/pprof 등록은 경고 | **차단** / 경고 | Go 문서 `net/http/pprof` 패키지 설명 (DefaultServeMux 에 등록) |
| `GIN-05` | `-race` 빌드로 부하를 재지 않는다 — Dockerfile · compose · k8s 는 차단, Makefile · 셸은 경고 (`go test -race` 는 보지 않는다) | **차단** / 경고 | Go 문서 "Data Race Detector" Runtime Overhead 절 — 실측 4 |
| `GIN-06` | `GOMAXPROCS` 를 손으로 고정하지 않는다 — 환경 변수 · `runtime.GOMAXPROCS(n>0)` | 경고 | Go 1.25 릴리스 노트 Runtime 절 — 실측 5 |
| `GIN-07` | 컨테이너로 배포하면 `go.mod` 의 `go` 를 1.25 이상으로 둔다 (automaxprocs · `GOMAXPROCS` 가 없을 때) | 경고 | Go 문서 "Go, Backwards Compatibility, and GODEBUG" · Go 소스 `internal/godebugs/table.go` `containermaxprocs` Changed 25 Old "0" — 실측 5 |
| `GIN-08` | 앱 서버는 타임아웃이 있는 `http.Server` 로 연다 — `engine.Run()` · `http.ListenAndServe` · 타임아웃 없는 `http.Server{}` | 경고 | Go 소스 `net/http/server.go` `Server` 필드 주석 · Gin 소스 `gin.go` `Run` |
| `GIN-09` | `database/sql` 풀은 `SetMaxOpenConns` 와 `SetMaxIdleConns` 를 둔다 | 경고 | Go 문서 `database/sql` `DB.SetMaxOpenConns` (기본 0 = 무제한) · `SetMaxIdleConns` (기본 2) |
| `GIN-10` | 지연은 Histogram 으로 잰다 — Summary `Objectives` 경고, 히스토그램이 없으면 경고 | 경고 | Prometheus 문서 "Histograms and summaries" · client_golang `SummaryOpts.Objectives` 주석 |
| `GIN-11` | 메트릭 라벨에 원시 경로(`URL.Path` · `RequestURI`)를 쓰지 않는다 — `c.FullPath()` | 경고 | Prometheus 문서 "Instrumentation" Do not overuse labels 절 |
| `GIN-12` | GC 를 끄면(`GOGC=off` · `SetGCPercent(-1)`) `GOMEMLIMIT` 를 같이 둔다 | 경고 | Go 문서 "A Guide to the Go Garbage Collector" Memory limit 절 |

검사 대상: `*.go`(`_test.go` · `vendor/` · `testdata/` 제외, `//` 로 시작하는 줄 제외) · `Dockerfile*` · `Containerfile*` · `*.yml` · `*.yaml` · `.env*` · `Makefile` · `*.mk` · `*.sh`.
환경 변수는 `KEY=v` · `KEY: v` · `ENV KEY v` · k8s `name:` / `value:` 쌍을 읽는다.

## 2. AI 판단 조항

| 조항 | 내용 | 근거 |
|---|---|---|
| `GIN-20` | DB 풀 크기는 Little 의 L 상한이다 — `SetMaxOpenConns` ≥ 목표 λ × DB 보유 시간. 포화하면 `DBStats.WaitCount` · `WaitDuration` 이 는다 (`collectors.NewDBStatsCollector`) | `database/sql` `DBStats` · research 2.1 — 실측 1 |
| `GIN-21` | `GOMEMLIMIT` 는 컨테이너 메모리 한도에서 5~10% 여유를 뺀 값 | GC 가이드 "leave an additional 5-10% of headroom" |
| `GIN-22` | `GOMAXPROCS` 는 CPU **limit** 만 따른다 (request 는 보지 않는다). 소수 limit 은 올림, 최소 2 | Go 1.25 릴리스 노트 · Go 소스 `runtime/cgroup_linux.go` `adjustCgroupGOMAXPROCS` |
| `GIN-23` | 부하 중 프로파일은 루프백 · 별도 mux 의 pprof 에서 정상 상태 구간에만 받는다 | `net/http/pprof` (`seconds` 기본 30) — 실측 6 |
| `GIN-24` | 서버 in-flight 평균과 X·W 가 어긋나면 대기가 핸들러 밖(커널 accept 큐 · CFS 스로틀 · 부하기)에 있다 — 측정 경계를 먼저 고친다 | research 2.1 · `ST-13` — 실측 1 · 5 |
| `GIN-25` | 코드 수준 비교는 `go test -bench -benchmem -count=10` 이상 + `benchstat` (Mann-Whitney U, α 0.05) | benchstat 문서 — [`go-microbenchmark.md`](go-microbenchmark.md) |
| `GIN-26` | 미들웨어 · 로깅 비용은 지연보다 **요청당 CPU**(`process_cpu_seconds_total` 증가 / 요청 수)로 비교한다 — 공유 호스트에서는 지연 분위수가 노이즈에 묻힌다 | 실측 3 |

## 3. 사실 — 확인한 동작

### Gin 모드 (Gin v1.12.0 소스)

- `GIN_MODE` 는 패키지 `init()` 에서 읽는다. 비어 있으면 debug (테스트 바이너리면 test). 알 수 없는 값이면 panic
- debug 모드가 하는 일
  - 시작할 때 `[WARNING] Running in "debug" mode` · 라우트 목록 · `gin.Default()` 경고 · 신뢰 프록시 경고를 출력한다
  - `LoadHTMLGlob` · `LoadHTMLFiles` · `LoadHTMLFS` 가 `render.HTMLDebug` 를 쓴다 — **렌더할 때마다 템플릿 파일을 다시 파싱한다**
  - Recovery 가 panic 때 요청 덤프를 같이 찍는다
- HTML 템플릿이 없으면 debug 모드의 요청당 비용은 거의 없다. 그래도 운영 설정이 아니므로 차단한다 (`GIN-01`)
- `gin.Default()` = `New()` + `Logger()` + `Recovery()`. `Logger` 는 모드와 상관없이 요청마다 `DefaultWriter`(stdout)에 쓴다
- `engine.Run()` 은 `&http.Server{Addr, Handler}` 만 채워 연다 — 타임아웃이 없다

### net/http 서버 타임아웃 (Go 1.25 소스)

| 필드 | 0 일 때 |
|---|---|
| `ReadTimeout` | 타임아웃 없음 |
| `ReadHeaderTimeout` | `ReadTimeout` 값을 쓴다. 둘 다 0 이면 없음 |
| `WriteTimeout` | 타임아웃 없음 |
| `IdleTimeout` | `ReadTimeout` 값을 쓴다. 둘 다 0 이면 없음 |

### GOMAXPROCS (Go 1.25 릴리스 노트 · GODEBUG 문서 · 런타임 소스)

- Linux 에서 cgroup CPU bandwidth limit 이 논리 CPU 수보다 작으면 그 값을 기본으로 한다. 값이 바뀌면 주기적으로 갱신한다
- `GOMAXPROCS` 환경 변수나 `runtime.GOMAXPROCS` 호출로 정하면 둘 다 꺼진다. `GODEBUG=containermaxprocs=0` · `updatemaxprocs=0` 으로도 끈다
- **`go.mod` 의 `go` 가 1.25 미만이면 1.25 툴체인으로 빌드해도 꺼진다** — GODEBUG 기본값이 모듈의 go 버전을 따른다 (릴리스 노트에는 없다. 실측 5)

### GC

- `GOGC` 기본 100. `off` 는 GC 를 끈다. 메모리 한도 기본은 사실상 없음(`math.MaxInt64`)
- `GOGC=off` 와 메모리 한도를 같이 쓰면 한도 근처에서 GC 가 계속 돌 수 있다 (thrashing). 둘 다 없으면 힙이 끝없이 자란다

### database/sql

- `SetMaxOpenConns(n)` — `n <= 0` 이면 무제한, 기본 0
- `SetMaxIdleConns` 기본 2 (`defaultMaxIdleConns = 2`). 유휴가 다 차 있으면 반납한 커넥션을 닫는다 (`DBStats.MaxIdleClosed` 가 는다) — 동시 사용이 2를 넘으면 닫고 다시 열기를 되풀이한다

## 4. 실측 요약

Docker Desktop (arm64, 8 vCPU) · 대상 컨테이너 `--cpus=2` · k6 open 모델 단계 15초. 같은 호스트에서 다른 부하가 같이 돌아 지연 분위수는 흔들렸다.

1. 풀 10 · 보유 20 ms 엔드포인트: 처리량이 **474 rps** 에서 멈췄다 (10 / 0.0211 s). 450 rps 까지 p99 25 ms, 500 rps 부터 p99 798 ms. 정상 단계에서 in-flight 와 X·W 가 ±4~10% 안에서 맞았다
2. debug vs release, HTML 템플릿 렌더 (`go test -bench -count=10` + benchstat): 4.8 µs → 377 µs (+7727%, p=0.000), 할당 56 → 191. 부하에서는 2000 rps 에서 요청당 CPU 88~104 µs → 137~251 µs
3. `gin.Default()` Logger: 요청당 CPU 92~124 µs (release 88~104 µs) — 차이가 노이즈 폭 안이라 결론 내지 못했다
4. `-race` 바이너리: 요청당 CPU 4~7배, RSS 83 → 934~1335 MiB
5. `--cpus=2` 에서 `GOMAXPROCS=8` 고정: CFS 스로틀 954 주기 중 291 (30.5%), 누적 50.6 s. 자동(2)은 974 중 9, 6.6 ms
6. 루프백에 바인드한 pprof 는 같은 네트워크의 다른 컨테이너에서 접속이 안 됐고, `docker run --network container:<앱>` 으로 10초 CPU 프로파일을 받았다
