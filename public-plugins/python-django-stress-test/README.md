# python-django-stress-test

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Prepares a Django server for load measurement, the Django way — detection of invalidating settings such as runserver · DEBUG=True · auto-reload · debug-toolbar · DEBUG logging, django-prometheus latency histograms with in-flight gauge · multiprocess instrumentation, Gunicorn worker · thread · `CONN_MAX_AGE` · DB pool knobs, pyperf microbenchmarks.

Load model · metrics · statistical verdicts · target host safety belong to `common-stress-test`. This plugin holds only what is specific to Django. Evidence: Django docs (django-admin runserver · Settings · Databases · Logging) · Gunicorn settings descriptions · prometheus client_python "Multiprocess Mode" · django-prometheus source and docs · pyperf docs, and each clause was confirmed by actually running it in Docker.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-django-stress-test@jaemyeong-hwnag-plugins
```

## Dependencies

- `common-stress-test` — writing load scripts · judging results · target host safety

## Skills

| Skill | Trigger | Description |
|---|---|---|
| django-stress-test-apply | Django load test · gunicorn performance · `/metrics` · worker count · `CONN_MAX_AGE` · pyperf | Remove invalidating settings, apply instrumentation, predict the saturation point from knobs, microbenchmarks |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| django-stress-config-validate.sh | PreToolUse (Bash) | When running a load tool (`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`, `docker run` · compose with those images, the gatling task of `mvn` · `gradle`), checks the project and **reports**. Does not block |

## Notes

- Reads line by line without parsing. When the value is a variable, as in `DEBUG = env("DEBUG", default=True)`, it is not read — the skill checks the default
- Settings whose file name contains the word `dev` · `local` · `test` (`settings/dev.py` · `docker-compose.dev.yml`), CI files (`.github/` · `.gitlab-ci.yml`), and `Makefile` are treated as development and skipped. If the measured target starts from such a file, do not rely on the CLI result alone
- django-prometheus has no in-flight gauge. Add the middleware from the recipe yourself
- Requires `jq` (hook mode)

## Rule summary

| Clause | Content | Verdict |
|---|---|---|
| `DJ-01` | Do not measure with `manage.py runserver` | Block |
| `DJ-02` | Do not measure with `DEBUG = True` | Block |
| `DJ-03` | Do not measure with Gunicorn · Uvicorn auto-reload | Block |
| `DJ-04` | Keep django-debug-toolbar out of the measured settings | Warning |
| `DJ-05` | Do not measure with log level DEBUG | Warning |
| `DJ-06` | Multiple workers + prometheus require `PROMETHEUS_MULTIPROC_DIR` | Block |
| `DJ-07` | `mark_process_dead` in Gunicorn `child_exit` | Warning |
| `DJ-08` | A latency histogram and an in-flight gauge exist | Warning |
| `DJ-09` | django-prometheus Before middleware first, After last | Warning |
| `DJ-10` | Histogram buckets cover the area near the SLO | AI judgment |
| `DJ-11` | Set the Gunicorn worker count before measuring (default 1) | Warning |
| `DJ-12` | Under ASGI, `CONN_MAX_AGE = 0` | Warning |
| `DJ-13` ~ `DJ-15` | `CONN_MAX_AGE` · DB connection count · concurrency limit of the worker model | AI judgment |
| `DJ-20` | Microbenchmarks with pyperf · pytest-benchmark repeated distributions | AI judgment |

Source: [`references/django-stress-rules.md`](references/django-stress-rules.md) · Instrumentation: [`references/django-instrumentation-recipe.md`](references/django-instrumentation-recipe.md) · Microbenchmark: [`references/django-microbenchmark.md`](references/django-microbenchmark.md)

## Usage

```bash
scripts/django-stress-config-validate.sh .               # check the project (0 pass · 2 violation)
test/django-stress-config-validate.test.sh               # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
