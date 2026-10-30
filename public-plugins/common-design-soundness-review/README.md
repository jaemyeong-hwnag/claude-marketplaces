# common-design-soundness-review

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

A verifier with no authoring context judges whether a software design (structure · flow · decisions) holds together before implementation — plan-mode plans, designs proposed in chat, and design documents. It first summarizes the design, then checks grounds · rebuttals, contradictions · progression, flow dead ends and steps that serve no requirement, and a decision for each requirement. Leaving plan mode or finishing after editing a design document without review is sent back once.

UI and visual design are out of scope. Install it in other projects and use it while designing.

A designer rereading their own design is not a review. So the verdict comes from a verifier that does not know the conversation that led to the design, and it receives only the design file · requirement source · questions without conclusions.

| Layer | When | What it does |
|---|---|---|
| 1. Mechanical checks | When writing a design document · leaving plan mode | Reports required sections · mermaid flow reachability · requirement IDs · quality requirements without numbers · terms used before definition (`DD-20` ~ `DD-24`) |
| 2. Independent verdict | When the skill calls it | The verifier summarizes the design, then judges argument · rebuttal · contradiction · progression · flow soundness · flow fitness · requirement fit · decision record with quotes (`DD-01` ~ `DD-15`) |
| 3. Gates | Right before moving to implementation | Blocks leaving plan mode once (`DD-31`), sends back once the end of a request that changed 3+ lines of a design document (`DD-30`), and notifies on the first code edit after a design request (`DD-32`) |

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-design-soundness-review@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| design-soundness-review | design this · set up the structure · draft the flow · review the design · does this hold together? · is this design OK? | Fixes the design as a file, finds the requirement source (if none, extracts it from the design and asks for confirmation), and hands it to the verifier with questions without conclusions. Fixes own designs per the verdict (up to 2 re-reviews); for others' designs, produces a report and questions for the designer |
| /design-soundness-validate | Invoked directly | Finds `DD-20` ~ `DD-24` in design documents · plan files (`--plan`). With `--strict`, exits 2 when there are signals |

## Agents

| Agent | Description |
|---|---|
| design-soundness-reviewer | Receives only the design file · requirement source · questions. Produces a design summary (components · decisions · flow table · requirement ↔ decision), then quote → verdict (`결함` (defect) · `빈 곳` (gap) · `판정 불가` (undecidable)) per viewpoint. Does not modify the design |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| design-soundness-validate.sh | UserPromptSubmit | Records the request text (requirement source). Marks it as a design request if it has design keywords |
| design-soundness-validate.sh | PreToolUse (ExitPlanMode) | **Blocks** leaving plan mode once without review and reports the plan file · mechanical signals (`DD-31`) |
| design-soundness-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | For design documents, **reports** new mechanical signals. On the first code edit after a design request, reminds to review (`DD-32`) |
| design-soundness-validate.sh | PostToolUse (Agent\|Task) | Marks reviewed when `design-soundness-reviewer` finishes synchronously, or in review when launched in the background |
| design-soundness-validate.sh | SubagentStop | Marks reviewed when a background `design-soundness-reviewer` finishes. While in review, the plan-mode gate blocks even the same plan |
| design-soundness-validate.sh | Stop | Sends back the end once if 3+ lines of a design document in the project changed without review (`DD-30`) |

## Notes

- **Do not pass the verifier the conversation · reasons that led to the design.** For a design in chat, copy only the design into a temp file and pass that.
- The verifier runs on `sonnet`. This is a choice to use a model different from the designer's (same as `common-evidence-review`).
- Without a requirement source, requirement fit and flow fitness are `판정 불가` (undecidable). If the skill extracts requirements from the design and gets them confirmed, they are judged.
- A design document is a `.md` · `.mdx` · `.markdown` file identified by path (`adr/` · `adrs/` · `decisions/` · `rfc/` · `rfcs/` · `design/` · `designs/`, `*-design.md` · `*-rfc.md`) or by `<!-- design-document -->` in the first 20 lines. Comma-separated globs in `DESIGN_SOUNDNESS_PATHS` replace the default paths.
- Mechanical signals are candidates. They do not block. Signals already reported for the same file are not reported again. If a line is intended, put `<!-- design-soundness-ignore -->` on that line or the line above.
- `DD-24` applies only when the glossary section comes before the decision section or there is no decision section — a glossary at the end of a document is for reference. Korean terms are matched as substrings.
- Change the `DD-22` requirement ID pattern with `DESIGN_SOUNDNESS_REQUIREMENT_ID` (default `(R|FR|NFR|QA|REQ)-[0-9]+`).
- `DD-21` checks only mermaid edges. It ignores nested states and `--x` · `--o` · `---` edges.
- Plan-mode gate
  - Leaving again with the same plan is not blocked. But while a background verifier is still judging, even the same plan is blocked. `DESIGN_SOUNDNESS_PLAN_GATE=0` turns off only this gate.
  - It does not run under `claude -p` (non-interactive), which has no `ExitPlanMode` tool (confirmed 2026-10-30, Claude Code 2.1.314).
- `DESIGN_SOUNDNESS_GATE=0` turns off all three gates. Mechanical signals are still reported.
- Designs in chat are not blocked, only notified. A machine cannot tell where the design starts and ends.
- Editing a design document may also trigger the `common-document-slop-review` gate. Running both reviews together finishes in one go.
- The script uses bash · awk · jq. Without jq, the hooks pass silently.

## Rule summary

| Clause | Content | Judged by |
|---|---|---|
| `DD-01` · `DD-02` | A different context judges · pass only design file · requirement source · questions | AI (skill) |
| `DD-03` · `DD-15` | Fix the requirement source (if none, extract and confirm) · design summary first | AI |
| `DD-04` · `DD-05` | Argument structure · 2 rebuttals per key decision | AI (agent) |
| `DD-06` · `DD-14` | Contradictions · terms · progression | AI (agent) |
| `DD-07` · `DD-13` | Flow soundness · fitness (steps that serve no requirement, comparison with alternatives) | AI (agent) |
| `DD-08` · `DD-09` | A decision per requirement scenario · alternatives and confirmation method per decision | AI (agent) |
| `DD-10` ~ `DD-12` | Quote first · no invented findings · fix own design, report and ask questions for others' | AI |
| `DD-20` ~ `DD-24` | Required sections · flow reachability · requirement IDs · quality requirements without numbers · terms before definition | Notify |
| `DD-30` | Send back once a request that edited a design document and ended without review | Gate |
| `DD-31` | Block once leaving plan mode without review | Gate |
| `DD-32` | Notify on the first code edit after a design request | Notify |

Source: [`references/design-soundness-rules.md`](references/design-soundness-rules.md) · Basis: [`references/design-soundness-methods.md`](references/design-soundness-methods.md)

## Usage

```bash
scripts/design-soundness-validate.sh docs/adr/0003-cancel.md          # mechanical signals of a design document
scripts/design-soundness-validate.sh --plan ~/.claude/plans/x.md      # plan
scripts/design-soundness-validate.sh --strict docs/adr/*.md           # exit 2 if there are signals (CI)
test/design-soundness-validate.test.sh                                # regression tests
```

## Basis

| Clause | Basis |
|---|---|
| Check requirement fit with scenarios | ATAM (ICECCS 1998) · comparison of scenario-based evaluation (APSEC 2004) · arc42 quality scenarios |
| Decision unit · confirmation method | DCAR (IEEE Software 2014) · MADR 4.0.0 · fitness functions (Thoughtworks Radar) |
| Claims · rebuttals | SACM 2.3 · confidence from eliminated doubt (ASSURE 2013) · LLM rebuttal generation (ISSRE 2024) · pre-mortem (HBR 2007) |
| Contradictions · inconsistencies | Managing specification inconsistency (TOSEM 1998 · RE 1995) · LLM requirement inconsistency detection (RE 2023) |
| Flow | Workflow soundness (TU/e 2008) · multi-view consistency · AWS TLA+ (CACM 2015) |
| Others' designs | ARID (SEI 2000) · inspection (IBM Systems Journal 1976) |
| Different context · inputs without conclusions | Same basis as `common-evidence-review` |

Sources, confidence levels, and "choices" (adopted or decided without direct evidence) for each item are in `references/design-soundness-methods.md`.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
