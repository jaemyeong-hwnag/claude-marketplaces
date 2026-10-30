# plugin-versioning

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

An internal plugin that enforces consistency between a plugin's version value and every place that value is recorded.

Names are checked by `plugin-naming`, directory structure by `marketplace-directory-structure`, placement and distribution by the repository `.claude/hooks/`.
This plugin checks **versions only**.

## Installation

In this repository, the SessionStart hook (`.claude/hooks/sync-internal-plugins.sh`) registers, enables, and installs it.
As an internal plugin it is not distributed to other repositories. To use it elsewhere, move it to `public-plugins/`.

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| version-update | Bumping a version, CHANGELOG | semver bump-level judgment and the order of bumping |
| /versioning-validate | Invoke directly | Validates version consistency for the whole repository and for the current change range (`--since`) |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-versioning.sh | PreToolUse (Write\|Edit) | **Blocks** a wrong `version` value written into `plugin.json` (`V-01` · `V-03`) |
| validate-versioning.sh | PostToolUse (Write\|Edit) | After saving `plugin.json` · `CHANGELOG.md`, **notifies** if `V-01` – `V-08` fail |

## Files

| Path | Role |
|---|---|
| `references/versioning-rules.md` | Source of the rules |
| `scripts/validate-versioning.sh` | Mechanical validation (hook mode + CLI mode) |
| `test/` | Regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — bump-level skill trigger · `0.0.x` blocked. Run by `plugin-workflow`'s `eval-all.sh` |

## What it enforces

| | Rules |
|---|---|
| Version value | `V-01` three-part semver · `V-02` version required · `V-03` initial version `0.1.0` |
| CHANGELOG | `V-04` first line · `V-05` entry heading · `V-06` entry for the current version exists · `V-07` descending order · `V-08` no duplicates |
| Declaration sites | `V-09` entry ↔ plugin.json match · `V-10` marketplace metadata.version · `V-11` dependencies range |
| Tags | `V-12` `{plugin-name}--v{version}` (format only) · `V-13` a tag cannot be ahead of the manifest |
| Changes | `V-14` a plugin whose files changed since the base ref must bump its version (`--since`) |

The source of the rules is [`references/versioning-rules.md`](references/versioning-rules.md). On conflict, it wins.

**The bump level (PATCH/MINOR/MAJOR) is not judged mechanically.** The `version-update` skill decides.

## Why the hook has two branches

Bumping a version and writing the CHANGELOG takes **two edits**. Blocking the first edit on `V-06` would make progress impossible.

- `PreToolUse` — **blocks** only when the `version` value written into `plugin.json` is wrong in itself (`V-01` · `V-03`)
- `PostToolUse` — after saving, **notifies** through `additionalContext` if `V-01` – `V-08` fail. Does not block

## Usage

```bash
# Whole repository (root + all plugins + tags)
scripts/validate-versioning.sh --all .

# One plugin
scripts/validate-versioning.sh internal-plugins/plugin-versioning

# Root entries only
scripts/validate-versioning.sh --marketplace .

# Tags only
scripts/validate-versioning.sh --tag .

# PR range — did changed plugins bump their version?
scripts/validate-versioning.sh --since origin/main .

# Regression tests
test/validate-versioning.test.sh
```

Exit code `2` means a rule violation.

## Release

```bash
# 1. judge level → 2. CHANGELOG → 3. plugin.json → 4. entry → 5. validate → 6. commit·PR·merge
```

7. Tags and releases are not done by this plugin. After merging and confirming installation, run the `plugin-release-create` skill (`plugin-workflow`) on main. Its script creates the `{plugin-name}--v{version}` tag with `claude plugin tag --push` and a GitHub release for each plugin.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
