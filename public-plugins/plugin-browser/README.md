# plugin-browser

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

A terminal CLI screen to view, pick, and install plugin-search-install results — table, compact table, card, or list by width; Hangul, emoji, and ambiguous-width handling; arrow-key and Space selection or number input; menu; scope confirmation.

```
검색 테스트 커버리지  3개
──────────────────────────────────────────────────────────────────────────────
#   이름                         마켓                  설명
1   java-spring-aitest-coverage  jaemyeong-hwnag-plu⋯  Java · Spring Boot(Gr⋯
2 ✓ project-completeness         jaemyeong-hwnag-plu⋯  프로젝트가 서비스로서 ⋯

❯ [x]   java-spring-aitest-coverage  Java · Spring Boot(Gradle) 프로젝트에서 ⋯
  [ ] ✓ project-completeness         프로젝트가 서비스로서 갖출 것을 갖췄는지 재⋯
↑↓ 이동 · Space 선택 · a 전부 · n 해제 · i 반전 · Enter 설치 · q 취소
```

Lookup and install are done by [`plugin-search-install`](../plugin-search-install/README.md). This plugin only draws its results (JSON) and lets you pick.

## Installation

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install plugin-browser@jaemyeong-hwnag-plugins --scope user
```

`plugin-search-install` is installed with it as a dependency. Requires: `bash` (3.2+), `jq` (1.6+), `stty`.

To use it directly from the terminal, add an alias (the path is `installPath` from `claude plugin list --json`).

```bash
alias plugins='bash <installPath>/scripts/plugin-browser.sh'
```

## Dependencies

| Plugin | Reason |
|---|---|
| plugin-search-install | Catalog · search · related · project · install engine |

## Skills

| Skill | Trigger | Description |
|---|---|---|
| plugin-browser | let me pick in the terminal · show it as a table · plugin browser | Inside Claude, shows a fixed-width render in a code block; for interactive use, gives a command for the user's terminal |

## Notes

- **Interactive selection opens only in a real terminal** (stdin and stdout are TTYs). In Claude's Bash, pipes, and CI you get only the static screen and a `--select` hint
- For terminals that draw ambiguous-width characters (`·` `─` `…`) as two cells (East Asian width setting), it asks the cursor position at startup to detect this. If the terminal does not answer, it waits 1 second and assumes one cell — pin it with `PLUGIN_BROWSER_AMBIGUOUS=1|2`
- Window resizes are redrawn within 1 second (periodic check instead of `SIGWINCH` — bash 3.2 `read` is not woken by signals)
- If the terminal is narrower than 10 columns, it does not draw and prints a notice
- Emoji width follows Unicode 15.1 (characters with VS16 are two cells). Old terminals and fonts may draw some emoji as one cell, so lines can come out short (they never overflow)
- Install scope defaults to `project`. Scope is asked after the selection screen

## Usage

```bash
P=scripts/plugin-browser.sh
$P                                   # menu
$P project                           # what this project needs
$P search naming has:hook -java      # query syntax is the same as plugin-search-install
$P related java-naming --by name
$P installed
$P show github-workflow
$P facets                             # domain · technology · tags (descriptions) · components · installed · keywords
$P search 커버리지 --width 60 --no-pick           # draw only, fixed width
$P search 커버리지 --select 1,3 --scope user --dry-run   # install plan without prompting
plugin-search-install.sh search x | $P render -   # only draw engine JSON
```

| Option | Meaning |
|---|---|
| `--width N` | Fixed width, 10 or more (default: terminal → `$COLUMNS` → 80) |
| `--ascii` | ASCII decorations (automatic for non-UTF-8 locales) |
| `--color auto\|always\|never` | Default auto — when TTY, `NO_COLOR` is unset, and `TERM` is not `dumb` |
| `--plain` | Number input instead of arrow-key selection |
| `--no-pick` | Draw only |
| `--select` · `--install-all` · `--scope` · `--dry-run` | Install without prompting |

## Layout by width

| Width | Layout |
|---|---|
| 120+ | Table — # · mark · name · marketplace · tags · reason · description |
| 100 – 119 | Table — # · mark · name · marketplace · description |
| 70 – 99 | One line — # · mark · name · description |
| 40 – 69 | Card — name / marketplace · tags / 2-line description / reason |
| under 40 | List — name / 1-line description (24+) |

Marks: `✓` installed · `!` required but missing · `-` disabled (ASCII: `*` `!` `-`). Every line fits within width − 1 cells (for terminals that auto-wrap when writing the last column).

## Files

| Path | Role |
|---|---|
| `scripts/plugin-browser.sh` | Menu · render · interactive selection · install confirmation |
| `references/display-width.json` | Display width table — zero-width · two-cell · ambiguous-width ranges (Unicode 15.1; Hangul syllables take the script's fast path) |
| `test/` | Regression tests and TC spec — 19 widths · pty interaction |
| `evals/` | `claude plugin eval` cases — skill trigger (`browser-request`) |

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
