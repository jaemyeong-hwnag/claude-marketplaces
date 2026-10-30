# plugin-enforcement-effectiveness

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Reproduces and blocks cases where enforcement a plugin declares in hook config, agent frontmatter, or its rule source is **silently turned off at runtime**.

If a blocking hook's script is missing, not executable, or given as a relative path, the hook fails and the tool call goes through. A plugin agent's `permissionMode` · `hooks` · `mcpServers` are ignored. `claude plugin validate --strict` passes all of these (reproduction commands in section 5 of the rule source).

Format is checked by `plugin-authoring`, file location by `marketplace-directory-structure`, creation order by `plugin-workflow`. This plugin checks what **has no effect at runtime** even when the format is correct.

## Installation

In this repository, the SessionStart hook (`.claude/hooks/sync-internal-plugins.sh`) registers, enables, and installs it.
It is an internal plugin and is not distributed to other repositories.

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| enforcement-effectiveness-review | Review plugin composition, role separation, whether hooks actually block | Script → review agent → reproduce findings → report |
| /enforcement-effectiveness-validate | Invoke directly | Validates the whole repository, including running hooks and MCP servers |

## Agents

| Agent | Description |
|---|---|
| enforcement-effectiveness-reviewer | Judges role separation (`EF-40` ~ `EF-44`) without authoring context and attaches a reproduction command to each finding. Does not modify files |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-enforcement-effectiveness.sh | PreToolUse (Write) | **Blocks** a `hooks.json` · `plugin.json` · agent · skill · command being written if it violates a clause decidable from that one file (`EF-01` · `EF-04` · `EF-10` · `EF-11` · `EF-13`). `onFailure: "block"` |
| validate-enforcement-effectiveness.sh | PostToolUse (Write\|Edit) | After a plugin file is saved, checks that whole plugin and **notifies** |

## Files

| Path | Role |
|---|---|
| `references/enforcement-effectiveness-rules.md` | Rule source — clauses, when they are judged, evidence and reproduction commands |
| `scripts/validate-enforcement-effectiveness.sh` | Mechanical validation. Used both as hook and CLI |
| `test/` | Regression tests, mutation test results, and TC spec |
| `evals/` | `claude plugin eval` cases — blocking ignored agent fields · review skill firing. Run by `plugin-workflow`'s `eval-all.sh` |

## What it blocks

| | Clauses |
|---|---|
| Enforcement chain | `EF-01` relative path · `EF-02` target file · `EF-03` execute permission · `EF-04` events that take no matcher · `EF-05` clause ID ↔ TC · `EF-06` validator or hook when clauses exist · `EF-07` `onFailure: "block"` (blocks only in `--since`) |
| Declarations applied | `EF-10` ignored agent fields · `EF-11` `tools` declared · `EF-12` edit tools (warning) · `EF-13` command · skill name clash |
| Execution | `EF-20` hook run on unrelated input (warning) · `EF-21` MCP `initialize` · `EF-22` referenced MCP tool names |
| eval | `EF-30` trigger · hook cases · `EF-31` firing grader per skill (blocks only new plugins in `--since`) |

## Why existing plugins are not blocked right away

`EF-07` · `EF-31` are warnings in `--all`. As of 2026-10-30, 17 skills have no firing grader (all 26 hooks that lacked `onFailure` have been fixed) — fixing them all at once would bump most plugin versions.
Because `verify-all.sh` also runs `--since origin/main`, they block on **newly created or modified plugins** (`EF-31` only on new plugins).

## Usage

Run from the repository root. If `--all` finds no plugins, it is a run error (exit code `1`). `--all` · `--since` actually run hook scripts and MCP servers in a temporary directory (skipped with `--no-run`).

```bash
S=internal-plugins/plugin-enforcement-effectiveness
$S/scripts/validate-enforcement-effectiveness.sh $S                          # one plugin (no execution checks)
$S/scripts/validate-enforcement-effectiveness.sh --all .                     # whole repository
$S/scripts/validate-enforcement-effectiveness.sh --since origin/main .       # changed plugins only
$S/test/validate-enforcement-effectiveness.test.sh                           # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
