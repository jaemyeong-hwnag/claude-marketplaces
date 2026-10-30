# common-document-slop-review

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Stops slop every time AI creates or edits a document — blocks chat residue, placeholders, chatbot tokens, and broken links; flags unsourced claims, undated time references, unsupported numbers, clichés, and over-formatting. Requires a review that checks claims against files, code, and links at the end of any session that edited documents.

Checks run in three layers.

| Layer | When | On what | What it does |
|---|---|---|---|
| 1. Mechanical check | Every document write | Lines written this time | Blocks obvious traces, flags style signals |
| 2. Judgment review | On review | Whole document | Checks whether content is correct, needed, and organized |
| 3. Completion gate | Session end | Documents edited in the session | Sends the session back once if layer 2 was skipped |

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-document-slop-review@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| document-slop-review | review this doc · check the README · fact-check · anything wrong · unnecessary content · slop | Mechanical check → fact check without authoring context → judge removable sentences, repetition, structure, format, terminology → fix defects only |
| /document-slop-validate | Direct call | Finds `DS-01` ~ `DS-16` in changed lines (default) or in the given paths |

## Agents

| Agent | Description |
|---|---|
| document-slop-reviewer | Takes only the document path, extracts factual claims, and checks them against repository files, commands, and links. Verdicts are `확인함` (verified) · `틀림` (wrong) · `미확인` (unverified). Does not edit the document |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| document-slop-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | In lines written this time, **blocks** `DS-01` ~ `DS-04` (exit 2) and **flags** `DS-05` ~ `DS-16` |
| document-slop-validate.sh | PostToolUse (Skill\|Agent\|Task) | Clears the gate record when `document-slop-review` or `document-slop-reviewer` runs. A `document-slop-reviewer` launched in the background is marked as reviewing |
| document-slop-validate.sh | SubagentStop | Clears the gate record when a background `document-slop-reviewer` finishes |
| document-slop-validate.sh | Stop | If documents were edited but not reviewed, sends the stop back once (`DS-30`) |

## Notes

- **Does not judge "whether AI wrote it".** Points only to fixable patterns and their lines. Human-written text with the same pattern is flagged too.
- Only four obvious traces are blocked: chat residue, placeholders, chatbot citation tokens, and relative links to paths that do not exist.
- Warnings are candidates. The skill makes the call.
- Evidence warnings (`DS-05` ~ `DS-07`) **do not mean delete.** Adding a source or marking `미확인` (unverified) passes. Deleting evidence to be concise lowers accuracy.
- Files checked: `.md` · `.mdx` · `.markdown` · `.rst` · `.txt` · `.adoc`
  - `requirements*.txt` · `constraints*.txt` · `*-lock.txt` · `CMakeLists.txt` · `robots.txt` · `LICENSE*` are skipped (case-insensitive).
- Not checked: front matter, code fences, inline code, quotes (`>`), HTML comments (including multi-line), lines over 4000 bytes
- For an intended line, put `<!-- document-slop-ignore -->` on that line or the line above.
- The evidence for the Korean word list (`DS-10`) is weaker than for English. So it flags only when 3 or more distinct words cluster.
- The completion gate records only when a document inside the project gets 3 or more lines edited at once.
  - It does not block twice in one request.
  - To turn it off: `DOCUMENT_SLOP_REVIEW_GATE=0`
- The script uses bash · awk · jq, and git for `--diff` and directory listing. Without jq the hook passes silently.

## Rule summary

| Clause | Content | Verdict |
|---|---|---|
| `DS-01` ~ `DS-04` | Chat residue · placeholders · chatbot tokens · broken relative links | Block |
| `DS-05` ~ `DS-07` | Source phrases without a source · undated time phrases · unsupported numbers | Warn |
| `DS-08` ~ `DS-13` | Meta narration · closing summary section · overused word cluster · repeated contrast phrasing · hype words · stacked hedges | Warn |
| `DS-14` ~ `DS-16` | Over-formatting · skipped heading levels · repeated sentences | Warn |
| `DS-20` ~ `DS-27` | Fact check · removable sentences · relevance · duplication · structure · format fit · reader cost · term consistency | AI judgment |
| `DS-30` | A session that edited documents and ends without review is sent back once | Gate |

Source: [`references/document-slop-rules.md`](references/document-slop-rules.md) · Patterns: [`references/document-slop-patterns.json`](references/document-slop-patterns.json) · Evidence: [`references/document-slop-methods.md`](references/document-slop-methods.md)

## Usage

```bash
scripts/document-slop-validate.sh --diff              # lines changed vs. the default branch
scripts/document-slop-validate.sh --diff origin/main  # lines changed vs. the given base
scripts/document-slop-validate.sh docs/ README.md     # whole paths
scripts/document-slop-validate.sh --strict docs/      # exit 2 even on warnings (CI)
test/document-slop-validate.test.sh                   # regression tests
```

## Evidence

| Clause | Evidence |
|---|---|
| Block criteria | Wikipedia speedy deletion criterion G15 · Signs of AI writing |
| Dictionary definition | 2025 words of the year from Merriam-Webster · Macquarie · American Dialect Society |
| Slop taxonomy | Shaib et al. 2025 · Kommers et al. 2025 |
| Overused words | Kobak et al. 2025 · Liang et al. 2024 · Antislop (ICLR 2026) |
| Fact check | FActScore · SAFE · Chain-of-Verification · Huang et al. ICLR 2024 |
| Documentation guides | GitLab · Grafana documentation style guides, Anthropic · OpenAI writing guidance |
| Cost | workslop (HBR 2025) |

Sources and confidence levels for each item are in `references/document-slop-methods.md`.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
