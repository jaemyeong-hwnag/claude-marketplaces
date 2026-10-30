# java-spring-aitest-coverage

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Makes **code changed by AI get covered by `@AiTest`** in Java · Spring Boot (Gradle) projects — case-matrix tests for changed methods, a testcontainer test environment, and a JaCoCo 100% gate on changed methods when work completes.

Stops AI from changing code and calling it "done" with no tests, or with a single success case. The basis for judgment is the local git diff.

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install java-spring-aitest-coverage@jaemyeong-hwnag-plugins --scope project
```

After installing, if there is no `@AiTest` environment, call `aitest-environment-create` with "Create the AiTest environment". Until the environment exists, the gate is off.

Requires: `git`, JDK, Docker (testcontainers), Gradle Wrapper (`./gradlew`). `jq` too if you use the config file (`.claude/java-spring-aitest-coverage.json`).

## Dependencies

None

## Skills

| Skill | Triggers | Description |
|---|---|---|
| aitest-generate | write tests, integration test, raise coverage, completion on hold | For each changed method, writes `@AiTest` · `@AiWebTest` · unit tests from a success · failure · boundary · data state · backward compatibility · side effect · concurrency matrix → runs them → changed methods at 100% |
| aitest-environment-create | AiTest environment, test infrastructure, testcontainers setup | Reads the project, creates the test-support module · `gradle/ai-test.gradle` · Docker setup script · smoke test, and runs the smoke test (after user confirmation) |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| aitest-coverage-validate.sh | UserPromptSubmit | Records a fingerprint of the `src/main` · `src/test` diff at request start |
| aitest-coverage-validate.sh | Stop | If the diff changed in this request, checks `@AiTest` for changed Controllers (`C-01`) · JaCoCo 100% on modified methods (`C-02`) · report freshness (`C-03`) · an `*AiTest*` diff for main changes with no known consumer module (`C-04`), and **blocks completion** if unmet (exit 2) |

## Notes

- The gate runs only in repositories that have `gradle/ai-test.gradle` or `@interface AiTest`. Otherwise it only notifies once per session
- The Stop hook does not run Gradle; it judges from the **existing report**. After changing code, refresh the report with `scripts/diff-coverage-validate.sh <base>` to pass — `aitest-generate` does this. `<base>` is the ref given in the block message (if you committed within the request, `HEAD` gives an empty diff and lets it pass)
- If completion is attempted again after one block, it is allowed with only a warning (prevents infinite loops). For comment- or format-only changes, use the `aitest: skip <reason>` exemption — the gate message gives the ACK file path
- Supported: Gradle **Groovy DSL** · Spring Boot 2.x – 4.x · Testcontainers 1.x / 2.x · MySQL · PostgreSQL · Redis · RabbitMQ. Kotlin DSL · Maven · Kotlin sources (`src/main/kotlin`) are not checked
- Combinations tested for real (manual checks in `test/README.md`)

  | Boot | Gradle | JDK | Testcontainers | Layout | Infrastructure | Verified |
  |---|---|---|---|---|---|---|
  | 2.5.6 | 7.2 | 11 | 1.19.7 | Single module | MySQL | Smoke → 80% FAIL → hook block |
  | 3.3.1 | 8.8 | 17 | 1.20.4 | Multi-module + library | MySQL | Smoke → `C-01` block → below 100% FAIL → 100% PASS · hook pass → `C-03` block |
  | 3.5.6 | 9.3.0 | 17 | 1.20.4 | Nested module (`apps:api`) + library · local profile | PostgreSQL · Redis · RabbitMQ | Same as 3.3.1 + Redis write · RabbitMQ channel · local profile hosts overridden by containers |
  | 4.0.2 | 9.3.0 | 17 | 2.0.3 | Single module | MySQL · PostgreSQL | Smoke → 80% FAIL → added tests → 100% PASS · hook pass |

## Gate rules

| Rule | Content |
|---|---|
| `C-01` | For each changed Controller, an `*AiTest*` covering that class (file name starts with the class name, or the class name appears as a word in the body) |
| `C-02` | JaCoCo INSTRUCTION 100% for the method containing each changed line |
| `C-03` | The report is newer than the local diff |
| `C-04` | Main changes with no known consumer module need an `*AiTest*` diff |
| `C-05` – `C-08` | Only when the diff changed in this request · off without the environment · exemption · infinite loop prevention |

Full rules: [`references/coverage-rules.md`](references/coverage-rules.md).

## Project configuration

`.claude/java-spring-aitest-coverage.json` — optional.

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"] },
  "javaVersion": "11"
}
```

- Without `modules`, uses `aiTestModules` in the root `build.gradle`; without that, the root single module
- `libraryModules` — when a library module such as core · common changes, it is measured by the consumer module's `aiTest` and judged from the consumer module's report

## Files

| Path | Role |
|---|---|
| `references/coverage-rules.md` | Source of rules — conventions · rules · target modules · configuration · rationale |
| `scripts/aitest-coverage-validate.sh` | Hook — fingerprint (`snapshot`) · Stop gate |
| `scripts/diff-coverage-validate.sh` | Runs `aiTest` on the local diff + judges (`--check-only` · `--report-only`) |
| `scripts/method-coverage-get.sh` | JaCoCo % per changed method |
| `skills/aitest-environment-create/templates/` | Skeletons for the test-support module · Gradle · Docker script |
| `skills/aitest-generate/examples.md` | Test code shapes · seed pitfalls |
| `test/` | Script regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — skill trigger · gate block |

## Usage

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" <base>               # aiTest + JaCoCo + judgment (<base> = ref from the block message)
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" --check-only <base>  # Controller @AiTest presence only
test/diff-coverage-validate.test.sh                                           # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
