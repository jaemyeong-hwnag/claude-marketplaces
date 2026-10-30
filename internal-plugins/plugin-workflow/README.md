# plugin-workflow

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Handles the **steps the plugin marketplace adds** to the GitHub flow — order of plugin creation · rename · deletion, running all validation, per-plugin tags · releases after install verification, and running evals.

Issue · branch · PR · merge rules (`W-01` ~ `W-10`) and their hooks are handled by the dependency `github-workflow`. Names · locations · versions · authoring format · dependency relations are handled by their own plugins.

## Installation

In this repository, the SessionStart hook (`.claude/hooks/sync-internal-plugins.sh`) registers, enables, and installs it. Claude Code installs the dependency `github-workflow` along with it.
It is an internal plugin and is not distributed to other repositories.

## Dependencies

| Plugin | Why |
|---|---|
| `github-workflow` | Issue · branch · PR · merge steps and hooks. This plugin adds steps in between |

## Skills

| Skill | Trigger | Description |
|---|---|---|
| plugin-release-create | release, tag, deploy | Steps 9 · 10 — verify install on main, tag · release each plugin whose current version has no tag |
| plugin-create | create a new plugin | Need check → name → placement → directory → version → rule source · validator · tests → README → dependencies → registration → eval → enforcement effectiveness check → validation → install verification |
| plugin-name-update | rename a plugin | User confirmation → new name → `--dry-run` → run → judge remaining references → version → reinstall notice → first tag under the new name. Public plugins leave a `renames` entry |
| plugin-delete | delete · disable a plugin | Check reverse references → cut dependencies → clean up directory · registration. Tags are kept |

## Files

| Path | Role |
|---|---|
| `references/workflow-rules.md` | Steps this marketplace adds (order relative to `github-workflow` steps) |
| `scripts/verify-all.sh` | Finds validators · regression tests · `claude plugin validate` by path convention and runs them all |
| `scripts/release-plugins.sh` | Tag · release each plugin whose current version has no tag (`--dry-run` · `--since`) |
| `scripts/plugin-name-update.sh` | Rename — changes the directory · `plugin.json` · entry · `renames` · dependents' `dependencies` · `enabledPlugins` key, and lists remaining reference candidates (`--dry-run`) |
| `scripts/eval-all.sh` | Runs every plugin's eval cases one case at a time — grants only needed permissions, does not publish reports (`--quick`) |
| `test/` | Regression tests and TC spec |
| `evals/` | `claude plugin eval` cases — create · rename · delete skill firing |

## Notes

- Skills · hooks running in a worktree session are **the main checkout's**. Changes made in a worktree take effect after merge
- The branch before this plugin and `.github/` reached main (`feature/plugin-creater-setting`) was merged once without an issue as a bootstrap exception

## Usage

Run from the repository root.

```bash
S=internal-plugins/plugin-workflow
$S/scripts/verify-all.sh .
$S/scripts/release-plugins.sh --dry-run
$S/scripts/eval-all.sh --quick .
$S/test/workflow-scripts.test.sh
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
