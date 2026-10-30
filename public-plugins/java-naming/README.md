# java-naming

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces Java naming conventions on Java code — lowercase packages, UpperCamelCase types, public type matches file name, UPPER_SNAKE_CASE constants, lowerCamelCase methods and fields.

A hook blocks wrong shapes; the `java-name-create` skill decides which words to use. Based on Google Java Style Guide chapter 5 and Oracle Code Conventions chapter 9.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install java-naming@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| java-name-create | Writing Java code · naming classes, methods, variables | Shape table and word choice (abbreviations · role suffixes · boolean · collections) |
| /java-naming-validate | Invoked directly | Validates every `*.java` in the project and reports by rule |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-java-naming.sh | PreToolUse (Write\|Edit) | **Blocks** a `*.java` edit that **introduces** a violation; warning rules are reported as notices |

## Notes

- The hook compares the file before and after the edit and blocks **only added violations**. Editing other lines of a legacy file is not blocked by existing names. Find existing violations with `/java-naming-validate`
- Only member declarations starting with an access modifier (`public` · `protected` · `private`) are checked. Local variables, parameters and enum constants are left to the skill
- Only primitive and `String` `static final` fields are treated as constants. The machine cannot tell whether a `Logger` or collection is a constant
- `build/` · `target/` · `out/` · `.gradle/` · `generated/` · `node_modules/` · `vendor/` are skipped
- Requires `jq`

## Rule summary

| Rule | Target | Rule | Verdict |
|---|---|---|---|
| `JN-01` | Package | Lowercase, no underscores | Uppercase blocked · underscore warned |
| `JN-02` | Class · interface · enum · record · annotation | UpperCamelCase | Blocked |
| `JN-03` | Public top-level type | Same as file name | Blocked |
| `JN-04` | `static final` primitive · `String` | UPPER_SNAKE_CASE | Blocked |
| `JN-05` | Method · field | lowerCamelCase (underscores allowed in methods under test paths) | Blocked |
| `JN-06` | Acronyms in type names | `HttpClient` (not `HTTPClient`) | Warning |

Source: [`references/java-naming-rules.md`](references/java-naming-rules.md)

## Usage

```bash
scripts/validate-java-naming.sh src/main/java     # directory
scripts/validate-java-naming.sh --all .           # whole project
test/validate-java-naming.test.sh                 # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
