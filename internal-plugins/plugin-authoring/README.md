# plugin-authoring

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces the **content format** of plugin files — skill · command · agent frontmatter, skill body and reference sizes, and the section layout of the three-language READMEs and their match with the actual components.

Names are checked by `plugin-naming`, file locations by `marketplace-directory-structure`, versions by `plugin-versioning`. This plugin only looks **inside files that are already in the right place**.

## Installation

In this repository the SessionStart hook (`.claude/hooks/sync-internal-plugins.sh`) registers, enables, and installs it.
It is an internal plugin and is not distributed to other repositories. To use it elsewhere, move it to `public-plugins/`.

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| plugin-document-create | Writing SKILL.md · description · README | Frontmatter and description judgment, three-language README template |
| /authoring-validate | Direct call | Validates the authoring rules for every plugin in the repository |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-authoring.sh | PreToolUse (Write) | **Blocks** a SKILL.md · command · agent written with `Write` if its frontmatter is wrong (`A-01` ~ `A-04`) |
| validate-authoring.sh | PostToolUse (Write\|Edit) | After a plugin file is saved, checks that whole plugin and **notifies** |

## Files

| Path | Role |
|---|---|
| `references/authoring-rules.md` | Authoring rules source (`A-01` ~ `A-09` skills · commands · agents · references, `A-20` ~ `A-30` README) |
| `scripts/validate-authoring.sh` | Machine validation. Serves as both hook and CLI |
| `test/` | Regression tests and TC spec |
| `evals/` | `claude plugin eval` cases — description-writing skill triggering · blocking a SKILL.md without frontmatter. Run by `plugin-workflow`'s `eval-all.sh` |

## What it blocks

| | Rules |
|---|---|
| Frontmatter | `A-01` opened and closed · `A-02` name = directory or file name · `A-03` description · `A-04` "use when …" |
| Size (warning) | `A-05` description 300 chars · `A-06` SKILL.md 200 lines · `A-07` references 500 lines |
| References | `A-08` relative links point to existing files · `A-09` no external URLs in skills · references |
| README | `A-20` first heading · `A-21` required sections · `A-22` per-component sections · `A-23` order · `A-24` ~ `A-27` tables ↔ reality · `A-28` public install command — for each language file with that language's headings |
| Languages | `A-29` the three READMEs link to each other · `A-30` the three root READMEs list every public plugin |

## Why the hook has two paths

Creating a skill and then updating the README takes two edits. Blocking the first edit for a README mismatch would make it impossible to create anything.
So only **what can be judged from a single file**, like frontmatter, is blocked in `PreToolUse`; anything that needs the whole plugin is reported after saving. `--all` blocks everything.

## Usage

Run from the repository root. If `--all` finds no plugins, it is an execution error (exit code `1`).

```bash
internal-plugins/plugin-authoring/scripts/validate-authoring.sh internal-plugins/plugin-authoring   # one plugin
internal-plugins/plugin-authoring/scripts/validate-authoring.sh --all .                             # whole repository (including root READMEs)
internal-plugins/plugin-authoring/test/validate-authoring.test.sh                                   # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
