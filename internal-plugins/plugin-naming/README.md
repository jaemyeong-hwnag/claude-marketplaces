# plugin-naming

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces names of plugins, skills, commands, and agents with shared rules and a glossary.

It handles **names only**. Which directory a file goes in, or how it is distributed, is not this plugin's concern.

## Installation

In this repository, the SessionStart hook (`.claude/hooks/sync-internal-plugins.sh`) registers, enables, and installs it.
As an internal plugin it is not distributed to other repositories. To use it elsewhere, move it to `public-plugins/`.

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| name-create | Naming or renaming; creating a plugin, skill, or command | Picks the concepts to carry from a purpose sentence ("without this, …") and builds the name from the `{대상}-{범위}-{관심사}-{행위}` (target-scope-concern-action) slots (1 – 3 words per slot) and the glossary. A name that passes is judged by `naming-reviewer` |
| glossary-update | Adding or changing glossary words, "can I use this word?" | Edits the glossary following the duplicate, ordering, and category rules |
| /naming-review | Invoke directly | Validates and judges one name or the whole repository |

## Agents

| Agent | Description |
|---|---|
| naming-reviewer | Judges whether a name that passed the mechanical rules says what it refers to, and whether the purpose sentence's key word shows in it |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-naming.sh | PreToolUse (Write\|Edit) | Extracts names from the path; **blocks** on a rule violation, and asks for AI judgment on a new name that passes |
| validate-naming.sh | PostToolUse (Write\|Edit) | Validates the glossary structure when `glossary.json` is saved |

## Files

| Path | Role |
|---|---|
| `references/naming-rules.md` | Source of the naming rules. Single source of truth |
| `references/glossary.json` | Default word glossary (`use` / `deny` / `meaning`) |
| `scripts/validate-naming.sh` | Mechanical validation. Serves both the hook and the CLI |
| `test/` | Regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — naming skill trigger · one-word name blocked. Run by `plugin-workflow`'s `eval-all.sh` |

## Behavior

On `Write` / `Edit`, names are extracted from the path and checked; a violation is blocked with exit code 2.

| Path pattern | Checked |
|---|---|
| `*plugins/<name>/...` | Plugin name |
| `.../skills/<name>/...` | Skill name |
| `.../commands/<name>.md` | Command name |
| `.../agents/<name>.md` | Agent name |

Other paths are ignored. **Any directory named `plugins` or ending in `-plugins`**, such as `plugins/`, `public-plugins/`, or `my-own-plugins/`, is treated as a plugin location. What those directories mean is up to the repository.

## Per-project glossary

The glossary is resolved in this order.

1. `$NAMING_GLOSSARY`
2. `internal-plugins/plugin-naming/references/glossary.json` at the git top level of the edited path (CLI: current directory, `--all`: root) ← glossary edited in a worktree
3. `$CLAUDE_PROJECT_DIR/references/glossary.json` ← project-specific
4. `${CLAUDE_PLUGIN_ROOT}/references/glossary.json` ← plugin default

A project glossary **replaces** the plugin glossary. It is not merged, so copy the default glossary and add your domain words.

## CLI

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" <name or path>
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --all .
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --glossary
```

## Tests

```bash
test/validate-naming.test.sh
```

TC specs: [`test/README.md`](test/README.md).

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
