# go-naming

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces Go naming conventions on Go code — single lowercase word packages, MixedCaps for functions, types, variables, constants and fields (no underscores), uppercase initialisms, no `Get` on getters, lowercase file names, short receiver names.

A hook blocks wrong shapes; the `go-name-create` skill decides which words to use. Based on the Names section of Effective Go · Go Code Review Comments · the Go blog post "Package names" · staticcheck ST1003.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install go-naming@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| go-name-create | Writing Go code · naming packages, functions, types, receivers | Shape table and word choice (package name stutter · `-er` interfaces · short local variables · exported or not) |
| /go-naming-validate | Invoked directly | Validates every `*.go` in the project and reports by rule |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-go-naming.sh | PreToolUse (Write\|Edit) | **Blocks** a `*.go` edit that **introduces** a violation; warning rules are reported as notices |

## Notes

- The hook compares the file before and after the edit and blocks **only added violations**. Editing other lines of a legacy file is not blocked by existing names. Find existing violations with `/go-naming-validate`
- Reads line by line without a parser. Local variables, parameters and `:=` are not checked, nor fields of a struct written on one line (`struct{ A_b int }`)
- Constants are MixedCaps too — `MAX_SIZE` is blocked (`MaxSize`). If you must follow C names, as with cgo · syscall constants, keep them in a generated file or an existing file
- `vendor/` · `testdata/` · `node_modules/` and files marked `// Code generated ... DO NOT EDIT.` are skipped
- Requires `jq`

## Rule summary

| Rule | Target | Rule | Verdict |
|---|---|---|---|
| `GO-01` | `package` name | Single lowercase word (`_test` suffix allowed) | Blocked |
| `GO-02` | Function · method · type · top-level var/const · struct field | MixedCaps without underscores (`Test*` etc. in `_test.go` allowed) | Blocked |
| `GO-03` | Initialisms in names | `userID` · `HTTPClient` (not `userId`) | Warning |
| `GO-04` | `GetX()` method with no parameters | No `Get` on getters (`Owner()`) | Warning |
| `GO-05` | File name | Lowercase · digits · underscores (`order_service.go`) | Warning |
| `GO-06` | Method receiver | Not `this` · `self` → `func (o *Order)` | Warning |

Source: [`references/go-naming-rules.md`](references/go-naming-rules.md)

## Usage

```bash
scripts/validate-go-naming.sh ./internal     # directory
scripts/validate-go-naming.sh --all .        # whole project
test/validate-go-naming.test.sh              # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
