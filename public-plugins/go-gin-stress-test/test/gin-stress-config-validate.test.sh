#!/usr/bin/env bash
# scripts/gin-stress-config-validate.sh 의 회귀 테스트.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/gin-stress-config-validate.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gin-stress-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-9s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
fail_tc() { [ "$TC_ON" = 1 ] || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { [ "$TC_ON" = 1 ] || return 0; OUT="$("$SCRIPT" "$@" 2>&1 </dev/null)"; CODE=$?; }
run_stdin_in() { [ "$TC_ON" = 1 ] || return 0; OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" "$SCRIPT" 2>&1)"; CODE=$?; }
expect_code() { [ "$TC_ON" = 1 ] || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_no_out() { [ "$TC_ON" = 1 ] || return 0; [ -z "$OUT" ] || fail_tc "출력이 있으면 안 됩니다: $OUT"; }
expect_not() { [ "$TC_ON" = 1 ] || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }

# --- 픽스처 ------------------------------------------------------------------
# 규칙을 지키는 Gin 앱. TC 마다 복사해 한 곳만 깨뜨린다
CLEAN_GO='package main

import (
	"database/sql"
	"net/http"
	"net/http/pprof"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var duration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
	Name: "http_server_request_duration_seconds",
}, []string{"method", "route", "code"})

func main() {
	gin.SetMode(gin.ReleaseMode)
	db, _ := sql.Open("pgx", "dsn")
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(20)

	r := gin.New()
	r.Use(gin.Recovery(), func(c *gin.Context) {
		c.Next()
		duration.WithLabelValues(c.Request.Method, c.FullPath(), strconv.Itoa(c.Writer.Status())).Observe(1)
	})

	dbg := http.NewServeMux()
	dbg.HandleFunc("/debug/pprof/", pprof.Index)
	go http.ListenAndServe("127.0.0.1:6060", dbg)

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      10 * time.Second,
	}
	_ = promhttp.Handler()
	srv.ListenAndServe()
}
'
proj() { # 새 프로젝트 → 경로
  local d; d="$(mktemp -d "$TMP/p.XXXXXX")"
  printf 'module example.com/app\n\ngo 1.25\n' > "$d/go.mod"
  printf '%s' "$CLEAN_GO" > "$d/main.go"
  printf 'FROM golang:1.25 AS build\nRUN CGO_ENABLED=0 go build -o /app .\n' > "$d/Dockerfile"
  printf '%s' "$d"
}
# 픽스처 main.go 의 한 줄을 바꾼다 — $1=프로젝트 $2=찾을 문자열 $3=바꿀 문자열
patch() { local c; c="$(cat "$1/main.go"; printf x)"; c="${c%x}"; printf '%s' "${c/"$2"/$3}" > "$1/main.go"; }
payload_bash() { jq -n --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'; }

echo "go-gin-stress-test 회귀 테스트"

# --- A. 기본 -------------------------------------------------------------------
tc TC-S01 "규칙을 지킨 Gin 프로젝트는 조용히 통과한다"
p="$(proj)"; run "$p"; expect_code 0; expect_no_out

tc TC-S02 "Go 파일이 없으면 보지 않는다"
mkdir -p "$TMP/empty"; printf 'GIN_MODE=debug\n' > "$TMP/empty/.env"; run "$TMP/empty"; expect_code 0; expect_no_out

tc TC-S03 "없는 디렉터리는 오류(1)다"
run "$TMP/nope"; expect_code 1

# --- B. 모드 (GIN-01 · GIN-02) ---------------------------------------------------
tc TC-S10 "코드의 gin.SetMode(gin.DebugMode) 를 막는다 (GIN-01)"
p="$(proj)"; patch "$p" 'gin.SetMode(gin.ReleaseMode)' 'gin.SetMode(gin.DebugMode)'; run "$p"; expect_code 2; expect_out "❌ GIN-01 main.go:20"; expect_not "GIN-02"

tc TC-S11 "배포 파일의 GIN_MODE=debug 를 막는다 — .env · compose · Dockerfile ENV · k8s name/value (GIN-01)"
p="$(proj)"; printf 'GIN_MODE=debug\n' > "$p/.env"
printf 'services:\n  app:\n    environment:\n      GIN_MODE: "debug"\n' > "$p/compose.yaml"
printf 'FROM golang:1.25\nENV GIN_MODE debug\n' > "$p/Dockerfile"
mkdir -p "$p/k8s"; printf 'env:\n  - name: GIN_MODE\n    value: debug\n' > "$p/k8s/deploy.yaml"
run "$p"; expect_code 2; expect_out "GIN-01 .env:1"; expect_out "GIN-01 compose.yaml:4"; expect_out "GIN-01 Dockerfile:2"; expect_out "GIN-01 k8s/deploy.yaml:3"

tc TC-S12 "release · 주석 처리한 debug · 다른 키 이름은 막지 않는다 (GIN-01 과잉 차단 방지)"
p="$(proj)"; printf '# GIN_MODE=debug\nGIN_MODE=release\nMY_GIN_MODE=debug\n' > "$p/.env"
patch "$p" 'gin.SetMode(gin.ReleaseMode)' '// gin.SetMode(gin.DebugMode)'; run "$p"; expect_code 0; expect_no_out

tc TC-S13 "release 지정이 어디에도 없으면 경고한다 (GIN-02)"
p="$(proj)"; patch "$p" 'gin.SetMode(gin.ReleaseMode)' ''; run "$p"; expect_code 0; expect_out "⚠️ GIN-02"

tc TC-S14 "배포 파일에 GIN_MODE=release 가 있으면 코드에 없어도 경고하지 않는다 (GIN-02 과잉 경고 방지)"
p="$(proj)"; patch "$p" 'gin.SetMode(gin.ReleaseMode)' ''; printf 'FROM golang:1.25\nENV GIN_MODE=release\n' > "$p/Dockerfile"
run "$p"; expect_code 0; expect_no_out

# --- C. 접근 로그 (GIN-03) -------------------------------------------------------
tc TC-S20 "gin.Default() · gin.Logger() 를 경고한다 (GIN-03)"
p="$(proj)"; patch "$p" 'r := gin.New()' 'r := gin.Default()'; patch "$p" 'r.Use(gin.Recovery(),' 'r.Use(gin.Logger(),'
run "$p"; expect_code 0; expect_out "GIN-03 main.go:25"; expect_out "GIN-03 main.go:26"

tc TC-S21 "gin.New() + gin.Recovery() 는 경고하지 않는다 (GIN-03 과잉 경고 방지)"
p="$(proj)"; run "$p"; expect_not "GIN-03"

# --- D. pprof (GIN-04) ---------------------------------------------------------
tc TC-S30 "_ net/http/pprof + 공개 주소 DefaultServeMux 를 막는다 (GIN-04)"
p="$(proj)"; patch "$p" '"net/http/pprof"' '_ "net/http/pprof"'; patch "$p" 'go http.ListenAndServe("127.0.0.1:6060", dbg)' 'go http.ListenAndServe(":6060", nil)'
run "$p"; expect_code 2; expect_out "❌ GIN-04"

tc TC-S31 "주소가 변수면 경고, gin-contrib/pprof 등록도 경고한다 (GIN-04)"
p="$(proj)"; patch "$p" '"net/http/pprof"' '_ "net/http/pprof"'; patch "$p" 'go http.ListenAndServe("127.0.0.1:6060", dbg)' 'go http.ListenAndServe(addr, nil)'
patch "$p" '"github.com/gin-gonic/gin"' '"github.com/gin-gonic/gin"
	"github.com/gin-contrib/pprof"'
patch "$p" 'r := gin.New()' 'r := gin.New()
	pprof.Register(r)'
run "$p"; expect_code 0; expect_out "⚠️ GIN-04 main.go:"; expect_not "❌"

tc TC-S32 "루프백 바인드 · 별도 mux 의 pprof 는 막지 않는다 (GIN-04 과잉 차단 방지)"
p="$(proj)"; patch "$p" '"net/http/pprof"' '_ "net/http/pprof"'; patch "$p" 'go http.ListenAndServe("127.0.0.1:6060", dbg)' 'go http.ListenAndServe("localhost:6060", nil)'
run "$p"; expect_code 0; expect_not "GIN-04"

# --- E. -race (GIN-05) ---------------------------------------------------------
tc TC-S40 "Dockerfile 의 go build -race 를 막고 Makefile 은 경고한다 (GIN-05)"
p="$(proj)"; printf 'FROM golang:1.25\nRUN go build -race -o /app .\n' > "$p/Dockerfile"; printf 'run:\n\tgo run -race .\n' > "$p/Makefile"
run "$p"; expect_code 2; expect_out "❌ GIN-05 Dockerfile:2"; expect_out "⚠️ GIN-05 Makefile:2"

tc TC-S41 "compose 의 GOFLAGS=-race 를 막는다 (GIN-05)"
p="$(proj)"; printf 'services:\n  app:\n    environment:\n      - GOFLAGS=-race\n' > "$p/compose.yml"
run "$p"; expect_code 2; expect_out "GIN-05 compose.yml:4"

tc TC-S42 "go test -race · -racex 같은 다른 플래그는 보지 않는다 (GIN-05 과잉 차단 방지)"
p="$(proj)"; printf 'test:\n\tgo test -race ./...\n' > "$p/Makefile"; printf 'FROM golang:1.25\nRUN go build -racex -o /app .\n# RUN go build -race .\n' > "$p/Dockerfile"
run "$p"; expect_code 0; expect_no_out

# --- F. GOMAXPROCS (GIN-06 · GIN-07) ------------------------------------------------
tc TC-S50 "GOMAXPROCS 환경 변수 · runtime.GOMAXPROCS(n) 고정을 경고한다 (GIN-06)"
p="$(proj)"; printf 'FROM golang:1.25\nENV GOMAXPROCS=8\n' > "$p/Dockerfile"; patch "$p" 'gin.SetMode(gin.ReleaseMode)' 'gin.SetMode(gin.ReleaseMode)
	runtime.GOMAXPROCS(4)'
run "$p"; expect_code 0; expect_out "GIN-06 Dockerfile:2"; expect_out "GOMAXPROCS=8"; expect_out "GIN-06 main.go:21"

tc TC-S51 "runtime.GOMAXPROCS(0) 조회는 경고하지 않는다 (GIN-06 과잉 경고 방지)"
p="$(proj)"; patch "$p" 'gin.SetMode(gin.ReleaseMode)' 'gin.SetMode(gin.ReleaseMode)
	_ = runtime.GOMAXPROCS(0)'
run "$p"; expect_code 0; expect_no_out

tc TC-S52 "컨테이너 배포 + go.mod 의 go 가 1.25 미만이면 경고한다 (GIN-07)"
p="$(proj)"; printf 'module example.com/app\n\ngo 1.24.3\n' > "$p/go.mod"
run "$p"; expect_code 0; expect_out "GIN-07 go.mod:3"; expect_out "go 1.24"

tc TC-S53 "go 1.25 이상 · Dockerfile 없음 · automaxprocs 사용이면 경고하지 않는다 (GIN-07 과잉 경고 방지)"
p="$(proj)"; printf 'module example.com/app\n\ngo 1.26\n' > "$p/go.mod"; run "$p"; expect_not "GIN-07"
p="$(proj)"; printf 'module example.com/app\n\ngo 1.22\n' > "$p/go.mod"; rm "$p/Dockerfile"; run "$p"; expect_not "GIN-07"
p="$(proj)"; printf 'module example.com/app\n\ngo 1.22\n\nrequire go.uber.org/automaxprocs v1.6.0\n' > "$p/go.mod"; run "$p"; expect_not "GIN-07"

# --- G. 서버 타임아웃 (GIN-08) -----------------------------------------------------
tc TC-S60 "gin 엔진의 Run() · 공개 http.ListenAndServe · 타임아웃 없는 http.Server 를 경고한다 (GIN-08)"
p="$(proj)"; patch "$p" '	srv.ListenAndServe()' '	srv.ListenAndServe()
	r.Run(":9000")
	http.ListenAndServe(":8081", r)'
patch "$p" '		ReadHeaderTimeout: 5 * time.Second,
' ''
run "$p"; expect_code 0; expect_out "r.Run()"; expect_out "GIN-08 main.go:35"; expect_out "http.ListenAndServe 는"

tc TC-S61 "다른 객체의 Run() · 루프백 ListenAndServe · ReadTimeout 만 있는 서버는 경고하지 않는다 (GIN-08 과잉 경고 방지)"
p="$(proj)"; patch "$p" '	srv.ListenAndServe()' '	srv.ListenAndServe()
	cmd.Run()
	server.Run()'
patch "$p" 'ReadHeaderTimeout: 5 * time.Second' 'ReadTimeout: 5 * time.Second'
run "$p"; expect_code 0; expect_no_out

# --- H. DB 풀 (GIN-09) ---------------------------------------------------------
tc TC-S70 "sql.Open 에 SetMaxOpenConns 가 없으면 경고한다 (GIN-09)"
p="$(proj)"; patch "$p" '	db.SetMaxOpenConns(20)
' ''; run "$p"; expect_code 0; expect_out "GIN-09 main.go:21"; expect_out "SetMaxOpenConns"

tc TC-S71 "SetMaxOpenConns 만 있고 SetMaxIdleConns 가 없으면 경고한다 (GIN-09)"
p="$(proj)"; patch "$p" '	db.SetMaxIdleConns(20)
' ''; run "$p"; expect_code 0; expect_out "SetMaxIdleConns 가 없다"

tc TC-S72 "DB 를 쓰지 않으면 보지 않는다 (GIN-09 과잉 경고 방지)"
p="$(proj)"; patch "$p" '	db, _ := sql.Open("pgx", "dsn")
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(20)
' ''; run "$p"; expect_not "GIN-09"

# --- I. 계측 (GIN-10 · GIN-11) ---------------------------------------------------
tc TC-S80 "Summary Objectives 와 히스토그램 부재를 경고한다 (GIN-10)"
p="$(proj)"; patch "$p" 'prometheus.NewHistogramVec(prometheus.HistogramOpts{
	Name: "http_server_request_duration_seconds",' 'prometheus.NewSummaryVec(prometheus.SummaryOpts{
	Name: "http_server_request_duration_seconds",
	Objectives: map[float64]float64{0.99: 0.001},'
run "$p"; expect_code 0; expect_out "GIN-10 main.go:17"; expect_out "히스토그램이 없다"

tc TC-S81 "OpenTelemetry Float64Histogram 도 히스토그램으로 본다 (GIN-10 과잉 경고 방지)"
p="$(proj)"; patch "$p" 'prometheus.NewHistogramVec(prometheus.HistogramOpts{' 'prometheus.NewCounterVec(prometheus.CounterOpts{'
patch "$p" 'func main() {' 'var _, _ = meter.Float64Histogram("http.server.request.duration")

func main() {'
run "$p"; expect_code 0; expect_not "GIN-10"

tc TC-S82 "라벨에 URL.Path · RequestURI 를 쓰면 경고한다 (GIN-11)"
p="$(proj)"; patch "$p" 'c.FullPath()' 'c.Request.URL.Path'; run "$p"; expect_code 0; expect_out "GIN-11 main.go:28"
p="$(proj)"; patch "$p" 'c.FullPath()' 'c.Request.RequestURI'; run "$p"; expect_out "GIN-11"

tc TC-S83 "c.FullPath() 라벨과 라벨 밖의 URL.Path 는 경고하지 않는다 (GIN-11 과잉 경고 방지)"
p="$(proj)"; patch "$p" '		c.Next()' '		log.Println(c.Request.URL.Path)
		c.Next()'; run "$p"; expect_not "GIN-11"

# --- J. GC (GIN-12) ------------------------------------------------------------
tc TC-S90 "GOGC=off · SetGCPercent(-1) 에 메모리 한도가 없으면 경고한다 (GIN-12)"
p="$(proj)"; printf 'GOGC=off\n' > "$p/.env"; run "$p"; expect_code 0; expect_out "GIN-12 .env:1"
p="$(proj)"; patch "$p" 'gin.SetMode(gin.ReleaseMode)' 'gin.SetMode(gin.ReleaseMode)
	debug.SetGCPercent(-1)'; run "$p"; expect_out "GIN-12 main.go:21"

tc TC-S91 "GOMEMLIMIT · SetMemoryLimit 가 있거나 GOGC 가 숫자면 경고하지 않는다 (GIN-12 과잉 경고 방지)"
p="$(proj)"; printf 'GOGC=off\nGOMEMLIMIT=900MiB\n' > "$p/.env"; run "$p"; expect_not "GIN-12"
p="$(proj)"; printf 'GOGC=200\n' > "$p/.env"; run "$p"; expect_not "GIN-12"
p="$(proj)"; patch "$p" 'gin.SetMode(gin.ReleaseMode)' 'gin.SetMode(gin.ReleaseMode)
	debug.SetGCPercent(-1)
	debug.SetMemoryLimit(900 << 20)'; run "$p"; expect_not "GIN-12"

# --- K. 제외 -----------------------------------------------------------------
tc TC-S95 "_test.go · vendor/ · testdata/ · .claude/worktrees 는 보지 않는다"
p="$(proj)"; mkdir -p "$p/vendor/x" "$p/testdata" "$p/.claude/worktrees/w"
printf 'package x\n\nfunc f() { gin.SetMode(gin.DebugMode) }\n' | tee "$p/vendor/x/a.go" "$p/testdata/a.go" "$p/.claude/worktrees/w/a.go" > "$p/main_test.go"
run "$p"; expect_code 0; expect_no_out

tc TC-S96 "루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준)"
p="$TMP/.claude/worktrees/wt"; mkdir -p "$p"; printf 'module m\n\ngo 1.25\n' > "$p/go.mod"
printf 'package main\n\nfunc main() { gin.SetMode(gin.DebugMode) }\n' > "$p/main.go"
run "$p"; expect_code 2; expect_out "GIN-01"

# --- L. 훅 --------------------------------------------------------------------
BAD="$(proj)"; patch "$BAD" 'gin.SetMode(gin.ReleaseMode)' 'gin.SetMode(gin.DebugMode)'

tc TC-S100 "k6 run 이면 위반을 additionalContext 경고로 알리고 막지 않는다"
run_stdin_in "$BAD" "$(payload_bash 'k6 run load.js')"; expect_code 0
expect_out '"additionalContext"'; expect_out "GIN-01"; expect_not '"permissionDecision"'

tc TC-S101 "docker run grafana/k6 · wrk · hey · vegeta attack · 환경 변수 접두 · 파이프 뒤 명령도 부하 도구로 본다"
for c in 'docker run --rm -i grafana/k6 run - < s.js' 'wrk -t2 -c50 -d30s http://127.0.0.1:8080/' 'hey -z 10s http://x' \
  'echo GET http://x | vegeta attack -rate=100' 'K6_OUT=json k6 run s.js' 'cd perf && oha -z 10s http://x'; do
  run_stdin_in "$BAD" "$(payload_bash "$c")"; expect_out "GIN-01"
done

tc TC-S102 "부하 도구가 아닌 명령은 조용히 통과한다"
for c in 'go test -race ./...' 'go build ./...' 'git log --grep k6' 'echo "k6 run"' 'docker run golang:1.25 go version'; do
  run_stdin_in "$BAD" "$(payload_bash "$c")"; expect_code 0; expect_no_out
done

tc TC-S103 "위반 없는 프로젝트면 부하 명령이어도 조용하다"
p="$(proj)"; run_stdin_in "$p" "$(payload_bash 'k6 run load.js')"; expect_code 0; expect_no_out

tc TC-S104 "빈 입력 · PostToolUse · Bash 가 아닌 도구는 통과한다"
run_stdin_in "$BAD" ''; expect_code 0; expect_no_out
run_stdin_in "$BAD" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"k6 run a.js"}}'; expect_code 0; expect_no_out
run_stdin_in "$BAD" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"a","content":"k6 run"}}'; expect_code 0; expect_no_out

flush_tc
echo
echo "결과: PASS $PASS · FAIL $FAIL · SKIP $SKIP"
[ "$FAIL" = 0 ]
