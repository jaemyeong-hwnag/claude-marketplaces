# claude-marketplaces

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

A Claude Code plugin marketplace. The marketplace name is `jaemyeong-hwnag-plugins`.

- **If you want to use plugins** — [Getting started](#getting-started) · [Finding plugins](#finding-plugins) · [Installing what a project needs](#installing-what-a-project-needs) · [Plugins](#plugins)
- **If you contribute to this repository** — [Working in this repository](#working-in-this-repository)

## Getting started

Requirements: Claude Code, `bash`, `jq`.

**1. Add the marketplace** (once per machine)

Inside a Claude Code session:

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
```

**2. Install the search · install plugin**

```
/plugin install plugin-search-install@jaemyeong-hwnag-plugins
```

You will be asked for an install scope — `project` so the whole team gets the same setup, `user` for yourself only. This plugin finds and installs the other plugins (it includes the local MCP server `plugin-search`).

**3. Restart Claude Code**

Plugins and MCP servers are loaded when a session starts. You are done when `plugin-search` shows up in `/mcp`.

> From a terminal, do the same with `claude plugin marketplace add …` · `claude plugin install … --scope project`.

## Finding plugins

Searches cover **this marketplace's public plugins** ([Plugins](#plugins)).

### Ask Claude

| You want to | Say |
|---|---|
| Find by feature | "Is there a plugin that raises test coverage?" |
| Find related ones | "Show plugins similar to or used with github-workflow" |
| Browse what exists | "Show me the plugins grouped by tag" |
| Look at one plugin | "What skills and hooks does java-naming have?" |

Claude searches with the `plugin-search` MCP tool (or the `plugin-search` skill) and shows results with reasons.

### Query syntax (for precise searches)

| Form | Meaning | Example |
|---|---|---|
| `word` | Anywhere in name · description · tags · keywords · skills · hooks · MCP | `naming` |
| `field:value` | Only in that field | `tag:spring` · `tech:spring` · `domain:development` · `skill:issue-create` |
| `-word` | Exclude | `naming -java` |
| `a\|b` | Either | `github\|gitlab` |
| `has:kind` | Has that component | `has:hook` · `has:mcp` |
| `is:state` | Install state | `is:not-installed` |

Synonyms (Korean · English), Korean particles, and typos are tolerated — "네이밍" also finds `naming`. Full syntax: [`search-rules.md`](public-plugins/plugin-search-install/references/search-rules.md).

### In a terminal UI

To browse tables · cards and pick with arrow keys and space, install [`plugin-browser`](public-plugins/plugin-browser).

```
/plugin install plugin-browser@jaemyeong-hwnag-plugins
```

From a terminal (outside Claude):

```bash
PB="$(claude plugin list --json | jq -r '[.[] | select(.id=="plugin-browser@jaemyeong-hwnag-plugins")][0].installPath')/scripts/plugin-browser.sh"
bash "$PB"                        # menu — project · feature search · related · tags · installed
bash "$PB" search test coverage
```

## Installing what a project needs

In the project folder, tell Claude:

```
Install the plugins this project needs
```

1. It searches three ways and shows the reasons
   - **Required** — declared in the project's `.claude/settings.json` but not installed, plus the plugins they depend on
   - **Recommended** — picked from file signals (e.g. `build.gradle` + Spring → `java-spring-*`, `.github/` → `github-workflow`)
2. It shows the install plan first — **it does not install right away**
3. Choose "all" · "only 1 and 3" · "skip recommended" · "just list" and it installs accordingly (default scope `project`)
4. Restart Claude Code to load them

### From the CLI (scripts · CI)

```bash
PSI="$(claude plugin list --json | jq -r '[.[] | select(.id=="plugin-search-install@jaemyeong-hwnag-plugins")][0].installPath')/scripts/plugin-search-install.sh"

"$PSI" project . --format tsv                          # what is needed (required + recommended, with reasons)
"$PSI" project . --only declared > /tmp/need.json      # required (declared · dependencies) only
"$PSI" install --from /tmp/need.json --all --dry-run   # plan — skips what is already installed
"$PSI" install --from /tmp/need.json --all             # install
"$PSI" project . > /tmp/all.json && "$PSI" install --from /tmp/all.json --select 1,3-5   # pick by number
```

### Giving the whole team the same plugins

Write the marketplace and plugins into the project's `.claude/settings.json` and commit it. Teammates add the marketplace and then say "Install the plugins this project needs" once — everything listed here counts as **required**.

```json
{
  "extraKnownMarketplaces": {
    "jaemyeong-hwnag-plugins": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": {
    "plugin-search-install@jaemyeong-hwnag-plugins": true,
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
| `plugin-search` is missing from `/mcp` | Restart Claude Code. If it is still missing, check `Error:` in `claude plugin list` |
| A tool says "jq is required" | `brew install jq` (macOS) · `apt install jq` |
| Installed as `…@plugin-marketplace` | That is the old marketplace name — run `claude plugin marketplace remove plugin-marketplace`, then start from step 1 |
| A plugin you look for does not show up | Only this marketplace's **public** plugins are searched. Other marketplaces and internal plugins are not |

## Plugins

Install: `/plugin install <name>@jaemyeong-hwnag-plugins`. Every plugin has a README in English, Korean, and Chinese.

| Area | Plugin | What it does |
|---|---|---|
| Finding · installing plugins | [`plugin-search-install`](public-plugins/plugin-search-install) | Search, related plugins, what a project needs, and install for this marketplace's public plugins. Includes a local MCP server |
| | [`plugin-browser`](public-plugins/plugin-browser) | The same results in a terminal UI (tables · cards · arrow-key selection) |
| Code naming | [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming) | Hooks block name shapes that break each language's official guide; skills judge word choice |
| Testing | [`java-spring-aitest-coverage`](public-plugins/java-spring-aitest-coverage) · [`kotlin-spring-aitest-coverage`](public-plugins/kotlin-spring-aitest-coverage) | Cover changed Java · Kotlin Spring Boot methods with `@AiTest` behind a JaCoCo 100% gate |
| Code-edit guardrail | [`code-edit-guardrail`](public-plugins/code-edit-guardrail) | Blocks completion when code changes without test changes or when lint · format checks on the changed paths fail; asks before editing shared resources. Language-agnostic |
| Verification · review | [`common-evidence-review`](public-plugins/common-evidence-review) | A verifier with no authoring context judges, from execution evidence, whether a change is needed and whether claims are true |
| | [`common-design-soundness-review`](public-plugins/common-design-soundness-review) | A verifier with no authoring context judges whether a design (structure · flow · decisions) holds together before implementation |
| | [`common-performance-review`](public-plugins/common-performance-review) | Reviews the performance of a change across 9 categories (complexity · queries · IO · concurrency · caching …) and flags 19 patterns such as queries or `await` in loops while writing. Language-agnostic |
| Security | [`git-secret-validate`](public-plugins/git-secret-validate) | Blocks keys · tokens · passwords and `.env` · key files before `git commit` · `git push`, and warns when writing them to files that are not ignored. Detection by gitleaks (built-in patterns if absent) |
| Load · performance | [`common-stress-test`](public-plugins/common-stress-test) | Designs and judges load tests quantitatively (blocks production hosts · sustainable capacity · regression statistics). Language-agnostic |
| | [`java-spring`](public-plugins/java-spring-stress-test) · [`python-fastapi`](public-plugins/python-fastapi-stress-test) · [`python-django`](public-plugins/python-django-stress-test) · [`node-express`](public-plugins/node-express-stress-test) · [`typescript-nestjs`](public-plugins/typescript-nestjs-stress-test) · [`go-gin`](public-plugins/go-gin-stress-test) `-stress-test` | Per-framework server instrumentation, detection of settings that invalidate measurements, microbenchmarks |
| Project quality | [`project-completeness`](public-plugins/project-completeness) | Diagnoses whether a project has what a service needs, applies fixes, and judges operational metrics |
| Documentation | [`domain-document-sync`](public-plugins/domain-document-sync) | Keeps domain knowledge docs in three layers and in sync with code changes |
| | [`common-document-slop-review`](public-plugins/common-document-slop-review) | Blocks slop (chat leftovers · broken links · unsupported claims) whenever docs are written or edited, and requires a fact-check review |
| Finding references | [`reference-search`](public-plugins/reference-search) | Finds papers, other companies' engineering cases, official docs, and standards with per-source agents, and blocks citing DOIs · arXiv IDs that do not exist |
| GitHub flow | [`github-workflow`](public-plugins/github-workflow) | Enforces issue → issue-numbered branch → PR → merge commit → tag |

Internal plugins used only to develop this repository — [`plugin-naming`](internal-plugins/plugin-naming) · [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) · [`plugin-versioning`](internal-plugins/plugin-versioning) · [`plugin-authoring`](internal-plugins/plugin-authoring) · [`plugin-dependency`](internal-plugins/plugin-dependency) · [`plugin-enforcement-effectiveness`](internal-plugins/plugin-enforcement-effectiveness) · [`plugin-workflow`](internal-plugins/plugin-workflow).

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
- Merge commits only. Tag and release with the `plugin-release-create` skill after merging and checking the install on main
- Use the `plugin-create` skill to create a plugin, `plugin-name-update` to rename one, and `plugin-delete` to remove one

### Who owns what

Each concern has exactly one owner. `Write` · `Edit` · `Bash` hooks block or notify according to the rules.

| Concern | Plugin | Rule source |
|---|---|---|
| Names | `plugin-naming` | [`naming-rules.md`](internal-plugins/plugin-naming/references/naming-rules.md) · [`glossary.json`](internal-plugins/plugin-naming/references/glossary.json) |
| File locations | `marketplace-directory-structure` | [`directory-structure-rules.md`](internal-plugins/marketplace-directory-structure/references/directory-structure-rules.md) |
| Versions · CHANGELOG | `plugin-versioning` | [`versioning-rules.md`](internal-plugins/plugin-versioning/references/versioning-rules.md) |
| File content format (frontmatter · three-language READMEs) | `plugin-authoring` | [`authoring-rules.md`](internal-plugins/plugin-authoring/references/authoring-rules.md) |
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

Every plugin and this repository keep `README.md` (English, default) · `README.ko.md` · `README.zh-CN.md` with the same content. `verify-all.sh` blocks if one is missing, if a component table does not match reality, or if a public plugin is missing from the root READMEs (`P-01` · `A-20` ~ `A-30`).

## License

[MIT](LICENSE)
