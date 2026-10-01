# go-gin-stress-test

Go · Gin 서버를 부하 측정할 때 프레임워크 몫을 맡는다 — Prometheus 지연 히스토그램 · in-flight · 런타임 계측, 측정을 무효로 만드는 설정(debug 모드 · `-race` 빌드 · pprof 공개 · GOMAXPROCS 고정) 탐지, GOMAXPROCS · GOMEMLIMIT · 서버 타임아웃 · DB 풀 손잡이 점검, `go test -bench` · `benchstat` 마이크로벤치마크.

부하 모델 · 판정 통계 · 대상 호스트 안전은 `common-stress-test` 가 맡는다. 근거는 Gin 소스(`mode.go` · `gin.go` · `render/html.go`) · Go 1.25 릴리스 노트 · GODEBUG 문서 · `net/http` · `database/sql` · `net/http/pprof` 문서 · Go GC 가이드 · race detector 문서 · Prometheus "Histograms and summaries" · client_golang 소스 · benchstat 문서다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install go-gin-stress-test@plugin-marketplace
```

## 의존성

- `common-stress-test` — 부하 스크립트 작성(`stress-test-create`) · 결과 판정(`stress-result-review`) · 대상 호스트 안전

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| gin-stress-test-apply | Gin 부하 테스트 · golang 성능 · GIN_MODE · pprof · GOMAXPROCS · benchstat | 무효 설정 제거 → 서버 측 계측 → 손잡이 기록 → 마이크로벤치마크 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| gin-stress-config-validate.sh | PreToolUse (Bash) | 부하 도구 실행(`k6 run` · `locust` · `jmeter` · `gatling` · `wrk` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon` · `docker run … grafana/k6`)일 때만 프로젝트를 검사해 **경고**로 알린다. 막지 않는다 |

## 주의

- 줄 단위로 본다. 문법 분석기가 없어 `//` 로 시작하는 줄만 주석으로 빼고, 블록 주석 · 문자열 안의 코드처럼 보이는 글자도 읽는다
- 환경 변수는 `Dockerfile*` · `Containerfile*` · `*.yml` · `*.yaml` · `.env*` 에서만 읽는다. Helm 템플릿 · 코드에서 조합한 값 · 실행 인자는 보지 않는다 — 떠 있는 프로세스의 `/metrics` 로 확인한다
- `_test.go` · `vendor/` · `testdata/` 는 보지 않는다. `go test -race` 는 대상이 아니다
- pprof 주소가 변수면 루프백인지 알 수 없어 경고로 낮춘다
- `jq` 가 필요하다 (훅 모드)

## 규칙 요약

| 조항 | 규칙 | 판정 |
|---|---|---|
| `GIN-01` | debug 모드로 띄우지 않는다 | 차단 |
| `GIN-02` | release 모드를 어딘가에서 지정한다 | 경고 |
| `GIN-03` | 요청마다 접근 로그(`gin.Default` · `gin.Logger`)는 운영과 같을 때만 | 경고 |
| `GIN-04` | pprof 를 공개 주소에 열지 않는다 | 차단 / 경고 |
| `GIN-05` | `-race` 빌드로 부하를 재지 않는다 | 차단 / 경고 |
| `GIN-06` | `GOMAXPROCS` 를 손으로 고정하지 않는다 | 경고 |
| `GIN-07` | 컨테이너 배포면 `go.mod` 의 `go` ≥ 1.25 | 경고 |
| `GIN-08` | 앱 서버는 타임아웃 있는 `http.Server` | 경고 |
| `GIN-09` | `SetMaxOpenConns` · `SetMaxIdleConns` 를 둔다 | 경고 |
| `GIN-10` | 지연은 Histogram 으로 (Summary `Objectives` X) | 경고 |
| `GIN-11` | 메트릭 라벨에 원시 경로 X → `c.FullPath()` | 경고 |
| `GIN-12` | GC 를 끄면 `GOMEMLIMIT` 도 | 경고 |
| `GIN-20` ~ `GIN-26` | 풀 크기 · 메모리 한도 · 프로파일 · Little · 마이크로벤치마크 · 요청당 CPU | AI 판단 |

원본: [`references/gin-stress-rules.md`](references/gin-stress-rules.md)

## 사용

```bash
scripts/gin-stress-config-validate.sh .          # 프로젝트 검사 — 종료 2 면 차단 조항 위반
test/gin-stress-config-validate.test.sh          # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
