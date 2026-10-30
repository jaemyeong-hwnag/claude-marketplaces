# common-performance-review

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Reviews the performance of code changes thoroughly — language-agnostic. Mandatory verdicts on 9 categories: time and space complexity, DB queries (N+1, indexes, pagination), network and IO, concurrency, caching, payload, resource release, and regex. Detects 19 patterns such as queries, awaits and unbounded fetches inside loops, notifies on write, and suggests how to measure.

This plugin **reads code** to find performance risks. A deterministic pattern check produces candidates, and the skill reads the call context and data scale to judge them. Load-testing a running system is the job of `common-stress-test` — items the review leaves as `측정필요` (needs measurement) are handed over there.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-performance-review@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| performance-review | review performance · will this get slow · N+1 · complexity · too many queries · memory | Pattern check → mandatory verdicts on 9 categories → findings with scale assumption, confidence and verification method |
| /performance-validate | Invoked directly | Finds `PF-01` ~ `PF-20` patterns in changed lines (default) or in the given paths |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| performance-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | **Notifies** patterns found in the lines just written (`PF-01` ~ `PF-20`). Does not block |

## Notes

- Patterns are **candidates**. Whether a collection is already a Set, whether the iteration count is constant, or whether it is already batched requires reading the context — the skill makes the call
- Loops are estimated line by line (braces, Python indentation). Calls made inside a loop through another function and lazy-loaded association access (`order.getCustomer()`) are invisible to patterns — the skill's category verdicts cover them
- Files checked: `.py` · `.java` · `.kt` · `.kts` · `.scala` · `.go` · `.js` · `.jsx` · `.mjs` · `.cjs` · `.ts` · `.tsx` · `.cs` · `.php` · `.swift` · `.rs` · `.sql`
- Test paths are skipped. Use `--include-tests` to check them
- For an intentional line, put a `performance-ignore` comment at the end of that line or on the line directly above
- Numbers (100 ms, 100 queries, etc.) are examples from the sources. The service sets its own thresholds
- Scripts use only bash, awk and jq

## Rule Summary

| Rule | Content | Verdict |
|---|---|---|
| `PF-01` ~ `PF-08` | In a loop: DB call · remote call · sequential await · regex compile · linear search · string accumulation · collection copy · heavy object creation | Warning |
| `PF-10` ~ `PF-14` | `SELECT *` · OFFSET pagination · unbounded fetch · leading `%` LIKE · `ORDER BY RAND()` | Warning |
| `PF-15` ~ `PF-20` | Blocking inside async · HTTP without timeout · ReDoS-prone regex · EAGER association · unbounded cache · full load for a count | Warning |
| `PF-30` ~ `PF-38` | All 9 categories — time · space · query · network · concurrency · caching · payload · resource release · regex — judged | AI judgment |
| `PF-40` ~ `PF-47` | Finding format · scale assumption required · severity separate from confidence · before/after comparison · context check · micro-optimizations are low · functional equivalence · cache invalidation | AI judgment |

Source: [`references/performance-rules.md`](references/performance-rules.md) · Evidence: [`references/performance-methods.md`](references/performance-methods.md)

## Usage

```bash
scripts/performance-validate.sh --diff                # lines changed vs the default branch
scripts/performance-validate.sh --diff HEAD~3         # set the base
scripts/performance-validate.sh src/                  # whole path
scripts/performance-validate.sh --strict src/         # exit 2 if there are warnings (CI)
test/performance-validate.test.sh                     # regression tests
```

## Evidence

ISO/IEC 25010:2023 · ISO/IEC 5055 (CWE-1309) · CWE-400 · CWE-1333 · OWASP API4:2023 · Jin et al. PLDI 2012 · Chen et al. ICSE 2014 · Yang et al. ICSE 2018 · Davis et al. FSE 2018 · Infer Cost · Dean & Barroso CACM 2013 · GitLab database and MR performance guides · Amazon Builders' Library · Azure performance antipatterns · SWE-Perf · SWR-Bench. Sources and verification level for each item are in `references/performance-methods.md`.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
