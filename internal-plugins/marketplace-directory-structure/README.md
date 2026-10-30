# marketplace-directory-structure

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces the **directory structure** of the marketplace root and of each plugin.

It handles only **what goes where**. Whether a name is correct (`plugin-naming`), and whether a plugin is public or internal and registered correctly (repository `.claude/hooks/`), are not this plugin's concern.

## Installation

In this repository, the SessionStart hook (`.claude/hooks/sync-internal-plugins.sh`) registers, enables, and installs it.
As an internal plugin it is not distributed to other repositories. To use it elsewhere, move it to `public-plugins/`.

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| plugin-directory-create | Creating a plugin, where to put a component | Creates the plugin and its components following the directory structure rules |
| /directory-structure-validate | Invoke directly | Validates the structure of the root and every plugin |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-directory-structure.sh | PreToolUse (Write\|Edit) | **Blocks** a path inside a plugin that is not an allowed location |

## Files

| Path | Role |
|---|---|
| `references/directory-structure-rules.md` | Source of the structure rules. Single source of truth (`R-0x` root / `P-0x` plugin) |
| `scripts/validate-directory-structure.sh` | Mechanical validation. Serves both the hook and the CLI |
| `test/` | Regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — location skill trigger · `docs/` blocked. Run by `plugin-workflow`'s `eval-all.sh` |

## Behavior

On `Write` / `Edit`, if the path is inside a plugin (`public-plugins/<name>/...` · `internal-plugins/<name>/...`), it checks **whether that file may go in that location**; a violation is blocked with exit code 2.

| Path | Result |
|---|---|
| `internal-plugins/order-sync/scripts/run.sh` | Pass |
| `internal-plugins/order-sync/hooks/run.sh` | Blocked — `hooks/` holds manifests (`*.json`) only |
| `internal-plugins/order-sync/docs/guide.md` | Blocked — unknown directory |
| `internal-plugins/order-sync/NOTES.md` | Blocked — the root holds only README·README.ko·README.zh-CN·CHANGELOG·LICENSE·.gitignore |
| `.agent-tasks/order/plan.md` | Ignored |

The hook checks **location only**. Whether all required files exist (`README.md`, `CHANGELOG.md`, `SKILL.md` …) cannot be judged while files are being created one by one, so the full CLI check covers it.

## CLI

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" --all .            # root + all plugins
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" --marketplace .    # root only
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" internal-plugins/order-sync
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" internal-plugins/order-sync/docs/guide.md
```

Exit codes: `0` pass / `2` violation / `1` execution error.

## Rule summary

On conflict, [`references/directory-structure-rules.md`](references/directory-structure-rules.md) wins.

Plugin root: `.claude-plugin/plugin.json` · `README.md` · `README.ko.md` · `README.zh-CN.md` · `CHANGELOG.md` are required. The only files allowed at the root are `README.md` · `README.ko.md` · `README.zh-CN.md` · `CHANGELOG.md` · `LICENSE` · `.gitignore`.

| Directory | Allowed |
|---|---|
| `.claude-plugin/` | `plugin.json` |
| `skills/` | `{skill-name}/SKILL.md` (anything inside the directory) |
| `hooks/` | `*.json` |
| `scripts/` | `*.sh` |
| `commands/` | `*.md` |
| `references/` | `*.md` `*.json` |
| `agents/` | `*.md` |
| `test/` | `*.test.sh` `README.md` |
| `evals/` | `{case-name}/` directories. Their contents follow the Claude Code eval format (`prompt.md` · `graders/*.md` · `case.yaml` · fixtures), so anything goes |

Marketplace root: `.claude-plugin/marketplace.json` · `README.md` · `README.ko.md` · `README.zh-CN.md` · `CHANGELOG.md` required; `.claude-plugin/` holds only `marketplace.json` `tags.json` `categories.json` `plugins.json` `keywords.json`; plugins go directly under `public-plugins/<name>/` · `internal-plugins/<name>/` only.

## Tests

```bash
test/validate-directory-structure.test.sh          # all
test/validate-directory-structure.test.sh TC-D1    # filter by ID prefix
```

TC specs: [`test/README.md`](test/README.md).

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
