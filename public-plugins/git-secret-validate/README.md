# git-secret-validate

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Keeps keys, tokens, and passwords out of Git — blocks secrets and sensitive files (`.env`, key files) in the changes a `git commit` or `git push` would carry, and warns when a file write puts a new secret into a non-ignored file or leaves a sensitive file un-ignored.

Detection is left to gitleaks; this plugin decides **when and what to scan** and judges ignore status. Without gitleaks it falls back to built-in patterns. Whether it is a real leak and how to fix it is decided by the `secret-review` skill.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install git-secret-validate@jaemyeong-hwnag-plugins
brew install gitleaks    # recommended — without it, built-in patterns are used
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| secret-review | checking for committed keys or tokens · checking gitignore · when the hook blocked · leaks | Separates false positives, in-progress exposure, and leaks, then acts (moving to env vars · ignoring · revoking keys · rewriting history are the user's call) |
| /secret-validate | Invoked directly | Scans the working tree (commit history with argument `history`, or the given file or directory) and reports by rule |

## Hooks

| Script | Event | Action |
|---|---|---|
| validate-git-secret.sh | PreToolUse (Bash) | **Blocks** when the changes a `git commit` or `git push` would carry contain secrets or sensitive files |
| validate-git-secret.sh | PreToolUse (Write\|Edit\|MultiEdit) | **Warns** when an edit creates a new secret or sensitive file that is not ignored |

## Notes

- Commits are blocked; writes only warn. Writing a key into an ignored `.env` is normal and is not reported
- In a single command like `git add … && git commit`, nothing is staged yet, so the paths given to `git add` are scanned (with `.`, `-A`, or `-u`: all changed files and all non-ignored new files)
- `git push` scans only commits on the current branch that are on no remote
- Only commands Claude runs are checked. To also block commits made directly in a terminal, add gitleaks to pre-commit and CI separately
- Exclude false positives with a `gitleaks:allow` comment on the line, or with `.git-secret-allow` at the repository root (one glob per line). The user decides what goes in
- Binary files and files over 1MB are not scanned. Requires `jq` and `git` (without jq, `git commit` and `git push` are blocked)

## Rule summary

| Rule | When | What | Verdict |
|---|---|---|---|
| `GS-01` | commit · push | Secrets in added lines | Block |
| `GS-02` | commit · push | Sensitive files (`.env` · `*.pem` · `id_rsa` · `credentials.json` …) | Block |
| `GS-03` | Write · Edit | New secret in a non-ignored file | Warn |
| `GS-04` | Write · Edit | Sensitive file that is not ignored or is tracked | Warn |
| `GS-05` | Always | If gitleaks is missing or fails, scan with built-in patterns and notify | Notify |

Source: [`references/secret-rules.md`](references/secret-rules.md) · Patterns and file lists: [`references/secret-rules.json`](references/secret-rules.json)

## Usage

```bash
scripts/validate-git-secret.sh --all .                   # working tree
scripts/validate-git-secret.sh --history .               # commit history
scripts/validate-git-secret.sh src/ config.yml           # only these paths
GIT_SECRET_ENGINE=builtin scripts/validate-git-secret.sh --all .   # pin the engine
test/validate-git-secret.test.sh                         # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
