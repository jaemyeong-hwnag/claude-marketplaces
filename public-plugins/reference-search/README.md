# reference-search

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Searches papers, research results (any field), other companies' technical case studies, official documentation and standards in parallel, split across per-source agents — picks the sources and agent count that fit the request, pulls real metadata from keyless academic APIs, then merges and verifies. Blocks DOIs and arXiv IDs newly written into documents that do not actually exist.

| Layer | What | Does |
|---|---|---|
| 1. Search | 3 skills · 10 per-source agents | Picks only the agents the request depth needs, launches them at once, and merges results by identifier |
| 2. Verify | `reference-reviewer` | Receives only the result table, without authoring context, and judges existence and support per item |
| 3. Block | PreToolUse hook | Blocks DOIs and arXiv IDs newly written into `.md` files that are not registered |

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install reference-search@jaemyeong-hwnag-plugins
```

## Dependencies

None

## Skills

| Skill | Trigger | Description |
|---|---|---|
| paper-search | find papers · prior work · related work · latest research · any evidence? · paper · literature | Picks among academic index, preprint, discipline DB, regional DB and research trend agents. Surveys first; snowballing when deep |
| company-case-search | how do other companies · find case studies · tech blog · adoption case · outage case | Picks among company blog, conference talk and postmortem agents. States company, date and scale |
| technology-usage-search | official docs · spec · standard · RFC · how it is actually used | Picks among official document/standard and code/issue/design document agents. States document version and deprecation status |
| /reference-validate | Direct call | Checks a file's DOIs and arXiv IDs for existence and retraction, and URL status (`RS-01` ~ `RS-06`) |

In 0.2.0, `/reference-search:company-reference-search` became `company-case-search` and `/reference-search:technical-document-search` became `technology-usage-search`.

## Agents

| Agent | Description |
|---|---|
| academic-index-searcher | Cross-discipline academic indexes (OpenAlex · Semantic Scholar · Crossref · Google Scholar, etc.). Handles snowballing |
| preprint-searcher | Preprints on arXiv · bioRxiv · medRxiv · SSRN · OSF, etc. Checks whether a published version exists |
| discipline-database-searcher | Whichever of the medicine · CS · psychology · economics · education · humanities · law · engineering · chemistry · physics · patent · thesis DBs fits the question's field |
| regional-academic-database-searcher | Korea first (RISS · KCI · DBpia · ScienceON, etc.), then Japan · China · Europe · Latin America DBs, in each country's language |
| research-trend-searcher | Trending papers and evidence of attention from Hugging Face Papers · alphaXiv · conference Best Papers · newsletters · Hacker News |
| company-blog-searcher | Domestic and international company tech blogs · architecture case studies · industry papers · tech radars |
| conference-talk-searcher | Domestic and international conference talk videos · slides |
| postmortem-searcher | Outage postmortems · incident reports · outage retrospectives |
| official-document-searcher | Official docs · release notes · RFC · W3C · ISO · NIST · OWASP |
| code-usage-searcher | GitHub code · issues · PRs, KEP · PEP · Rust RFC · ADR |
| reference-reviewer | Receives only the merged result table and judges, per item, existence (`확인` confirmed · `불일치` mismatch · `없음` missing · `철회` retracted · `미확인` unverified) and support (`지지` supports · `부분` partial · `아님` does not). Does not modify results |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| reference-validate.sh | PreToolUse (Write\|Edit\|MultiEdit) | Looks up DOIs and arXiv IDs newly appearing in `.md`; **blocks** if missing (`RS-01` · `RS-02`), notifies if retracted (`RS-03`), passes with a notice if it cannot check (`RS-04`) |

## Depth and agent count

Depth is set by request complexity; a user-specified value takes precedence.

| Depth | Agents | Tool calls per agent | Snowballing · verification |
|---|---|---|---|
| Quick | 0 ~ 1 | 3 ~ 10 | Script check only |
| Normal | 2 ~ 4 | 10 ~ 15 | `reference-reviewer` |
| Deep | 5 ~ 10 | 10 ~ 15 | One snowballing round + `reference-reviewer` |

- If the request says "quick" · "deep" · "N agents" · "arXiv only" · "Korea only" · "except ~", that is followed as is
- Defaults can be set via environment variables: `REFERENCE_SEARCH_DEPTH=quick|normal|deep`, `REFERENCE_SEARCH_MAX_AGENTS=<N>`
- If there are more groups than the cap, catalogs are added onto the nearest agent — no source is dropped

## Sources and keys

`scripts/reference-search.sh` calls these without keys: `openalex` · `openalex-citing` · `openalex-references` · `semantic-scholar` · `crossref` · `arxiv` · `biorxiv` · `medrxiv` · `pubmed` · `europepmc` · `openreview` · `huggingface` · `huggingface-daily` · `hackernews` · `rfc` · `github-repository` · `github-code` · `github-issue`.

- Sources that need a key (KCI · RISS · ScienceON · NTIS · CORE · Unpaywall · IEEE · Springer · Scopus) are not included. They are left as TODOs in the script; agents find them with WebSearch `site:`
- Semantic Scholar and arXiv often hit the rate limit (429) when called without a key (both returned 429 during development in 2026-10). The script waits once, retries, then reports exit code 6 and a fallback source (OpenAlex)
- `github-*` needs `gh` authentication; `arxiv` needs `xmllint`

## Notes

- The hook only looks at **newly added** identifiers (ones in neither the current file nor `old_string`). It does not re-check everything on every edit of an existing document
- The hook does not look at URLs. URLs are checked only by `/reference-validate`
- Identifiers inside inline code and code fences are treated as examples and not checked
- It does not block when there is no network or a rate limit is hit. To turn it off: `REFERENCE_VALIDATE=off`
- Identifiers confirmed to exist are cached in `${CLAUDE_PLUGIN_DATA}`. Ones found missing are not cached
- Agents and skills read catalogs and scripts via `${CLAUDE_PLUGIN_ROOT}` paths

## Rule summary

| Clause | Content | Verdict |
|---|---|---|
| `RS-01` · `RS-02` | A newly written DOI or arXiv ID is not registered | Block |
| `RS-03` | Retracted paper | Notify |
| `RS-04` | Could not check (network · rate limit · cap) | Pass + notify |
| `RS-05` · `RS-06` | URL 404 · access restricted (`/reference-validate --urls`) | Fail · warn |
| `RS-10` ~ `RS-20` | Tool results only · identifier · status · path · search record · summary only from what was opened · merge · weight · retraction marking · company material date · passed verification · depth · instruction fields (in clause order) | AI judgment |

Source: [`references/reference-search-rules.md`](references/reference-search-rules.md) · Procedure: [`references/search-orchestration.md`](references/search-orchestration.md) · Format: [`references/result-schema.md`](references/result-schema.md) · Rationale: [`references/reference-search-methods.md`](references/reference-search-methods.md) · Source catalogs: [`references/sources/`](references/sources/)

## Usage

```bash
scripts/reference-search.sh openalex "agent memory" --from 2024-10-26 --limit 8
scripts/reference-search.sh openalex-citing 10.48550/arXiv.2005.11401
scripts/reference-validate.sh --urls docs/research.md
test/reference-validate.test.sh && test/reference-search.test.sh
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
