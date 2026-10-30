# code-edit-guardrail

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Enforces the lines Claude must not cross when editing code, with one project config — language-agnostic. Blocks completion when code changes without test changes, blocks completion when the lint · format · type-check command for the edited paths fails, and asks the user before shared resources are edited.

The plugin hooks run the engine; the project holds only one config file. No scripts are copied into the project, so a plugin update reaches every project at once.

```json
{
  "test":    { "code": ["src/main/**"], "tests": ["src/test/"] },
  "quality": [{ "name": "api", "paths": ["src/**"], "command": "./gradlew ktlintCheck" }],
  "shared":  { "paths": ["db/migration/"] }
}
```

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install code-edit-guardrail@jaemyeong-hwnag-plugins --scope project
```

After installing, say "set up the guardrail" to invoke `code-edit-guardrail-apply`, which creates `.claude/code-edit-guardrail.json`. Until the config exists, the hooks do nothing.

Requires `jq`. Without it the hooks pass silently (fail-open).

## Dependencies

None

## Skills

| Skill | Triggers | Description |
|---|---|---|
| code-edit-guardrail-apply | don't let it finish without tests · run lint at the end · ask before touching migrations · set up the guardrail | Detects the stack and fills in code · test globs and quality lanes; for shared resources it only proposes candidates and the user decides |

## Hooks

| Script | Event | Action |
|---|---|---|
| code-edit-guardrail.sh reset | UserPromptSubmit | Clears this request's edit log · exemptions |
| code-edit-guardrail.sh shared | PreToolUse (Edit\|Write\|MultiEdit) | **Asks the user** when a shared-resource path · content pattern matches (`G-03`) |
| code-edit-guardrail.sh track | PostToolUse (Edit\|Write\|MultiEdit\|NotebookEdit) | Records the edited file |
| code-edit-guardrail.sh stop | Stop | **Blocks** completion if code changed without test changes (`G-01`) or a quality lane for the edited paths fails (`G-02`). After one block, only warns the user (`systemMessage`) |

## Notes

- The unit of judgment is one request. Only files changed by Claude's edit tools count — files changed via Bash (code generators · `sed`) are not seen. It does not depend on git
- `G-01` only checks "was at least one test file edited". It does not check coverage
- Behavior-preserving changes are exempted after telling the user — the block message shows the exemption file path. An exemption is valid only for that request
- The edit log · exemption files live in the project's `.claude/code-edit-guardrail/`. The directory ignores itself, so it is never committed
- A quality lane runs at Stop only when a file edited in this request matches its `paths`. Use fast check commands, not a full build · test run (the time limit is 600 seconds for the whole Stop hook — lanes run one after another)
- A file in another git work tree under the project (`.claude/worktrees/<id>` · nested repository) uses that work tree as its root if the work tree has its own config — config, globs and lane working directory are relative to it. Without its own config, the project config applies
- The config path can be changed with the `CODE_EDIT_GUARDRAIL_CONFIG` environment variable (default `.claude/code-edit-guardrail.json`)
- Secrets · code ↔ docs sync are out of scope

## What it enforces

| | Rules |
|---|---|
| Gates (hooks) | `G-01` tests accompany code · `G-02` quality lane · `G-03` shared-resource confirmation |
| Config (`validate`) | `C-01` file · JSON · `C-02` top-level keys · `C-03` section shape · `C-04` regex · `C-05` glob matching no files (warning) |

## Files

| Path | Role |
|---|---|
| `references/code-edit-guardrail-rules.md` | Rule source — config format, glob syntax, rules, exemptions |
| `scripts/code-edit-guardrail.sh` | Four hook modes + CLI `validate` |
| `test/` | Regression tests and TC spec |
| `evals/` | `claude plugin eval` cases — config skill firing (`guardrail-config-request`) · blocking completion without tests (`test-missing-blocked`) |

## Usage

```bash
scripts/code-edit-guardrail.sh validate .   # validate the config
test/code-edit-guardrail.test.sh            # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
