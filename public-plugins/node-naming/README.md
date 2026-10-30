# node-naming

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces npm rules and JavaScript conventions on Node.js project names — package.json name, UPPER_SNAKE_CASE environment variables, PascalCase classes, camelCase variables and functions, kebab-case files.

A hook blocks wrong shapes; the `node-name-create` skill decides which words to use. Based on npm's package.json `name` rules · the Naming Conventions of the Airbnb JavaScript Style Guide · Node.js and POSIX environment variable conventions.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install node-naming@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| node-name-create | package.json · npm package name · npm script · environment variable name · `.js` · `.mjs` | Shape table and word choice (environment variable prefixes · module files and exports · CLI bin · event names) |
| /node-naming-validate | Invoked directly | Validates `package.json`, JS files and environment variables across the project and reports by rule |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-node-naming.sh | PreToolUse (Write\|Edit) | **Blocks** an edit to `package.json` · `*.js` · `*.mjs` · `*.cjs` · `*.jsx` (and environment variables in TS) that **introduces** a violation; warning rules are reported as notices |

## Notes

- The hook compares the file before and after the edit and blocks **only added violations**. Editing other lines of a legacy file is not blocked by existing names. Find existing violations with `/node-naming-validate`
- In TS files (`*.ts` · `*.tsx` · `*.mts` · `*.cts`) only environment variables (`ND-03`) are checked. Identifiers belong to `typescript-naming`
- For variables and functions, only the first name of a `let` · `const` · `var` · `function` declaration is checked. Methods, object properties, parameters and destructuring are left to the skill
- Environment variables read via destructuring, like `const { dbHost } = process.env`, are not checked
- If `package.json` is not valid JSON after the edit, it is not judged
- `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` · `vendor/` and `*.min.js` are skipped
- Requires `jq`

## Rule summary

| Rule | Target | Rule | Verdict |
|---|---|---|---|
| `ND-01` | Top-level `name` in `package.json` | npm rules (≤ 214 chars · lowercase · no leading `.` `_` · URL-safe · `@scope/name`) | Blocked |
| `ND-02` | `scripts` keys in `package.json` | Lowercase and digits joined by `-` and `:` (`test:unit`) | Warning |
| `ND-03` | `process.env.NAME` · `process.env['NAME']` | UPPER_SNAKE_CASE (exceptions: `npm_*` · proxy variables) | Blocked |
| `ND-04` | JS class | PascalCase | Blocked |
| `ND-05` | JS `let` · `const` · `var` · `function` | No snake_case with lowercase → camelCase | Blocked |
| `ND-06` | JS file name | kebab-case, or camelCase · PascalCase after the export name. Only underscores warned | Warning |

Source: [`references/node-naming-rules.md`](references/node-naming-rules.md)

## Usage

```bash
scripts/validate-node-naming.sh src package.json     # files · directories
scripts/validate-node-naming.sh --all .              # whole project
test/validate-node-naming.test.sh                    # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
