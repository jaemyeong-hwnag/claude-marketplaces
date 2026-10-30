# kotlin-spring-aitest-coverage

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Makes **code changed by AI get covered by `@AiTest`** in Kotlin · Spring Boot (Gradle Kotlin DSL) projects — case-matrix tests for changed methods, a testcontainer test environment, and a JaCoCo 100% gate on changed methods when work completes.

Stops AI from changing code and calling it "done" with no tests, or with a single success case. The basis for judgment is the local git diff.

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install kotlin-spring-aitest-coverage@jaemyeong-hwnag-plugins --scope project
```

After installing, if there is no `@AiTest` environment, call `kotlin-aitest-environment-create` with "Create the Kotlin AiTest environment". Until the environment exists, the gate is off.

Requires: `git`, JDK (including `javap`), Docker (testcontainers), Gradle Wrapper (`./gradlew`). `jq` too if you use the config file (`.claude/kotlin-spring-aitest-coverage.json`).

## Dependencies

None

## Skills

| Skill | Triggers | Description |
|---|---|---|
| kotlin-aitest-generate | write tests, integration test, raise coverage, completion on hold | For each changed method, writes `@AiTest` · `@AiWebTest` in Kotlin (constructor injection · MockK · `runTest` · backtick names) from a success · failure · boundary · data state · backward compatibility · side effect · concurrency matrix → runs them → changed methods at 100% |
| kotlin-aitest-environment-create | Kotlin AiTest environment, test infrastructure, testcontainers setup | Reads the project, creates the `aiTest` block in target modules' `build.gradle.kts` · Kotlin support module · Docker setup script · smoke test, and runs the smoke test (after user confirmation) |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| aitest-coverage-validate.sh | UserPromptSubmit | Records a fingerprint of the `src/main` · `src/aiTest` diff at request start |
| aitest-coverage-validate.sh | Stop | If the diff changed in this request, checks aiTest for changed Controllers (`C-01`) · JaCoCo 100% on changed methods (`C-02`) · report freshness (`C-03`) · an aiTest diff for main changes with no known consumer module (`C-04`) · judgment tools (`C-09`), and **blocks completion** if unmet (exit 2) |

## Notes

- The gate runs only in repositories whose `build.gradle.kts` has a `// >>> kotlin-spring-aitest-coverage` block. Otherwise it only notifies once per session. It does nothing in Gradle Groovy DSL repositories
- The Stop hook does not run Gradle; it judges from the **existing report and class files**. After changing code, refresh the report with `scripts/diff-coverage-validate.sh <base>` to pass — `kotlin-aitest-generate` does this. `<base>` is the ref given in the block message (if you committed within the request, `HEAD` gives an empty diff and lets it pass)
- Which method a changed line belongs to is decided from the class file's line table (`javap`). If `javap` or the class files are missing, it blocks as undecidable
- If completion is attempted again after one block, it is allowed with only a warning (prevents infinite loops). For comment- or format-only changes, use the `aitest: skip <reason>` exemption — the gate message gives the ACK file path (`<Gradle root>/.claude/kotlin-spring-aitest-coverage/`)
- Checks only `.kt`. `.java` is checked by `java-spring-aitest-coverage` — the two editions can be installed together without overlapping state · config · skill names. One module cannot hold the `aiTest` environments of both editions
- Supported: Kotlin 2.x · Spring Boot 3.1 – 4.x · Gradle 8 · 9 (Kotlin DSL) · JDK 17+ · MockMvc · MySQL · PostgreSQL · Redis · RabbitMQ. WebFlux (`WebTestClient`) · Groovy DSL · Maven · Boot 2 are not checked
- Combinations tested for real (manual checks in `test/README.md`)

  | Boot | Gradle | Kotlin | JDK | Testcontainers | Layout | Infrastructure | Verified |
  |---|---|---|---|---|---|---|---|
  | 3.5.16 | 8.14.4 | 2.2.21 | 17 | 1.21 (Boot BOM) | Multi-module + library | PostgreSQL | Environment creation → smoke → block → 75% FAIL → 100% PASS · hook pass · library `C-04` · `C-03` · `C-02` |
  | 4.1.1 | 9.8.0 | 2.4.21 | 17 | 2.0.5 (Boot BOM) | Single module · package ≠ directory | MySQL · Redis | Environment creation → smoke → block (Controller named differently from its file) → 50% FAIL → 100% PASS (including `suspend`) · hook pass · `C-03` · aiTest-only change |

## Gate rules

| Rule | Content |
|---|---|
| `C-01` | For each changed Controller (`@RestController` · `@Controller`), its class name in a `src/aiTest/kotlin` body |
| `C-02` | JaCoCo INSTRUCTION 100% for the method containing each changed line — excluding `@JvmStatic` bridges · `$default` on the same line · accessors on the primary constructor line |
| `C-03` | The report is newer than the local diff |
| `C-04` | Main changes with no known consumer module need an aiTest diff |
| `C-05` – `C-08` | Only when the diff changed in this request · off without the environment · exemption · infinite loop prevention |
| `C-09` | Blocks as undecidable when judgment tools (`javap` · class files) are missing |

Full rules: [`references/coverage-rules.md`](references/coverage-rules.md).

## Project configuration

`.claude/kotlin-spring-aitest-coverage.json` — optional.

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"] },
  "jdkVersion": "17"
}
```

- Without `modules`, uses the modules whose `build.gradle.kts` has the environment block; without that, the root single module
- `libraryModules` — when a library module such as core · common changes, it is measured by the consumer module's `aiTest` and judged from the consumer module's report

## Files

| Path | Role |
|---|---|
| `references/coverage-rules.md` | Source of rules — conventions · rules · changed line → method · target modules · configuration · rationale |
| `scripts/aitest-coverage-validate.sh` | Hook — fingerprint (`snapshot`) · Stop gate |
| `scripts/diff-coverage-validate.sh` | Runs `aiTest` on the local diff + judges (`--check-only` · `--report-only`) |
| `scripts/method-coverage-get.sh` | JaCoCo % per changed method (`javap` line table) |
| `skills/kotlin-aitest-environment-create/templates/` | Skeletons for the Gradle block · support module · Docker script |
| `skills/kotlin-aitest-generate/examples.md` | Test code shapes · seed pitfalls |
| `test/` | Script regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — skill trigger · gate block |

## Usage

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" <base>               # aiTest + JaCoCo + judgment (<base> = ref from the block message)
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" --check-only <base>  # Controller aiTest presence only
test/diff-coverage-validate.test.sh                                           # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
