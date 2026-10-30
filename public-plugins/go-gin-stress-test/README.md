# go-gin-stress-test

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Handles the framework's share when load-testing a Go · Gin server — Prometheus latency histogram · in-flight · runtime instrumentation, detection of settings that invalidate a measurement (debug mode · `-race` build · exposed pprof · pinned GOMAXPROCS), GOMAXPROCS · GOMEMLIMIT · server timeout · DB pool knob checks, `go test -bench` · `benchstat` microbenchmarks.

Load model · verdict statistics · target host safety belong to `common-stress-test`. Evidence: Gin source (`mode.go` · `gin.go` · `render/html.go`) · Go 1.25 release notes · GODEBUG docs · `net/http` · `database/sql` · `net/http/pprof` docs · Go GC guide · race detector docs · Prometheus "Histograms and summaries" · client_golang source · benchstat docs.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install go-gin-stress-test@jaemyeong-hwnag-plugins
```

## Dependencies

- `common-stress-test` — writing load scripts (`stress-test-create`) · judging results (`stress-result-review`) · target host safety

## Skills

| Skill | Trigger | Description |
|---|---|---|
| gin-stress-test-apply | Gin load test · golang performance · GIN_MODE · pprof · GOMAXPROCS · benchstat | Remove invalidating settings → server-side instrumentation → record knobs → microbenchmarks |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| gin-stress-config-validate.sh | PreToolUse (Bash) | Only when running a load tool (`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`, `docker run` · compose with those images, the gatling task of `mvn` · `gradle`), checks the project and reports **warnings**. Does not block |

## Notes

- Reads line by line. With no parser, only lines starting with `//` are treated as comments; block comments · code-like text inside strings are read too
- Environment variables are read only from `Dockerfile*` · `Containerfile*` · `*.yml` · `*.yaml` · `.env*`. Helm templates · values assembled in code · runtime arguments are not read — check `/metrics` of the running process
- `_test.go` · `vendor/` · `testdata/` are skipped. `go test -race` is out of scope
- Files whose name contains the word `dev` · `local` · `test` (`.env.local` · `docker-compose.dev.yml`) and CI files (`.github/` · `.gitlab-ci.yml`) are skipped
- If the pprof address is a variable, loopback cannot be determined, so it is lowered to a warning
- Requires `jq` (hook mode)

## Rule summary

| Clause | Rule | Verdict |
|---|---|---|
| `GIN-01` | Do not start in debug mode | Block |
| `GIN-02` | Set release mode somewhere | Warning |
| `GIN-03` | Per-request access logs (`gin.Default` · `gin.Logger`) only when same as production | Warning |
| `GIN-04` | Do not open pprof on a public address | Block / Warning |
| `GIN-05` | Do not measure load with a `-race` build | Block / Warning |
| `GIN-06` | Do not pin `GOMAXPROCS` by hand | Warning |
| `GIN-07` | For container deployments, `go` in `go.mod` ≥ 1.25 | Warning |
| `GIN-08` | App servers use `http.Server` with timeouts | Warning |
| `GIN-09` | Set `SetMaxOpenConns` · `SetMaxIdleConns` | Warning |
| `GIN-10` | Latency as Histogram (not Summary `Objectives`) | Warning |
| `GIN-11` | No raw paths in metric labels → `c.FullPath()` | Warning |
| `GIN-12` | If GC is off, also set `GOMEMLIMIT` | Warning |
| `GIN-20` ~ `GIN-26` | Pool size · memory limit · profiles · Little · microbenchmarks · CPU per request | AI judgment |

Source: [`references/gin-stress-rules.md`](references/gin-stress-rules.md)

## Usage

```bash
scripts/gin-stress-config-validate.sh .          # check the project — exit 2 means a blocking clause was violated
test/gin-stress-config-validate.test.sh          # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
