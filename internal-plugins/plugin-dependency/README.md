# plugin-dependency

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces **dependency relations** between plugins — existence · cycles · common and bundle layers · marketplace boundary · no public→internal · overlapping version ranges.

Range string format is checked by `plugin-versioning` (`V-11`), names by `plugin-naming`, locations by `marketplace-directory-structure`. This plugin checks **relations** only.

## Installation

In this repository, the SessionStart hook (`.claude/hooks/sync-internal-plugins.sh`) registers, enables, and installs it.
As an internal plugin it is not distributed to other repositories. To use it elsewhere, move it to `public-plugins/`.

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| dependency-update | Adding, changing, or removing dependencies; composing common · bundles | Judges layer direction and common eligibility |
| /dependency-validate | Invoke directly | Validates the whole repository graph; given a name, shows reverse dependencies |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-dependency.sh | PostToolUse (Write\|Edit) | After saving `plugin.json`, rechecks the whole repository graph and **notifies** |

## Files

| Path | Role |
|---|---|
| `references/dependency-rules.md` | Source of the dependency rules (`D-01` – `D-11`) |
| `scripts/validate-dependency.sh` | Mechanical validation. Graph computation (cycles · range intersection) is done in jq — macOS default bash 3.2 has no associative arrays |
| `test/` | Regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — bundle advice skill trigger · cycle notice. Run by `plugin-workflow`'s `eval-all.sh` |

## What it enforces

| | Rules |
|---|---|
| Graph | `D-01` target exists · `D-02` self-dependency · `D-03` cycle · `D-11` duplicate declaration |
| Layers | `D-04` common has no dependencies · `D-05` no bundle → bundle · `D-06` bundles have dependencies only |
| Boundary | `D-07` no other marketplace · `D-08` no public → internal |
| Ranges | `D-09` ranges on the same target must overlap · `D-10` exact pin is a warning |

## Why the hook only notifies

Breaking a cycle or aligning ranges often means editing **two plugins**. Blocking the first edit would make it unsolvable. `--all` does block.

## Usage

Run from the repository root. If `--all` finds no plugins, it is an execution error (exit code `1`).

```bash
internal-plugins/plugin-dependency/scripts/validate-dependency.sh --all .                       # whole repository
internal-plugins/plugin-dependency/scripts/validate-dependency.sh --dependents common-naming .  # who depends on it
internal-plugins/plugin-dependency/scripts/validate-dependency.sh internal-plugins/order-sync   # this plugin's declarations only
internal-plugins/plugin-dependency/test/validate-dependency.test.sh                             # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
