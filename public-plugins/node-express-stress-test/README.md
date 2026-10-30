# node-express-stress-test

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Prepares load measurement of a Node.js · Express app — prom-client latency histogram · in-flight gauge instrumentation, detection of settings that invalidate a measurement (`NODE_ENV` · nodemon · `--watch` · profilers · `DEBUG` · view cache), cluster worker · `UV_THREADPOOL_SIZE` · keep-alive knobs, tinybench · mitata microbenchmarks. A hook warns before a load tool runs.

Load model · metric definitions · statistical verdicts belong to `common-stress-test`; this plugin holds only what is specific to Express · Node.js. Evidence: Express docs (Production best practices: performance · Debugging) · Express 4.x/5.x source · Node.js API docs (cli · http · cluster · perf_hooks · process · dns) · libuv docs · prom-client source and README, measured on Express 5.2.1 · Node.js 22.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install node-express-stress-test@jaemyeong-hwnag-plugins
```

## Dependencies

| Plugin | Used for |
|---|---|
| common-stress-test | Writing load scenarios (`stress-test-create`) · judging results (`stress-result-review`) |

## Skills

| Skill | Trigger | Description |
|---|---|---|
| express-stress-test-apply | express load · node performance measurement · prom-client · event loop lag | Remove invalidating settings → instrumentation → record capacity knobs → microbenchmarks; scenarios · verdicts go to common-stress-test |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| express-stress-config-validate.sh | PreToolUse (Bash) | Only when the command is a load tool (`k6 run` · `k6 cloud` · `wrk` · `wrk2` · `autocannon` · `locust` · `jmeter` · `gatling` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery`, `docker run` · compose with those images, the gatling task of `mvn` · `gradle`), checks the project and **warns**. Does not block |

## Notes

- Directories without `express` in `package.json` are skipped. The hook looks at the nearest express app upward from the directory the command runs in (including `cd`)
- Only production startup settings are read — `start` · `start:prod` · `prod` · `serve` in `package.json`, `Dockerfile`, `compose*.yml`, `Procfile`, PM2 `ecosystem.config.*`. Files whose name contains the word `dev` · `local` · `test` (`loadtest` · `perftest` are read) and `.env` are skipped
- Environment variables injected by Kubernetes manifests · systemd units are not visible. That is why a missing `NODE_ENV=production` (`NEX-02`) is a warning
- It is line-based grep. Commands spanning several lines · commands assembled from variables are missed
- In Express core, `NODE_ENV` changes only the view cache and error responses. For a JSON API the measured difference was within noise; pug rendering was 3-4x faster in production (median of sequential requests)
- The queue of a synchronous handler does not show up in the server in-flight gauge (`NEX-11`) — for the Little check, look at it together with the load generator's L
- Requires `jq`

## Rule summary

| Clause | Target | Verdict |
|---|---|---|
| `NEX-01` | `NODE_ENV` of production startup is not production | Violation |
| `NEX-02` | `NODE_ENV=production` found nowhere | Warning |
| `NEX-03` | nodemon · `--watch` · `tsx watch` · `ts-node-dev` · PM2 `watch: true` | Violation |
| `NEX-04` | `--prof` · `--cpu-prof` · `--heap-prof` · `--trace-sync-io` · `--trace-gc` · 0x · clinic | Violation |
| `NEX-05` | `--inspect` | Warning |
| `NEX-06` | `DEBUG=express:*` · `router` · `*` | Violation |
| `NEX-07` | Turning off `view cache` | Violation |
| `NEX-08` | prom-client Summary | Warning |
| `NEX-09` | `*Sync(` in route files | Warning |
| `NEX-10` ~ `NEX-13` | Histogram · in-flight · event loop · cluster aggregation | AI judgment |
| `NEX-20` ~ `NEX-24` | Worker count · thread pool · keep-alive · Agent · loop blocking | AI judgment |

Source: [`references/express-stress-rules.md`](references/express-stress-rules.md)

## Usage

```bash
scripts/express-stress-config-validate.sh .          # check the project (0 pass · 2 violation · 1 error)
test/express-stress-config-validate.test.sh          # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
