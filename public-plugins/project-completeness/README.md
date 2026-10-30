# project-completeness

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Measures and fills what a project needs to be a service — auto-detects the repository and diagnoses risk · practice coverage with a 69-item checklist, applies settings · CI from recipes then verifies · rolls back, and judges 18 DORA · SLO · on-call metrics from measured values. No pass by guessing.

Some services get an A grade from linters while developers open the DB to handle every customer inquiry. Code quality tools do not look at empty states · refund paths · backup restores · on-call · rollbacks. This plugin includes those questions and measures **does it exist** (checklist) and **does it work** (measured metrics) separately.

```
completeness-review      diagnosis (read-only)   → risk + practice coverage + emptiest axis
completeness-apply       settings · CI by recipe → verify → roll back on failure
service-health-review    measured values         → judgment per metric + unmeasured list
```

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install project-completeness@jaemyeong-hwnag-plugins --scope project
```

Requires: `bash`, `jq`, `find`, `grep`. When applying a recipe, that recipe's tools (Node · Python · Go toolchains, Docker, etc.).

## Dependencies

None

## Skills

| Skill | Triggers | Description |
|---|---|---|
| completeness-review | completeness check · quality diagnosis · what to adopt first | `detect` → choose measurement scope → judge by ⚡ auto · ▶️ run · 💬 ask → `score` |
| completeness-apply | apply it · hook it into CI · adopt a linter | One axis at a time: recipe → plan agreement → apply → verify → roll back on failure. Does not commit |
| service-health-review | service health · DORA · on-call · alert fatigue | Collects only known values and judges them with `health`. Reports unmeasured metrics separately |

## Notes

- **No pass by guessing.** Items that could not be confirmed count as not passed — a low score is normal
- `hints` from `detect` are not judgments. Even if the source contains `refund`, whether it is a working refund path is decided by reading the code or asking
- **Risk and practice coverage are different questions.** A library with the 12 critical items is not at risk even at 20% coverage
- Language recipes exist only for Node · Python · Go. Java · Kotlin are detected, but only the common · ops · service recipes apply
- Recipe versions · config formats go stale. If the installed version's format differs, the skill stops and tells you
- `completeness-apply` changes files but does not commit. Newly added checks do not fail CI (except secrets · Critical vulnerabilities)

## What it measures

| Axis | Items | Critical | Examples |
|---|---:|---:|---|
| `code` Code | 10 | 2 | Linter enforced in CI · new-code gate · CODEOWNERS · architecture boundaries |
| `test` Tests | 7 | 1 | Coverage · mutation · E2E for core flows · integration with a real DB |
| `security` Security | 8 | 3 | Secret scanning · SAST · SCA + SBOM · automatic dependency updates |
| `perf` Performance | 7 | 0 | Core Web Vitals · performance · bundle budgets · load tests |
| `ux` Accessibility · UX | 6 | 0 | Zero axe violations · manual screen reader · WCAG 2.2 |
| `ops` Operations | 7 | 3 | Traces · SLO · on-call · runbooks · rollback · postmortems |
| `service` Service completeness | 19 | 3 | Empty · error · loading states · refund path · admin tools · backup restore · render smoke · spec ↔ implementation |
| `product` Product · organization | 5 | 0 | Funnels · experiments · DORA collection · DevEx |

Items structurally irrelevant to a project type (`backend-api` · `library` · `cli` …) drop out as N/A.

## Files

| Path | Role |
|---|---|
| `references/completeness-rules.md` | Source of rules — judgment principles `Q-01` – `Q-07`, application principles `Q-11` – `Q-19`, gate stages, axis order, recipe format |
| `references/completeness-checklist.json` | Items · critical · measurement mode · N/A per project type · grade boundaries |
| `references/service-health-metrics.json` | Health metrics · thresholds |
| `references/recipe-*.md` | Adoption recipes — common · Node · Python · Go · ops · service |
| `scripts/project-completeness.sh` | `detect` · `scope` · `score` · `health` · `recipe` |
| `test/` | Regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — diagnosis skill trigger (`completeness-request`) |

## Usage

```bash
S=scripts/project-completeness.sh
$S detect .                                          # repository traces → JSON
$S scope --type backend-api                          # measurable items
$S score --type backend-api --pass code.lint-ci,security.secret-scan --na code.ai-provenance
$S health cfr=8 recovery=45 pages_week=12            # without arguments, lists metrics
$S recipe security.secret-scan                       # recipe that fills the item
test/project-completeness.test.sh                    # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
