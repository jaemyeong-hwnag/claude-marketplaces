# Go 마이크로벤치마크 절차 (`go test -bench` + `benchstat`)

핸들러 · 미들웨어 · 직렬화 같은 코드 수준 변경을 비교할 때 쓴다. 서버 전체의 용량은 부하 테스트(`common-stress-test`)로 잰다.
확인 버전: Go 1.25.14 (`testing.B.Loop`), benchstat `golang.org/x/perf` 2026-09-29 빌드. 아래 출력은 실제로 돌린 것이다.

## 1. 벤치마크 작성

```go
func newEngine(mode string) *gin.Engine {
	gin.DefaultWriter = io.Discard // 디버그 출력이 벤치 줄 사이에 끼면 benchstat 이 그 줄을 버린다
	gin.SetMode(mode)
	r := gin.New()
	r.LoadHTMLGlob("templates/*")
	r.GET("/html", func(c *gin.Context) {
		c.HTML(http.StatusOK, "page.tmpl", gin.H{"title": "t"})
	})
	return r
}

func BenchmarkHTML(b *testing.B) {
	r := newEngine(gin.Mode())
	req := httptest.NewRequest(http.MethodGet, "/html", nil)
	b.ReportAllocs()
	for b.Loop() { // Go 1.24+. 준비 코드는 루프 밖에서 한 번만 돈다
		r.ServeHTTP(httptest.NewRecorder(), req)
	}
}
```

- 엔진 · 요청 준비는 루프 밖에 둔다. `b.Loop()` 이전 버전이면 준비 뒤 `b.ResetTimer()` 를 부른다
- 결과를 버리는 순수 계산은 컴파일러가 지울 수 있다 — 결과를 패키지 변수에 담거나 `b.Loop()` 를 쓴다
- 테스트에서 Gin 은 `GIN_MODE` 가 비면 test 모드다. 비교 대상 모드를 `SetMode` 로 명시한다

## 2. 실행

```bash
# 비교할 두 상태를 같은 머신에서 같은 조건으로. -cpu 를 고정한다
go test -run='^$' -bench=HTML -benchmem -count=10 -cpu=2 . > old.txt
# 코드 · 설정을 바꾼 뒤
go test -run='^$' -bench=HTML -benchmem -count=10 -cpu=2 . > new.txt

go install golang.org/x/perf/cmd/benchstat@latest
benchstat old.txt new.txt
```

| 옵션 | 이유 |
|---|---|
| `-run='^$'` | 단위 테스트를 같이 돌리지 않는다 |
| `-count=10` 이상 | benchstat 문서 권장 "at least 10 times". 6 미만이면 신뢰구간을 못 낸다 (`± ∞`) |
| `-benchmem` | B/op · allocs/op — 할당은 노이즈가 거의 없어 먼저 본다 |
| `-cpu=N` | GOMAXPROCS 를 고정해 두 실행을 같은 조건으로 |
| `-benchtime` | 기본 1s. 한 번이 느린 벤치는 `-benchtime=100x` 처럼 횟수로 |

- 두 상태를 번갈아 여러 번 돌리면 시간에 따른 머신 상태 변화가 한쪽에 몰리지 않는다
- 최신 benchstat 은 go 1.26 이상을 요구했다 (`requires go >= 1.26.0`). 프로젝트 툴체인이 낮으면 별도 이미지(`golang:latest`)에서 설치해 결과 파일만 읽힌다

## 3. 출력 읽기

실측 — Gin HTML 렌더, release vs debug 모드 (`-count=10 -cpu=2`):

```
       │ release.txt  │                debug.txt                 │
       │    sec/op    │     sec/op      vs base                  │
HTML-2   4.816µ ± 20%   376.951µ ± 15%  +7727.06% (p=0.000 n=10)

       │ release.txt │              debug.txt               │
       │  allocs/op  │  allocs/op   vs base                 │
HTML-2    56.00 ± 0%   191.00 ± 0%  +241.07% (p=0.000 n=10)
```

| 칸 | 뜻 |
|---|---|
| `4.816µ ± 20%` | 중앙값과 중앙값의 95% 신뢰구간 (`-confidence` 기본 0.95) |
| `+7727.06%` | 중앙값 변화 |
| `p=0.000 n=10` | Mann-Whitney U 검정 p 값과 표본 수. α 기본 0.05 (`-alpha`) |
| `~` | 유의한 차이 없음 — 이때 % 는 내지 않는다 |
| 마지막 `geomean` 줄 | 벤치가 여럿이면 전체 기하평균 변화 |

- benchstat 문서: 기본은 비모수 — 요약은 중앙값, A/B 비교는 Mann-Whitney U. α=0.05 이므로 차이가 없어도 5% 는 차이가 있다고 나온다. 벤치마크가 많으면 그만큼 거짓 양성이 섞인다
- 신뢰구간이 ±10% 를 넘으면 머신이 시끄럽다 — 반복을 늘리거나 다른 부하를 끄고 다시 잰다
- 디버그 출력이 섞였을 때 benchstat 은 `parsing iteration count: invalid syntax` 를 내고 그 줄을 버렸다 (n=10+1). 표본 수가 기대와 같은지 확인한다

## 4. 하지 않는다

- `-race` 를 붙여 성능을 재지 않는다 (`GIN-05`)
- 한 번 실행한 `ns/op` 두 개를 비교하지 않는다
- 마이크로벤치 결과로 서버 용량을 말하지 않는다 — 네트워크 · 스케줄링 · GC 압력이 빠져 있다
