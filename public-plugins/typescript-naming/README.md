# typescript-naming

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces TypeScript conventions on identifiers in TypeScript source — PascalCase types, classes and enums, camelCase variables and functions (no snake_case), warnings for interface `I` prefix, enum members, type parameters and class members.

A hook blocks wrong shapes; the `typescript-name-create` skill decides which words to use. Based on the Names section of the TypeScript team Coding guidelines · TypeScript Handbook · typescript-eslint `naming-convention` defaults · the Identifiers section of the Google TypeScript Style Guide.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install typescript-naming@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| typescript-name-create | Writing `.ts` · `.tsx` code · naming interfaces, types, generics | Shape table and word choice (type/value name clashes · `Props` suffix · boolean · union literals · acronyms) |
| /typescript-naming-validate | Invoked directly | Validates every `*.ts` · `*.tsx` · `*.mts` · `*.cts` in the project and reports by rule |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-typescript-naming.sh | PreToolUse (Write\|Edit) | **Blocks** a `*.ts` · `*.tsx` · `*.mts` · `*.cts` edit that **introduces** a violation; warning rules are reported as notices |

## Notes

- The hook compares the file before and after the edit and blocks **only added violations**. Editing other lines of a legacy file is not blocked by existing names. Find existing violations with `/typescript-naming-validate`
- Reads line by line without a parser. Destructuring, object literal keys, interface and type properties, and parameters are not checked — left to the skill
- Only class members starting with an access modifier (`public` · `protected` · `private`) or `readonly` are checked. Some DTOs take API payloads as-is, so this is a warning only
- File names, `package.json` and environment variable names are not checked
- `*.d.ts` · `*.d.mts` · `*.d.cts` and `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` · `__generated__/` are skipped
- Requires `jq`

## Rule summary

| Rule | Target | Rule | Verdict |
|---|---|---|---|
| `TS-01` | class · interface · type · enum · namespace | PascalCase | Blocked |
| `TS-02` | interface | No `I` prefix (not `IUser`) | Warning |
| `TS-03` | `let` · `const` · `var` · `function` | No lowercase snake_case → camelCase (UPPER_SNAKE · PascalCase · leading underscore allowed) | Blocked |
| `TS-04` | enum member | PascalCase or UPPER_SNAKE_CASE | Warning |
| `TS-05` | Type parameter | `T` · `TKey` · PascalCase | Warning |
| `TS-06` | Class member (access modifier · `readonly`) | No snake_case → camelCase | Warning |

Source: [`references/typescript-naming-rules.md`](references/typescript-naming-rules.md)

## Usage

```bash
scripts/validate-typescript-naming.sh src           # directory
scripts/validate-typescript-naming.sh --all .       # whole project
test/validate-typescript-naming.test.sh             # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
