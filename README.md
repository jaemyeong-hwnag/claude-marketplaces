# claude-marketplaces

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Claude Code plugins that enforce rules with hooks instead of instructions the model can skip. They turn Claude back from finishing when code changed without tests or lint fails, hand AI changes to a verifier that never sees the author's conclusion, block load tests aimed at production hosts, stop secrets from being committed, and enforce naming conventions for Java, Kotlin, TypeScript, Node.js, Python and Go. For people and teams who want these rules applied in every Claude Code session. The completion (`Stop`) gates turn the stop back once per request, so they do not replace human review.

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install code-edit-guardrail@jaemyeong-hwnag-plugins
```

The marketplace name is `jaemyeong-hwnag-plugins`.

- **If you want to use plugins** — [Getting started](#getting-started) · [Plugins](#plugins) · [FAQ](#faq)
- **If you contribute to this repository** — [Working in this repository](#working-in-this-repository)

## Getting started

Requirements: Claude Code, `bash`, `jq`.

**1. Add the marketplace** (once per machine)

Inside a Claude Code session:

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
```

**2. Install plugins**

Pick a name from the [Plugins](#plugins) table and install it. You can also open `/plugin` and pick from the list.

```
/plugin install <name>@jaemyeong-hwnag-plugins
```

You will be asked for an install scope — `project` so the whole team gets the same setup, `user` for yourself only.

**3. Restart Claude Code**

Hooks, skills and MCP servers are loaded when a session starts.

> In a terminal, do the same with `claude plugin marketplace add …` · `claude plugin install … --scope project`.

### Giving the whole team the same plugins

Write the marketplace and plugins into the project's `.claude/settings.json` and commit it. When teammates trust the folder, the marketplace is registered and the plugins in `enabledPlugins` are enabled.

```json
{
  "extraKnownMarketplaces": {
    "jaemyeong-hwnag-plugins": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": {
    "<name>@jaemyeong-hwnag-plugins": true
  }
}
```

### Updates · troubleshooting

```
/plugin marketplace update jaemyeong-hwnag-plugins     # get new plugins · new versions
```

| Symptom | Fix |
|---|---|
| A hook does nothing or errors | Check the errors in `claude plugin list`. Hook scripts need `jq` — `brew install jq` (macOS) · `apt install jq` |
| Installed as `…@plugin-marketplace` | That is the old marketplace name — run `claude plugin marketplace remove plugin-marketplace`, then start from step 1 |

## Plugins

Install: `/plugin install <name>@jaemyeong-hwnag-plugins`. Every public plugin has a README in English, Korean, and Chinese.

| Area | Plugin | What it does |
|---|---|---|
| Code-edit guardrail | [`code-edit-guardrail`](public-plugins/code-edit-guardrail) | Blocks completion when code changes without test changes or when lint · format checks on the changed paths fail; asks before editing shared resources. Language-agnostic |
| Verification · review | [`common-evidence-review`](public-plugins/common-evidence-review) | A verifier with no authoring context judges, from execution evidence, whether a change is needed and whether claims are true |
| | [`common-design-soundness-review`](public-plugins/common-design-soundness-review) | A verifier with no authoring context judges whether a design (structure · flow · decisions) holds together before implementation |
| | [`common-performance-review`](public-plugins/common-performance-review) | Reviews the performance of a change across 9 categories (complexity · queries · IO · concurrency · caching …) and flags 19 patterns such as queries or `await` in loops while writing. Language-agnostic |
| Load · performance | [`common-stress-test`](public-plugins/common-stress-test) | Designs and judges load tests quantitatively (blocks production hosts · sustainable capacity · regression statistics). Language-agnostic |
| | [`java-spring`](public-plugins/java-spring-stress-test) · [`python-fastapi`](public-plugins/python-fastapi-stress-test) · [`python-django`](public-plugins/python-django-stress-test) · [`node-express`](public-plugins/node-express-stress-test) · [`typescript-nestjs`](public-plugins/typescript-nestjs-stress-test) · [`go-gin`](public-plugins/go-gin-stress-test) `-stress-test` | Per-framework server instrumentation, detection of settings that invalidate measurements, microbenchmarks |
| Security | [`git-secret-validate`](public-plugins/git-secret-validate) | Blocks keys · tokens · passwords and `.env` · key files before `git commit` · `git push`, and warns when writing them to files that are not ignored. Detection by gitleaks (built-in patterns if absent) |
| Testing | [`java-spring-aitest-coverage`](public-plugins/java-spring-aitest-coverage) · [`kotlin-spring-aitest-coverage`](public-plugins/kotlin-spring-aitest-coverage) | Cover changed Java · Kotlin Spring Boot methods with `@AiTest` behind a JaCoCo 100% gate |
| Code naming | [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming) | Hooks block name shapes that break each language's official guide; skills judge word choice |
| Documentation | [`domain-document-sync`](public-plugins/domain-document-sync) | Keeps domain knowledge docs in three layers and in sync with code changes |
| | [`common-document-slop-review`](public-plugins/common-document-slop-review) | Blocks slop (chat leftovers · broken links · unsupported claims) whenever docs are written or edited, and requires a fact-check review |
| Finding references | [`reference-search`](public-plugins/reference-search) | Finds papers, other companies' engineering cases, official docs, and standards with per-source agents, and blocks citing DOIs · arXiv IDs that do not exist |
| GitHub flow | [`github-workflow`](public-plugins/github-workflow) | Enforces issue → issue-numbered branch → PR → merge commit → tag |

Internal plugins used only to develop this repository — [`plugin-naming`](internal-plugins/plugin-naming) · [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) · [`plugin-versioning`](internal-plugins/plugin-versioning) · [`plugin-authoring`](internal-plugins/plugin-authoring) · [`plugin-dependency`](internal-plugins/plugin-dependency) · [`plugin-enforcement-effectiveness`](internal-plugins/plugin-enforcement-effectiveness) · [`plugin-workflow`](internal-plugins/plugin-workflow).

## FAQ

### How do I stop Claude Code from finishing without writing tests?

Install [`code-edit-guardrail`](public-plugins/code-edit-guardrail) and say "set up the guardrail". Its `Stop` hook turns completion back once when code changed in a request but no test file did, or when the lint · format · type-check command for the edited paths fails. A behavior-preserving change passes once Claude writes a reason to the exemption file — the hook does not check that the user agreed.

### How do I get Claude Code's changes checked by something other than Claude itself?

[`common-evidence-review`](public-plugins/common-evidence-review) sends the original request, the changed files and conclusion-free questions to a separate verifier agent, which judges each change from execution evidence. If a request changed 3 or more lines of code or config and ends without that review, the stop is turned back once. The gate checks only that the verifier was called, not that its verdict was followed.

### How do I keep Claude Code from committing API keys or `.env` files?

[`git-secret-validate`](public-plugins/git-secret-validate) blocks `git commit` · `git push` when the change carries secrets or sensitive files, using gitleaks or built-in patterns when gitleaks is absent. Commands wrapped in `bash -c` · `sh -c` · `eval` are checked too.

### Can Claude Code run load tests without hitting production?

[`common-stress-test`](public-plugins/common-stress-test) blocks load commands (k6 · Gatling · Locust · JMeter · wrk · hey · bombardier · siege and more) whose target host is outside an allowlist (loopback, private IPs, `*.local` · `*.test` · `*.internal`, and hosts you add). It cannot see indirect runs through `make` · `npm run` or commands · targets built from variables.

### How do I make Claude Code follow my language's naming conventions?

Install the plugin for your language — [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming). Hooks block only violations that a new edit introduces, so existing code does not stop you.

### Why hooks instead of `CLAUDE.md` instructions?

Claude Code runs hooks itself, outside the model. An instruction can be skipped; a `PreToolUse` hook can refuse a tool call and a `Stop` hook can refuse to end the turn. The `Stop` gates here turn the stop back only once per request, though — the model can pass on its second attempt.

## Working in this repository

The full working rules are in [`CLAUDE.md`](CLAUDE.md) (Korean) — Claude Code reads it every session, and it reads the same for people. The rule sources in the table below hold the details.

| Path | Kind | Distribution |
|---|---|---|
| [`public-plugins/`](public-plugins) | Distributed plugins | GitHub marketplace — other repositories get them once merged |
| [`internal-plugins/`](internal-plugins) | Plugins used only by this repository | Not distributed — a hook registers and installs them at session start |

### Development flow

```
issue → worktree · branch → work → version → verify · test → rebase and re-verify → PR
→ merge → install check on main → tag · release → clean up
```

- Issue, branch, PR, and commit types are only `feature` / `bugfix`. Issue forms and PR templates live in [`.github/`](.github)
- Bump the version of every plugin whose files changed — CHANGELOG first, then `plugin.json`
- Merge commits only. Tag and release public plugins with the `plugin-release-create` skill after merging and checking the install on main. Internal plugins are not distributed, so they get no tags or releases
- Use the `plugin-create` skill to create a plugin, `plugin-name-update` to rename one, and `plugin-delete` to remove one

### Who owns what

Each concern has exactly one owner. `Write` · `Edit` · `Bash` hooks block or notify according to the rules.

| Concern | Plugin | Rule source |
|---|---|---|
| Names | `plugin-naming` | [`naming-rules.md`](internal-plugins/plugin-naming/references/naming-rules.md) · [`glossary.json`](internal-plugins/plugin-naming/references/glossary.json) |
| File locations | `marketplace-directory-structure` | [`directory-structure-rules.md`](internal-plugins/marketplace-directory-structure/references/directory-structure-rules.md) |
| Versions · CHANGELOG | `plugin-versioning` | [`versioning-rules.md`](internal-plugins/plugin-versioning/references/versioning-rules.md) |
| File content format (frontmatter · READMEs) | `plugin-authoring` | [`authoring-rules.md`](internal-plugins/plugin-authoring/references/authoring-rules.md) |
| Dependencies between plugins | `plugin-dependency` | [`dependency-rules.md`](internal-plugins/plugin-dependency/references/dependency-rules.md) |
| Whether written enforcement actually takes effect at runtime | `plugin-enforcement-effectiveness` | [`enforcement-effectiveness-rules.md`](internal-plugins/plugin-enforcement-effectiveness/references/enforcement-effectiveness-rules.md) |
| Issue → branch → PR → merge | `github-workflow` | [`workflow-rules.md`](public-plugins/github-workflow/references/workflow-rules.md) |
| Install check · tag · release; create · rename · delete procedures | `plugin-workflow` | [`workflow-rules.md`](internal-plugins/plugin-workflow/references/workflow-rules.md) |
| Placement · marketplace registration · install sync | Repository [`.claude/hooks/`](.claude/hooks) | [`test/README.md`](test/README.md) |

### Verification

Run before a PR, and again after rebasing onto `origin/main`.

```bash
internal-plugins/plugin-workflow/scripts/verify-all.sh .        # all validators · regression tests · claude plugin validate --strict
internal-plugins/plugin-workflow/scripts/eval-all.sh --quick .  # skill-trigger · hook-block evals (calls the model, never publishes)
```

### READMEs in three languages

Every public plugin and this repository keep `README.md` (English, default) · `README.ko.md` · `README.zh-CN.md` with the same content. Internal plugins keep only `README.ko.md`. `verify-all.sh` blocks if one is missing, if a component table does not match reality, or if a public plugin is missing from the root READMEs (`P-01` · `A-20` ~ `A-30`).

## License

[MIT](LICENSE)
