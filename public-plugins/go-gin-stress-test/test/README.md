# Go · Gin 부하 측정 설정 테스트

`scripts/gin-stress-config-validate.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/gin-stress-config-validate.test.sh           # 전체
test/gin-stress-config-validate.test.sh TC-S1     # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. macOS 기본 bash 3.2 에서도 돈다.

## 자동 TC (38건)

픽스처는 **규칙을 지키는 Gin 앱**(`main.go` · `go.mod` go 1.25 · `Dockerfile`)이고, TC 마다 새 디렉터리에 복사해 한 곳만 깨뜨린다. 과잉 탐지(잡으면 안 되는 것)를 막는 TC 를 조항마다 둔다.

### A. CLI 조항 (GIN-01 ~ GIN-12)

| ID | 케이스 |
|---|---|
| TC-S01 | 규칙을 지킨 Gin 프로젝트는 조용히 통과한다 |
| TC-S02 | Go 파일이 없으면 보지 않는다 |
| TC-S03 | 없는 디렉터리는 오류(1)다 |
| TC-S10 | 코드의 gin.SetMode(gin.DebugMode) 를 막는다 (GIN-01) |
| TC-S11 | 배포 파일의 GIN_MODE=debug 를 막는다 — .env · compose · Dockerfile ENV · k8s name/value (GIN-01) |
| TC-S12 | release · 주석 처리한 debug · 다른 키 이름은 막지 않는다 (GIN-01 과잉 차단 방지) |
| TC-S13 | release 지정이 어디에도 없으면 경고한다 (GIN-02) |
| TC-S14 | 배포 파일에 GIN_MODE=release 가 있으면 코드에 없어도 경고하지 않는다 (GIN-02 과잉 경고 방지) |
| TC-S20 | gin.Default() · gin.Logger() 를 경고한다 (GIN-03) |
| TC-S21 | gin.New() + gin.Recovery() 는 경고하지 않는다 (GIN-03 과잉 경고 방지) |
| TC-S30 | _ net/http/pprof + 공개 주소 DefaultServeMux 를 막는다 (GIN-04) |
| TC-S31 | 주소가 변수면 경고, gin-contrib/pprof 등록도 경고한다 (GIN-04) |
| TC-S32 | 루프백 바인드 · 별도 mux 의 pprof 는 막지 않는다 (GIN-04 과잉 차단 방지) |
| TC-S40 | Dockerfile 의 go build -race 를 막고 Makefile 은 경고한다 (GIN-05) |
| TC-S41 | compose 의 GOFLAGS=-race 를 막는다 (GIN-05) |
| TC-S42 | go test -race · -racex 같은 다른 플래그는 보지 않는다 (GIN-05 과잉 차단 방지) |
| TC-S50 | GOMAXPROCS 환경 변수 · runtime.GOMAXPROCS(n) 고정을 경고한다 (GIN-06) |
| TC-S51 | runtime.GOMAXPROCS(0) 조회는 경고하지 않는다 (GIN-06 과잉 경고 방지) |
| TC-S52 | 컨테이너 배포 + go.mod 의 go 가 1.25 미만이면 경고한다 (GIN-07) |
| TC-S53 | go 1.25 이상 · Dockerfile 없음 · automaxprocs 사용이면 경고하지 않는다 (GIN-07 과잉 경고 방지) |
| TC-S60 | gin 엔진의 Run() · 공개 http.ListenAndServe · 타임아웃 없는 http.Server 를 경고한다 (GIN-08) |
| TC-S61 | 다른 객체의 Run() · 루프백 ListenAndServe · ReadTimeout 만 있는 서버는 경고하지 않는다 (GIN-08 과잉 경고 방지) |
| TC-S70 | sql.Open 에 SetMaxOpenConns 가 없으면 경고한다 (GIN-09) |
| TC-S71 | SetMaxOpenConns 만 있고 SetMaxIdleConns 가 없으면 경고한다 (GIN-09) |
| TC-S72 | DB 를 쓰지 않으면 보지 않는다 (GIN-09 과잉 경고 방지) |
| TC-S80 | Summary Objectives 와 히스토그램 부재를 경고한다 (GIN-10) |
| TC-S81 | OpenTelemetry Float64Histogram 도 히스토그램으로 본다 (GIN-10 과잉 경고 방지) |
| TC-S82 | 라벨에 URL.Path · RequestURI 를 쓰면 경고한다 (GIN-11) |
| TC-S83 | c.FullPath() 라벨과 라벨 밖의 URL.Path 는 경고하지 않는다 (GIN-11 과잉 경고 방지) |
| TC-S90 | GOGC=off · SetGCPercent(-1) 에 메모리 한도가 없으면 경고한다 (GIN-12) |
| TC-S91 | GOMEMLIMIT · SetMemoryLimit 가 있거나 GOGC 가 숫자면 경고하지 않는다 (GIN-12 과잉 경고 방지) |
| TC-S95 | _test.go · vendor/ · testdata/ · .claude/worktrees 는 보지 않는다 |
| TC-S96 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-S100 | k6 run 이면 위반을 additionalContext 경고로 알리고 막지 않는다 |
| TC-S101 | docker run grafana/k6 · wrk · hey · vegeta attack · 환경 변수 접두 · 파이프 뒤 명령도 부하 도구로 본다 |
| TC-S102 | 부하 도구가 아닌 명령은 조용히 통과한다 |
| TC-S103 | 위반 없는 프로젝트면 부하 명령이어도 조용하다 |
| TC-S104 | 빈 입력 · PostToolUse · Bash 가 아닌 도구는 통과한다 |
