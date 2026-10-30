# github-workflow

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces the **path a change takes from issue to merge** in a GitHub repository — feature · bugfix issue and PR templates, issue-numbered branches, default branch protection, merge commits after rebase, tags only on the default branch.

What to verify and test, and how to bump versions, is up to the project. This plugin only checks **the order of steps in git and GitHub**.

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install github-workflow@jaemyeong-hwnag-plugins --scope project
```

After installing, if templates or labels are missing, invoke `github-template-create` with "set up issue and PR templates".

Requires: `git`, `jq`, `gh` (logged in).

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| github-template-create | adopting the flow, issue · PR templates, labels | Step 0 — copy `.github/` issue forms · PR templates (no overwrite), labels `feature` · `bugfix` |
| issue-create | starting work, creating an issue · branch · worktree | Steps 1 · 2 — pick the type, open the issue, branch · worktree from the default branch |
| pull-request-create | opening a PR, rebase, verification | Steps 4 – 6 — project verification · tests, re-verify after rebase, PR with template · label |
| pull-request-merge | merge, cleanup | Steps 7 · 8 — merge commit, pull the default branch, clean up worktree · branch, confirm the issue is closed |
| /github-workflow-validate | invoked directly | Templates · current branch · up-to-date status |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| validate-workflow.sh | PreToolUse (Bash) | **Blocks** `git` · `gh` · `claude plugin tag` commands that violate `W-03` – `W-10`. Worktree location (`W-04`) is a notice |

## Notes

- Once installed, **`git commit` · `git push` · `cherry-pick` · `revert` · `am`, and `git merge` · `git pull` without `--ff-only` (passes with `pull.ff=only`), are blocked on this repository's default branch** (`W-09`). Work on a `{feature|bugfix}/{issue}-{slug}` branch
- The default branch is read from `origin/HEAD`. If missing, it checks `origin/main` → `origin/master` → `main` in that order — set it with `git remote set-head origin --auto`
- Without `jq`, `git` · `gh` · `claude` commands cannot be checked, so they are blocked
- Commands inside subshells · `bash -c` · `eval` · `$( )` are checked too. Commands assembled from variables (`$CMD`) are not
- Merges and pushes from the web UI cannot be blocked. Turn on branch protection as well if you can
- Since 0.2.0, `/github-workflow:workflow-validate` is invoked as `/github-workflow:github-workflow-validate`

## What it blocks

| | Rules |
|---|---|
| Templates | `W-01` issue forms `feature` · `bugfix` + no blank issues · `W-02` two PR templates, no single default file |
| Branches | `W-03` `{feature\|bugfix}/{issue}-{slug}` · `W-04` worktree location (notice) |
| PR · merge | `W-05` template · label · no `--fill` · `W-06` includes the latest default branch · `W-07` merge commits only |
| Default branch | `W-08` force push only with `--force-with-lease` · `W-09` no direct commit · merge · push · `W-10` tags only on the default branch |

## Files

| Path | Role |
|---|---|
| `references/workflow-rules.md` | Rule source (`W-01` – `W-10`, steps) |
| `scripts/validate-workflow.sh` | Validation for both hook and CLI (`--templates` · `--branch` · `--up-to-date`) |
| `scripts/branch-create.sh` | Step 2 — a rule-compliant branch and worktree from the default branch |
| `skills/github-template-create/templates/` | Default issue forms · PR templates |
| `test/` | Regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — PR skill firing · main commit blocked |

## Usage

```bash
scripts/validate-workflow.sh --templates .
scripts/branch-create.sh feature 12 order-sync
test/validate-workflow.test.sh
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
