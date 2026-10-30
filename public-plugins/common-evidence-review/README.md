# common-evidence-review

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

A verifier with no authoring context judges, from execution evidence, whether the AI's changes and claims are really needed and correct — it receives only open questions with the conclusion removed, evidence comes first and none means undecidable, bug claims are reproduced as failing before the fix and passing after, test weakening (skip · fewer assertions) is flagged, and ending after editing code without verification is turned back once.

A model re-reading its own output is not verification. And showing the verifier the author's conclusion pulls the verdict toward it. So verification runs in a different context, and the verifier never receives the conclusion.

| Layer | When | What it does |
|---|---|---|
| 1. Mechanical check | Every time a test file is edited | Flags when skip · focus markers increase or assertions decrease (`E-20`) |
| 2. Independent verdict | On review | A verifier that receives only the original request · changed files · conclusion-free questions judges each change for necessity · correctness (`E-01` ~ `E-11`) |
| 3. Completion gate | When a request ends | If code · config was changed and layer 2 was skipped, turns the stop back once (`E-30`) |

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-evidence-review@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| evidence-review | Is this really needed? · fact-check · verify this · check if it's right · unnecessary change | Turns claims into conclusion-free open questions for the verifier, then fixes · reverts · marks `미확인` (unverified) per the verdict. Re-verification capped at 2 |
| /evidence-validate | Manual | Finds test-weakening signals (`E-20`) in changes against the default branch and in untracked files. With `--strict`, exits 2 when there are signals |

## Agents

| Agent | Description |
|---|---|
| evidence-reviewer | Receives only the original request · changed files · questions. For each change, gives necessity (`필요함` needed · `불필요함` unneeded · `판정 불가` undecidable) and correctness (`맞음` correct · `틀림` wrong · `판정 불가` undecidable), evidence first, then verdict. Does not modify code; runs pre-change behavior in a temporary worktree |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| evidence-validate.sh | UserPromptSubmit | Records the original request. This is the baseline the gate hands to the verifier |
| evidence-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | Records changed files · line counts, and **flags** `E-20` signals for test files |
| evidence-validate.sh | PostToolUse (Agent\|Task) | Marks verified when `evidence-reviewer` finishes synchronously, or verifying when it launches in the background |
| evidence-validate.sh | SubagentStop | Marks verified when a background `evidence-reviewer` finishes |
| evidence-validate.sh | Stop | If code · config was changed without verification, turns the stop back once (`E-30`). The message includes changed files · the request record · claim candidates from the final answer. Does not block while a background `evidence-reviewer` is verifying |

## Notes

- **Do not pass the author's reasons · summary · commit message to the verifier.** Adding "ignore this" still pulls the verdict.
- The verifier runs on `sonnet`. A model different from the author reduces self-preference bias.
- The verifier runs tests · scripts. It needs permission to run project commands, or verdicts fall to `판정 불가` (undecidable).
- `불필요함` (unneeded) means "it does not correspond to any sentence of the request, and reverting it breaks nothing". If the user may have wanted the change, the skill asks before reverting.
- Completion gate
  - Runs only when a request changed 3 or more lines of code · config inside the project. Change with `EVIDENCE_REVIEW_MIN_LINES`.
  - Docs (`.md` etc.) are not counted — that is `common-document-slop-review`'s job. Config such as `requirements.txt` · `CMakeLists.txt` is counted.
  - Files changed via Bash are invisible to the hook.
  - Does not block twice in one request. But editing again after verification re-judges on that edit. Disable with `EVIDENCE_REVIEW_GATE=0`
- `E-20` is a notice. It does not block, since the test may have been changed on purpose.
- The script uses bash · jq · grep, and git for `--diff`. Without jq the hook passes silently.

## Rule summary

| Clause | Content | Verdict |
|---|---|---|
| `E-01` ~ `E-03` | Verify in another context · do not pass the conclusion · claims become open questions | AI (skill) |
| `E-04` ~ `E-09` | Evidence first · necessity · correctness · bugs by reproduction · inspect the tests themselves · no invented findings | AI (agent) |
| `E-10` | The verifier does not change the working tree | AI (agent) |
| `E-11` | Wrong → fix · unneeded → revert · undecidable → `미확인` · re-verify up to 2 times | AI (skill) |
| `E-20` | Increase of skip · focus markers · decrease of assertions in test files | Notice |
| `E-30` | A request that changed code · config and ends without verification is turned back once | Gate |

Source: [`references/evidence-rules.md`](references/evidence-rules.md) · Evidence: [`references/evidence-methods.md`](references/evidence-methods.md)

## Usage

```bash
scripts/evidence-validate.sh --diff            # test-weakening signals against the default branch
scripts/evidence-validate.sh --diff --strict   # exit 2 if there are signals (CI)
test/evidence-validate.test.sh                 # regression tests
```

## Evidence

| Clause | Evidence |
|---|---|
| Self-verification is invalid | Huang et al. ICLR 2024 · Kamoi et al. TACL 2024 · Self-Correction Bench |
| Do not pass the conclusion | Anchoring CIKM 2026 · contextual bias in security code review · Chain-of-Verification · sycophancy |
| Evidence first · undecidable | CRITIC · Wang et al. ACL 2024 · Anthropic evals |
| Separate necessity | Over-editing EMNLP 2026 · "Solved Issues" ICSE 2026 |
| Reproduction | SWT-Bench · Agentless · SWE-Doctor · Refute-or-Promote |
| Test weakening | ImpossibleBench · SWE-Bench+ · Anthropic long-running agent harness |
| A single verifier | Comparative studies of multi-agent debate (ICML 2024 · NeurIPS 2025) |

Sources and confirmation level for each item are in `references/evidence-methods.md`.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
