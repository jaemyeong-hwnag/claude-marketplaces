# python-fastapi-stress-test

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Prepares a FastAPI server for load measurement — latency histogram · in-flight gauge instrumentation (prometheus multiprocess mode with multiple workers), detection of invalidating settings such as the dev server · reload · debug, worker · thread token · DB pool knobs, pyperf microbenchmarks.

Load model · metrics · statistical verdicts belong to `common-stress-test`; this plugin holds only what is specific to FastAPI · Uvicorn · Gunicorn · prometheus_client. Evidence: FastAPI · Starlette · Uvicorn · AnyIO · prometheus client_python · SQLAlchemy · pyperf official docs and source, and Docker measurements.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-fastapi-stress-test@jaemyeong-hwnag-plugins
```

## Dependencies

- `common-stress-test` — writing load scripts · judging results · target host safety

## Skills

| Skill | Trigger | Description |
|---|---|---|
| fastapi-stress-test-apply | FastAPI load test · uvicorn performance · `/metrics` · worker count · pyperf | Remove invalidating settings, apply instrumentation, predict the saturation point from knobs, microbenchmarks |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| fastapi-stress-config-validate.sh | PreToolUse (Bash) | When running a load tool (`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`, `docker run` · compose with those images, the gatling task of `mvn` · `gradle`), checks the project and **reports**. Does not block |

## Notes

- The hook reports only in FastAPI projects (`fastapi` appears in a dependency file or `*.py`)
- The script reads only line-level literals. Values set through variables, such as `debug=settings.debug` · `--workers "$N"`, are not read — the skill judges them
- `#` comment lines, test files (`test_*.py` · `*_test.py` · `conftest.py`), and `.venv/` · `venv/` · `site-packages/` · `node_modules/` · `build/` · `dist/` are skipped
- `FAS-01` skips files whose name contains the word `dev` · `local` · `test`, Makefile targets with those names, and CI files (`.github/` · `.gitlab-ci.yml`). Other development setups (`docker-compose.override.yml`, etc.) are reported too. A person decides which setup is measured
- Requires `jq`

## Rule summary

| Clause | Content | Verdict |
|---|---|---|
| `FAS-01` | Do not measure with `fastapi dev` · `--reload` | Block |
| `FAS-02` | Workers ≥ 2 + prometheus requires `PROMETHEUS_MULTIPROC_DIR` | Block |
| `FAS-03` | Gunicorn + multiprocess calls `mark_process_dead` in `child_exit` | Warning |
| `FAS-04` | Do not measure with `debug=True` | Warning |
| `FAS-05` | Do not measure with log level `debug` · `trace` | Warning |
| `FAS-06` | `uvicorn.workers.UvicornWorker` → `uvicorn_worker.UvicornWorker` | Warning |
| `FAS-07` | No blocking calls inside `async def` | Warning |
| `FAS-08` | Server-side instrumentation and an in-flight gauge exist | Warning |
| `FAS-09` | Measure latency with `Histogram` (not `Summary`) | Warning |
| `FAS-10` ~ `FAS-13` | Buckets · thread tokens 40 · DB pool · worker count | AI judgment |
| `FAS-20` | Microbenchmarks are judged with pyperf `compare_to` · repeated distributions | AI judgment |

"Block" means CLI exit code `2`. The hook does not block load commands.

Source: [`references/fastapi-stress-rules.md`](references/fastapi-stress-rules.md)

## Usage

```bash
scripts/fastapi-stress-config-validate.sh .         # check the project
test/fastapi-stress-config-validate.test.sh         # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
