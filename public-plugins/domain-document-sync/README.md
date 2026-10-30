# domain-document-sync

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Keeps domain knowledge documents in **3 layers** (catalog `_index` → domain meta `_meta` → concept) and in sync with the code — document generation from language- · framework-agnostic code analysis, reading only the domains needed, editing protocol injection, and a document sync gate on code changes.

Which code belongs to which domain is stated not by a script but by the `code:` globs in each domain's `_meta.md` front matter. So Java · TypeScript · Python · Go … anything, monorepo or single module, runs under the same rules.

```
docs/domain/
  _index.md            # catalog — 1 row per domain, triggers (words · identifiers · paths · symptoms)
  order/
    _meta.md           # code: globs · relations · part table (when to read which file)
    entities.md        # concept — rules · entities · flows
    flows.md
```

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install domain-document-sync@jaemyeong-hwnag-plugins --scope project
```

After installing, if there are no documents, call `domain-document-create` with "Create domain documents". While the document root does not exist, the hooks do nothing.

Requires: `git`, `jq`. Without them, the hooks pass silently (fail-open).

## Dependencies

None

## Skills

| Skill | Triggers | Description |
|---|---|---|
| domain-document-get | domain rules · which domain · affected domains | Reads only the needed parts in `_index → _meta → concept` order |
| domain-document-create | create domain documents · organize domains · new domain | Analyzes the codebase language-agnostically, splits domains, and creates the 3 layers |
| domain-document-update | update documents · sync gate block | Reflects code changes into concepts and adjusts `_meta` · `_index` only when they changed. Exemption procedure |
| /domain-document-validate | Invoked directly | Validates the document tree (`D-01` – `D-08`) + code mapping per domain |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| domain-document-sync.sh session | SessionStart | If the document root exists, **injects** the catalog location · domain list · reading order. Cleans up state files older than 7 days |
| domain-document-sync.sh snapshot | UserPromptSubmit | Saves per-domain code · document fingerprints at request start and clears past exemptions |
| domain-document-sync.sh pre-edit | PreToolUse (Edit\|Write\|MultiEdit) | When editing the document root, **injects** the 3-layer protocol (per catalog · meta · concept · new domain) |
| domain-document-sync.sh post-edit | PostToolUse (Edit\|Write\|MultiEdit) | **Notifies** when a concept exceeds 300 lines (`D-07`) or is missing from the `_meta` part table (`D-05`) |
| domain-document-sync.sh stop | Stop | **Blocks** completion if a domain whose code changed in this request has no document change (`S-01`). After one block, only warns |

## Notes

- `S-01` judges by the working tree (changes + untracked) against HEAD at request start. It catches commits made within the request and does not block requests that only asked questions. The documents must also change in this request
- Worktrees under the project (`.claude/worktrees/{x}` etc.) are also judged against their own working tree
- State · exemption files live in the project's `.claude/domain-document-sync/` — they ignore themselves and can be written from inside the Bash sandbox
- Changes that leave domain knowledge unchanged (refactors · tests · formatting) are exempted after telling the user — the block message shows the exemption file path. An exemption is valid only for that request
- Broad `code:` globs (`src/**`) make every change require that domain's documents. Check the matched file count with `map` and narrow them
- Paths may contain Korean characters · spaces. Project paths reached through symbolic links are also recognized
- Configuration goes in `env` of the project's `.claude/settings.json` — `DOMAIN_DOCUMENT_ROOT` (default `docs/domain`), `DOMAIN_DOCUMENT_MAX_LINES` (default `300`)

## What it blocks

| | Rules |
|---|---|
| Tree (`validate`) | `D-01` root · `_index.md` · `D-02` `_meta.md` per domain · `D-03` kebab-case slug · `D-04` listed in catalog · `D-05` listed in meta part table · `D-06` relative links |
| Warnings | `D-07` concept 300 lines · `D-08` `code:` glob matching no files |
| Sync (Stop hook) | `S-01` when a domain's code changes, its documents change too |

## Files

| Path | Role |
|---|---|
| `references/domain-document-rules.md` | Source of rules — 3 layers, rules, `code:` glob syntax, gate behavior, read · write procedures, configuration |
| `references/templates.md` | `_index` · `_meta` · concept skeletons, how to split concepts |
| `scripts/domain-document-sync.sh` | Five hook modes + CLI `validate` · `map` |
| `test/` | Regression tests and TC specs |
| `evals/` | `claude plugin eval` cases — domain lookup order (`domain-lookup`) · document editing protocol injection (`edit-protocol-injected`) |

## Usage

```bash
scripts/domain-document-sync.sh validate .   # validate the document tree
scripts/domain-document-sync.sh map .        # domain → code globs → matched file count
test/domain-document-sync.test.sh            # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
