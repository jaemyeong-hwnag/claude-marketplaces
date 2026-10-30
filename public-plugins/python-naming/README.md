# python-naming

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces PEP 8 naming on Python code — lowercase snake_case module files, CapWords classes, snake_case functions and methods, warnings for mixedCase parameters and variables, `Error` suffix on exception classes.

A hook blocks wrong shapes; the `python-name-create` skill decides which words to use. Based on the Naming Conventions section of PEP 8 and the `N8xx` rules of pep8-naming (a flake8 plugin).

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-naming@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| python-name-create | Writing Python code · naming modules, classes, functions, variables | Shape table and word choice (abbreviations · shadowing builtins · underscore prefixes · boolean · collections · TypeVar) |
| /python-naming-validate | Invoked directly | Validates every `*.py` in the project and reports by rule |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-python-naming.sh | PreToolUse (Write\|Edit) | **Blocks** a `*.py` edit that **introduces** a violation; warning rules are reported as notices |

## Notes

- The hook compares the file before and after the edit and blocks **only added violations**. Editing other lines of a legacy file is not blocked by existing names. Find existing violations with `/python-naming-validate`
- Lines ending with `# noqa` or `# noqa: N8xx` are skipped (the same escape hatch as pep8-naming). unittest's `setUp` family, `visit_X`, `do_GET` and methods decorated with `@override` are not blocked
- Reads line by line, not a syntax tree. Parameters, variables and exception classes can produce false positives, so they are warnings only
- `venv/` · `.venv/` · `site-packages/` · `__pycache__/` · `build/` · `dist/` · `.tox/` · `.eggs/` · `node_modules/` · `migrations/` · `alembic/versions/` are skipped
- Requires `jq`

## Rule summary

| Rule | Target | Rule | Verdict |
|---|---|---|---|
| `PY-01` | Module file name | Lowercase snake_case (`__init__.py` allowed) | Blocked |
| `PY-02` | `class` | CapWords (leading underscore allowed) | Blocked |
| `PY-03` | `def` · `async def` | snake_case (leading underscore · dunder · unittest · `visit_X` allowed) | Blocked |
| `PY-04` | Parameters | snake_case — mixedCase warned | Warning |
| `PY-05` | Assignment targets | mixedCase warned (UPPER_SNAKE constants allowed) | Warning |
| `PY-06` | Exception class | Ends with `Error` | Warning |

Source: [`references/python-naming-rules.md`](references/python-naming-rules.md)

## Usage

```bash
scripts/validate-python-naming.sh app             # directory
scripts/validate-python-naming.sh --all .         # whole project
test/validate-python-naming.test.sh               # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
