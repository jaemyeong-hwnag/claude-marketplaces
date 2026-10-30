# plugin-search-install

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Finds and installs this marketplace's public plugins — what the project needs from its declarations and file signals, what is related to a plugin or a feature word, and feature search by field, tag facets, synonyms and typo tolerance. Install all, some, or just look. Works as a CLI and a local MCP server.

**Only `category: public` plugins of the marketplace this plugin was installed from are in scope.** Other marketplaces and internal plugins are never listed, recommended or installed. The marketplace name is not hard-coded, so in a forked marketplace it handles that marketplace's public plugins.

```
project   what this project needs       declarations (settings) · dependency closure · file-signal recommendations
related   what relates to this          dependencies · dependents · tags · keywords · name · components · description
search    what does this                field:value · domain: · tech: · -exclude · a|b · /regex/ · has: · is: · dep:
facets    what is there                 counts by domain · technology tag (tags.json descriptions) · keyword · component
install   install the chosen ones       all · some by number/name · exclude · look only · dry-run
```

One engine, three front ends — the CLI that skills call, a **local MCP server** Claude calls without Bash, and [`plugin-browser`](../plugin-browser/README.md), which shows tables and cards in the terminal and lets you pick with arrow keys. The logic lives only in the engine.

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install plugin-search-install@jaemyeong-hwnag-plugins --scope project
```

Requires `bash` (3.2+), `jq` (1.6+), `find` · `grep` · `awk`. Without the `claude` CLI it reads the record files in `~/.claude/plugins/` (installing needs the CLI).

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| plugin-search | find a plugin · is there a plugin that ~? · similar plugins | Turns the request into the query syntax, runs `search` · `related`, and shows results with reasons |
| plugin-project-requirement-search | what should I install for this project · missing plugins · onboarding | Splits `project` results into required (declared · dependency) and recommended (signals), with status and evidence |
| plugin-install | install it · install all · only 1 and 3 · all but this | Picks all · some · look only and the scope, then dry-run → install → restart notice |

## MCP server

Installing the plugin makes Claude Code start the `plugin-search` MCP server (`scripts/plugin-search-mcp.sh`, stdio) locally. The runtime is just `bash` · `jq`.

| Tool | What it does |
|---|---|
| `search_plugins` | Feature search — query syntax · tags · domain · technology · components · installed state |
| `list_related_plugins` | Plugins related to a plugin or feature word |
| `list_project_plugins` | What this project needs |
| `get_plugin` | Details of one plugin |
| `list_plugin_facets` | Counts per facet |
| `install_plugins` | Install — **dry-run by default**, installs only with `dry_run: false` |

To attach it without the plugin (name the marketplace):

```bash
claude mcp add plugin-search -e PLUGIN_SEARCH_MARKETPLACE=jaemyeong-hwnag-plugins -- <path>/scripts/plugin-search-mcp.sh
```

## Notes

- Since 0.3.0 the skill `project-plugin-search` is `plugin-project-requirement-search` — call it as `/plugin-search-install:plugin-project-requirement-search`
- **Install defaults to `--scope project`** — the project's `.claude/settings.json` changes. For personal tools use `--scope user`
- It stops if it cannot tell the target marketplace or that marketplace is not registered — set it with `PLUGIN_SEARCH_MARKETPLACE`
- Remote-source (github · url) plugins have unknown skills · hooks until installed (`componentsKnown: false`). They are found only by name · description · tags
- Plugins that need command-execution confirmation (command source) are not approved on your behalf with `-y`. It tells you the command to run yourself
- Installed plugins load only **after restarting Claude Code** (`restartRequired`)
- The catalog cache lasts 10 minutes. If an updated marketplace does not show up, use `--refresh`
- Project recommendations look only at file traces. A `pom.xml` in an example directory also counts as a Java signal — the skill filters by `evidence`

## Usage

```bash
S=scripts/plugin-search-install.sh
$S search 테스트 커버리지                         # feature search (synonyms · particles · typo tolerance)
$S search naming has:hook -java --format tsv      # fields · exclusion · table
$S search tech:spring is:not-installed --sort installs
$S search --domain development --has hook
$S related java-naming --by name,tag              # related — pick relations
$S related 문서 동기화                             # related by feature word
$S project . --only missing                       # declared but not installed
$S facets                                         # counts by domain · technology · keyword · component
$S search 커버리지 > /tmp/l.json && $S install --from /tmp/l.json --select 1,2 --dry-run
$S install github-workflow --scope user
```

## Files

| Path | Role |
|---|---|
| `references/search-rules.md` | Rule source — catalog origin, query syntax, scoring, related · project · install rules, output fields |
| `references/search-synonyms.json` | Synonym groups (Korean · English) · stop words |
| `references/project-signals.json` | 33 file signals — path · content patterns, search words, weights, language exclusivity |
| `scripts/plugin-search-install.sh` | `catalog` · `search` · `related` · `project` · `detect` · `show` · `facets` · `install` |
| `scripts/plugin-search-mcp.sh` | Local MCP server (stdio) — the engine as 6 tools |
| `test/` | Regression tests and TC specs — engine (stub claude · fake marketplace), MCP (JSON-RPC exchange) |
| `evals/` | `claude plugin eval` cases — feature-search skill trigger (`search-request`) |

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
