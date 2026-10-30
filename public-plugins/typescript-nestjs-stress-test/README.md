# typescript-nestjs-stress-test

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Prepares a NestJS server for load measurement — prom-client latency histogram · in-flight gauge instrumentation, detection of invalidating settings such as `nest start` · ts-node · debug logging, checks of Express/Fastify adapter · request scope · DB pool knobs, tinybench microbenchmarks.

Load model · verdict statistics · target host safety belong to `common-stress-test`; this plugin looks only at the NestJS server side. Evidence: Nest docs (CLI · Logger · Injection scopes · Request lifecycle · Performance), Fastify · Prometheus · prom-client docs, and Docker measurements.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install typescript-nestjs-stress-test@jaemyeong-hwnag-plugins
```

## Dependencies

- `common-stress-test` — writing load scripts (`stress-test-create`) · judging results (`stress-result-review`) · regression statistics

## Skills

| Skill | Trigger | Description |
|---|---|---|
| nestjs-stress-test-apply | NestJS performance measurement · load test preparation · nestjs-prometheus · Scope.REQUEST · Fastify adapter | Remove invalidating settings, histogram · in-flight instrumentation, knob checks, microbenchmarks |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| nestjs-stress-config-validate.sh | PreToolUse (Bash) | When the command is a load tool (k6 · locust · wrk · autocannon · `docker run grafana/k6` …), checks the project and **reports**. Does not block |

## Notes

- The hook only warns. Blocking load target hosts is done by the `common-stress-test` hook
- The production startup command is looked up in Dockerfile · compose · Procfile; if there is none, `start:prod` in `package.json` (or `start` if absent) is read. `npm run x` is expanded one level
- Dockerfile · compose whose name contains the word `dev` · `local` · `test` are skipped (`loadtest` · `perftest` are read)
- Reads line by line without a parser. If the `logger` option is passed as a variable, its value is not followed
- If `@nestjs/core` is not in `package.json`, nothing is checked. For a monorepo, pass the app directory to the CLI as an argument. The hook looks at the nearest app upward from the directory the command runs in (including `cd`)
- Requires `jq`

## Rule summary

| Clause | Content | Verdict |
|---|---|---|
| `NST-01` | Do not start with `nest start` (`--watch` · `--debug`) → `node dist/main` | Block |
| `NST-02` | Do not run `.ts` directly with ts-node · tsx | Warning |
| `NST-03` | Do not enable debug · verbose in the Nest log levels (without a logger option, all 6 default levels are on) | Warning |
| `NST-04` | Do not measure with `FastifyAdapter({ logger: true })` | Warning |
| `NST-05` | `'0.0.0.0'` in `listen` of the Fastify adapter | Warning |
| `NST-06` | Latency as Histogram — no Summary | Warning |
| `NST-07` · `NST-08` | A latency histogram · in-flight gauge exist | Warning |
| `NST-09` | Use `Scope.REQUEST` only after measuring its cost | Warning |
| `NST-10` ~ `NST-13` | Instrumentation point · adapter · process count · DB pool | AI judgment |
| `NST-20` | Microbenchmarks with tinybench · mitata + repeated distributions | AI judgment |

Source: [`references/nestjs-stress-rules.md`](references/nestjs-stress-rules.md) · Recipes: [`references/nestjs-stress-recipes.md`](references/nestjs-stress-recipes.md)

## Usage

```bash
scripts/nestjs-stress-config-validate.sh .            # check the project (0 pass · 2 violation · 1 error)
test/nestjs-stress-config-validate.test.sh            # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
