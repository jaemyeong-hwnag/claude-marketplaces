# Go 레시피

선행 조건 공통: 저장소에 `go.mod` 가 존재할 것.

---

## golangci-lint — 린터 애그리게이터

- **메우는 항목**: `code.lint-ci` 린터 CI 강제
- **설치**: `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest`
  **v2 부터 모듈 경로에 `/v2` 가 들어간다.** 구 경로로 설치하면 v1.x 가 깔려 아래 설정과 어긋난다.
  v2 는 Go 1.26+ 를 요구한다.
- **설정** — `.golangci.yml`. **v2 형식이어야 한다.**
  `version` 키가 없으면 v2 는 `unsupported version of the configuration` 으로 즉시 거부한다.
  v1 의 `issues.exclude-rules` 는 v2 에서 `linters.exclusions.rules` 로 옮겨졌다.
  ```yaml
  version: "2"

  run:
    timeout: 5m

  linters:
    enable:
      - errcheck      # 처리 안 된 에러
      - govet
      - staticcheck   # v2 에서 gosimple·stylecheck 가 여기로 통합됐다
      - ineffassign
      - unused        # 미사용 코드 — code.unused-code
      - gosec         # 보안 — security.sast
      - revive
    exclusions:
      rules:
        - path: _test\.go
          linters: [gosec, errcheck]
  ```
  기존 v1 설정이 있으면 `golangci-lint migrate` 로 변환한다.
- **검증**: `golangci-lint run`
- **CI**:
  ```yaml
  - uses: golangci/golangci-lint-action@v6
    with: { version: latest }
  ```
- **롤백**: `.golangci.yml` 삭제
- **비고**: `unused` + `gosec` 을 켜면 Knip·Bandit 에 해당하는 항목을 한 도구로 커버한다.

---

## go test 커버리지

- **메우는 항목**: `test.unit-coverage` 커버리지
- **설정**: 별도 파일 불필요
- **검증**: `go test ./... -coverprofile=coverage.out -covermode=atomic` → `go tool cover -func=coverage.out | tail -1`
- ⚠️ `-race` 는 **cgo 를 요구한다.** alpine 기반 이미지에서는 `-race requires cgo` 로 실패하므로
  `CGO_ENABLED=1` 과 컴파일러를 함께 설치하거나, `golang:<ver>` (debian) 이미지를 쓴다.
  GitHub Actions 의 `setup-go` + ubuntu 러너는 기본으로 동작한다.
- **CI**:
  ```yaml
  - run: go test ./... -race -coverprofile=coverage.out -covermode=atomic
  - uses: codecov/codecov-action@v4
    with: { files: ./coverage.out }
  ```
- **롤백**: CI step 삭제
- **gitignore 추가**: `coverage.out`
- **비고**: `-race` 를 함께 켜면 데이터 레이스까지 잡힌다. CI 시간이 2~3배가 되므로 PR 에서만 켠다.

---

## govulncheck — 취약점 (Go 공식)

- **메우는 항목**: `security.sca-sbom` SCA, `security.critical-vulnerability` Critical 0
- **설치**: `go install golang.org/x/vuln/cmd/govulncheck@latest`
- **검증**: `govulncheck ./...`
- **CI**:
  ```yaml
  - uses: golang/govulncheck-action@v1
    with: { go-version-input: '1.23' }
  ```
- **롤백**: step 삭제
- **비고**: **호출 그래프 기반**이라 실제로 도달 가능한 취약점만 보고한다.
  Trivy 보다 노이즈가 훨씬 적으므로 Go 프로젝트는 govulncheck 을 우선한다.

---

## Testcontainers — 실제 DB 통합 테스트

- **메우는 항목**: `test.integration-real-db` 실제 DB 통합 테스트
- **설치**: `go get github.com/testcontainers/testcontainers-go`
- **설정** — 테스트 헬퍼 예시:
  ```go
  func setupPostgres(t *testing.T) string {
      ctx := context.Background()
      c, err := postgres.Run(ctx, "postgres:16-alpine",
          postgres.WithDatabase("test"),
          postgres.WithUsername("test"),
          postgres.WithPassword("test"),
          testcontainers.WithWaitStrategy(
              wait.ForLog("database system is ready to accept connections").
                  WithOccurrence(2).WithStartupTimeout(30*time.Second)),
      )
      if err != nil { t.Fatal(err) }
      t.Cleanup(func() { _ = c.Terminate(ctx) })
      dsn, _ := c.ConnectionString(ctx, "sslmode=disable")
      return dsn
  }
  ```
- **검증**: `go test ./... -run Integration`
- **CI**: GitHub Actions ubuntu 러너는 Docker 가 기본 제공되어 추가 설정이 필요 없다.
- **롤백**: 의존성과 헬퍼 삭제
- **비고**: 컨테이너 기동 때문에 느리다. `-short` 플래그로 유닛 테스트와 분리한다.

---

## pprof — 프로파일링 기준선

- **메우는 항목**: `perf.latency-baseline` 성능 기준선
- **선행 조건**: `func BenchmarkXxx(b *testing.B)` 벤치마크가 하나 이상 존재
- **설정** — 벤치마크 작성 후:
  ```bash
  go test -bench=. -benchmem -cpuprofile=cpu.out -memprofile=mem.out ./...
  go tool pprof -top cpu.out
  ```
- **검증**: `go test -bench=. -benchmem ./...` → ns/op 과 allocs/op 이 출력되면 성공.
  이 값을 기준선으로 기록한다.
- **CI**: `benchstat` 으로 회귀 비교 (`golang.org/x/perf/cmd/benchstat`)
  ```yaml
  - run: go test -bench=. -benchmem -count=5 ./... | tee new.txt
  ```
- **롤백**: 벤치마크 파일 삭제
- **gitignore 추가**: `*.out`, `*.test`
