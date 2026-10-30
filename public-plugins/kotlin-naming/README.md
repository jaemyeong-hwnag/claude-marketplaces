# kotlin-naming

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces Kotlin naming conventions on Kotlin code — lowercase packages, UpperCamelCase types, file name for single-class files, SCREAMING_SNAKE_CASE `const val`, lowerCamelCase functions and properties.

A hook blocks wrong shapes; the `kotlin-name-create` skill decides which words to use. Based on the Naming rules section of the official Kotlin Coding conventions; the Android Kotlin style guide is reference only.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install kotlin-naming@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| kotlin-name-create | Writing Kotlin code · naming data classes, extension functions, properties | Shape table and word choice (extension functions · Boolean · Flow · suspend · factories · test names) |
| /kotlin-naming-validate | Invoked directly | Validates every `*.kt` in the project and reports by rule |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-kotlin-naming.sh | PreToolUse (Write\|Edit) | **Blocks** a `*.kt` edit that **introduces** a violation; warning rules are reported as notices |

## Notes

- The hook compares the file before and after the edit and blocks **only added violations**. Editing other lines of a legacy file is not blocked by existing names. Find existing violations with `/kotlin-naming-validate`
- `*.kts` (`build.gradle.kts` etc.) is not checked
- For `val` · `var`, only snake_case starting with a lowercase letter is blocked. The machine cannot tell whether SCREAMING_SNAKE_CASE is a deeply immutable value or whether UpperCamelCase is a singleton reference
- Functions starting with an uppercase letter are allowed only for `@Composable` and factory functions whose return type matches the name. Function names under test paths may contain underscores
- Parameters, enum constants and lambda parameters are left to the skill
- `build/` · `target/` · `out/` · `.gradle/` · `generated/` · `node_modules/` are skipped
- Requires `jq`

## Rule summary

| Rule | Target | Rule | Verdict |
|---|---|---|---|
| `KN-01` | Package | Segments start lowercase (camelCase allowed), no underscores | Uppercase start blocked · underscore warned |
| `KN-02` | class · interface · object · enum / annotation / data / sealed / value class · fun interface · typealias | UpperCamelCase | Blocked |
| `KN-03` | File name | That name if the only top-level declaration is one class-like; otherwise UpperCamelCase | Blocked when single · otherwise warned |
| `KN-04` | `const val` | SCREAMING_SNAKE_CASE | Blocked |
| `KN-05` | `fun` | lowerCamelCase (exceptions: backticks · `@Composable` · factories · underscores in tests) | Blocked |
| `KN-06` | `val` · `var` | No snake_case starting lowercase (`_name` · SCREAMING · UpperCamel allowed) | Blocked |
| `KN-07` | Acronyms in type names | `HttpClient` (not `HTTPClient`; `IOStream` is fine) | Warning |

Source: [`references/kotlin-naming-rules.md`](references/kotlin-naming-rules.md)

## Usage

```bash
scripts/validate-kotlin-naming.sh src/main/kotlin   # directory
scripts/validate-kotlin-naming.sh --all .           # whole project
test/validate-kotlin-naming.test.sh                 # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
