# common-stress-test

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Designs and judges load and stress tests quantitatively — language-agnostic. Blocks load against production hosts, checks open model · thresholds · p99, computes sustainable capacity · knee · USL · Little consistency from step results, judges regressions with Mann-Whitney U · Cliff's delta, and provides local · Docker · k8s environment templates.

This plugin owns the measurement method that is not tied to a language or framework. Server-side instrumentation (latency histograms · in-flight) and settings that invalidate a measurement belong to the `{language}-{framework}-stress-test` plugins. Those plugins depend on this one.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-stress-test@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| stress-test-create | Writing a load · stress test, k6 · locust · gatling · jmeter, "how many rps can it handle" | Test type selection · open model · step plan · thresholds |
| stress-result-review | Result analysis · bottleneck · p99 · performance regression | Sustainable capacity · knee · USL · Little, cause resource, regression verdict between two versions |
| stress-environment-create | Load test environment · docker compose · k8s | Separate load generator and target · pin resources · disable autoscaling · record the environment |
| /stress-script-validate | Invoked directly | Checks the project's load scripts against `ST-02` ~ `ST-06` |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| stress-target-validate.sh | PreToolUse (Bash) | **Blocks** when a load tool targets a host outside the allowlist (`ST-01`) |
| stress-script-validate.sh | PostToolUse (Write\|Edit) | **Reports** the measurement design of saved k6 · Gatling · Locust · JMeter scripts (`ST-02` ~ `ST-06`) |

## Notes

- The allowlist is:
  - Loopback, private IPv4
  - Names without a dot (container · service names)
  - `*.localhost` · `*.local` · `*.test` · `*.internal` · `host.docker.internal`
- Put dedicated test domains in `env.STRESS_TEST_ALLOWED_HOSTS` of `.claude/settings.json` (comma- or space-separated, `*.perf.example.com` form allowed)
- The target host is looked up in:
  - URLs in the load command
  - `--host` · locust's `-H`
  - Assignments to variables whose name contains `URL` · `HOST`
  - URLs in the script file the command points to
- If the script reads its target from elsewhere at runtime (a config server, etc.), the hook cannot see it
- If the system really is a closed model, put a `stress-test: closed-model` comment in the script. This turns off the `ST-02` warning
- Analysis scripts use only bash · awk · jq. Load tools (k6, etc.) are installed by the project or run as Docker images
- SLO values (p99 limit · error rate) are set by the service. The `300 ms` · `1%` in the docs are examples

## Rule summary

| Clause | Content | Verdict |
|---|---|---|
| `ST-01` | Load target is in the allowlist | Block |
| `ST-02` | Latency verdicts use an open model (mark it if closed) | Warning |
| `ST-03` | thresholds · assertions exist | Warning |
| `ST-04` | p99 is reported | Warning |
| `ST-05` · `ST-06` | `maxVUs` on k6 arrival-rate, no `sleep` | Warning |
| `ST-10` | Step pass = p99 · error rate · throughput · dropped | Verdict |
| `ST-11` | knee · USL need 6 or more steps | Warning |
| `ST-12` | Dropped steps under-measure latency | Warning |
| `ST-13` | Little's Law consistency | Warning |
| `ST-20` | Regression = Mann-Whitney U p < 0.05 · \|Cliff's delta\| ≥ 0.147 · worse direction | Block (exit 2) |
| `ST-30` ~ `ST-35` | Steady-state window · merging quantiles · separating failure latency · environment record · separate load generator · autoscaling off | AI judgment |

Source: [`references/stress-test-rules.md`](references/stress-test-rules.md) · Evidence: [`references/stress-test-methods.md`](references/stress-test-methods.md) · Templates: [`references/stress-test-templates.md`](references/stress-test-templates.md)

## Usage

```bash
scripts/stress-step-generate.sh --header > steps.csv
scripts/stress-step-generate.sh --load 200 summary.json >> steps.csv         # k6 · Locust · JMeter · Gatling
scripts/stress-report-generate.sh --model open --slo-p99 300 steps.csv       # capacity · knee · USL · Little
scripts/stress-regression-validate.sh baseline.txt candidate.txt              # regression (exit 2)
test/common-stress-test.test.sh                                               # regression tests
```

## Evidence

ISTQB Glossary v3.2 · ISO/IEC 25010:2023 · Little (1961 · 2011) · Gunther USL · Satopää et al. 2011 (Kneedle) · Schroeder et al. NSDI 2006 · Tene 2013 (coordinated omission) · Dean & Barroso CACM 2013 · Georges et al. OOPSLA 2007 · Kalibera & Jones ISMM 2013 · Arcuri & Briand ICSE 2011 · Laaber et al. EMSE 2019 · Daly et al. ICPE 2020 · Papadopoulos et al. TSE 2019 · k6 · Prometheus official docs. The source and verification level of each number are in `references/stress-test-methods.md`.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
