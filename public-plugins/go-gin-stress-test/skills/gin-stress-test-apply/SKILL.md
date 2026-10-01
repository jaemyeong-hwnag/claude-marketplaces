---
name: gin-stress-test-apply
description: Go · Gin 서버를 부하 · 스트레스 측정할 수 있게 준비한다 — 지연 히스토그램 · in-flight 계측, debug 모드 · -race · pprof 공개 같은 무효 설정 제거, GOMAXPROCS · GOMEMLIMIT · DB 풀 점검, benchstat 마이크로벤치마크. Go 서버 성능 측정을 준비할 때 사용한다. 트리거 — "Gin 부하 테스트", "golang 성능", "GIN_MODE", "pprof", "GOMAXPROCS", "go test -bench", "benchstat".
---

# Go · Gin 부하 측정 준비

규칙 원본: [`references/gin-stress-rules.md`](../../references/gin-stress-rules.md)
계측 레시피: [`references/gin-instrumentation-recipe.md`](../../references/gin-instrumentation-recipe.md)
마이크로벤치마크: [`references/go-microbenchmark.md`](../../references/go-microbenchmark.md)
기계 검증: [`scripts/gin-stress-config-validate.sh`](../../scripts/gin-stress-config-validate.sh)

이 스킬은 **Go · Gin 쪽**만 맡는다. 부하 스크립트 작성(open 모델 · 단계)은 `common-stress-test` 의 `stress-test-create`, 결과 판정(SLO · knee · Little · 회귀)은 `stress-result-review` 에 넘긴다.

## 1. 무효 설정부터 없앤다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/gin-stress-config-validate.sh" .
```

`❌` 가 있으면 측정하지 않는다. 훅은 부하 도구(`k6 run` · `wrk` · `hey` · `vegeta attack` …)를 실행할 때 같은 검사를 알림으로 보여 준다.

| 조항 | 고칠 것 |
|---|---|
| `GIN-01` ❌ | `GIN_MODE=release` 또는 `gin.SetMode(gin.ReleaseMode)`. debug 는 HTML 템플릿을 요청마다 다시 파싱한다 — 실측 렌더 4.8 µs → 377 µs |
| `GIN-04` ❌ | pprof 를 `127.0.0.1` 에 바인드한 별도 mux 로 옮긴다 |
| `GIN-05` ❌ | 이미지 빌드에서 `-race` 를 뺀다. 실측 요청당 CPU 4~7배 · RSS 11~16배 |
| `GIN-02` | 배포 파일이나 코드에 release 를 명시한다 |
| `GIN-03` | 운영에 접근 로그가 없으면 `gin.Default()` → `gin.New()` + `gin.Recovery()` |
| `GIN-06` · `GIN-07` | `GOMAXPROCS` 고정을 지우고 `go.mod` 의 `go` 를 1.25 이상으로 |
| `GIN-08` | `r.Run()` 대신 타임아웃을 채운 `http.Server` |
| `GIN-09` | `SetMaxOpenConns` · `SetMaxIdleConns` 를 둔다 (3절) |
| `GIN-10` · `GIN-11` | 2절 계측으로 바꾼다 |
| `GIN-12` | `GOGC=off` 를 쓰면 `GOMEMLIMIT` 도 |

스크립트는 줄 단위로 본다. 환경 변수를 코드에서 조합하거나 Helm values 로 넘기면 놓친다 — 실제로 뜬 프로세스에서 확인한다.

```bash
curl -s <앱>:9090/metrics | grep -E '^go_sched_gomaxprocs_threads|^go_info'
docker logs <앱> 2>&1 | grep -m1 'GIN-debug'      # 나오면 debug 모드다
```

## 2. 서버 측 계측을 붙인다

[`gin-instrumentation-recipe.md`](../../references/gin-instrumentation-recipe.md) 대로.

1. 지연 **Histogram** — 라벨 `method` · `route`(`c.FullPath()`) · `code`. Summary `Objectives` 는 인스턴스끼리 합칠 수 없다
2. in-flight 게이지 — `promhttp.InstrumentHandlerInFlight(gauge, engine)`
3. `/metrics` · pprof 는 앱 라우터와 다른 포트, pprof 는 루프백
4. DB 를 쓰면 `collectors.NewDBStatsCollector(db, "main")`
5. 붙인 뒤 `/metrics` 에 `http_server_request_duration_seconds_bucket` · `http_server_requests_in_flight` 가 나오는지 확인한다

SLO 경계(예: 100 ms)를 버킷 경계로 넣는다. 경계 사이 값은 보간이라 오차가 난다.

## 3. 용량 손잡이를 기록한다

결과 보고서에 실제 값을 적는다 (`ST-33`). 기본값은 [규칙 3절](../../references/gin-stress-rules.md).

| 손잡이 | 포화에 미치는 영향 | 확인 |
|---|---|---|
| `GOMAXPROCS` | CPU 바운드 용량의 상한. CPU limit 보다 크면 CFS 스로틀 — 실측 `--cpus=2` 에 8 고정 시 주기의 30.5% 스로틀 | `go_sched_gomaxprocs_threads`, `cpu.stat` |
| `SetMaxOpenConns` | DB 대기 요청의 상한 = Little 의 L. 용량 ≈ 풀 크기 / DB 보유 시간 — 실측 풀 10 · 20 ms 에서 474 rps 에서 멈췄다 | `go_sql_wait_count_total` 증가 |
| `SetMaxIdleConns` | 기본 2. 동시 사용이 넘으면 닫고 다시 열기 반복 | `go_sql_max_idle_closed_total` |
| `GOGC` · `GOMEMLIMIT` | GC 빈도 ↔ 메모리. 한도는 컨테이너 메모리의 90~95% | `go_gc_duration_seconds_count` |
| `http.Server` 타임아웃 | 과부하 때 요청이 끝없이 쌓이는지, 끊기는지를 정한다 | 에러율 · in-flight |

포화를 지나면 in-flight 가 단계마다 커진다 (실측 500 → 600 rps 에서 187 → 930). 풀 대기 시간 히스토그램을 따로 두면 대기가 어디서 생기는지 바로 보인다.

## 4. 측정 중

- 대상 컨테이너에 CPU · 메모리 limit 을 두고 그 값을 기록한다. 부하기와 대상이 같은 호스트면 부하기가 병목인지 본다 (`ST-34`)
- 단계마다 in-flight 평균과 X·W 를 비교한다. in-flight 가 X·W 보다 훨씬 작으면 대기가 핸들러 밖(커널 큐 · CFS 스로틀 · 부하기)에 있다 (`GIN-24`)
- CPU 프로파일은 정상 상태 구간에서 받는다 — 레시피 6절
- 설정 하나를 바꿔 비교할 때는 요청당 CPU 도 같이 본다. 공유 호스트에서는 p95 · p99 가 노이즈에 묻혔다 (`GIN-26`)

## 5. 코드 수준 비교 — 마이크로벤치마크

[`go-microbenchmark.md`](../../references/go-microbenchmark.md) 대로.

```bash
go test -run='^$' -bench=. -benchmem -count=10 -cpu=2 ./... > old.txt
# 변경 후
go test -run='^$' -bench=. -benchmem -count=10 -cpu=2 ./... > new.txt
benchstat old.txt new.txt
```

`~` 면 차이 없음, `p=` 는 Mann-Whitney U. 신뢰구간이 ±10% 를 넘으면 다시 잰다.

## 6. 넘긴다

계측 · 설정이 끝나면 `common-stress-test` 로 넘긴다.

- 부하 스크립트 · 단계 설계 → `stress-test-create`
- 단계 CSV 판정 · 회귀 비교 → `stress-result-review`
