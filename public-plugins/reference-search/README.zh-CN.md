# reference-search

[English](README.md) · [한국어](README.ko.md) · **简体中文**

将论文、研究成果（不限领域）、其他公司的技术案例、官方文档和标准按来源拆分给各个代理并行查找 — 按请求选择来源和代理数量，从无需密钥的学术 API 获取真实元数据，再合并和验证。文档中新写入的 DOI · arXiv ID 若实际不存在则阻止。

| 层 | 内容 | 作用 |
|---|---|---|
| 1. 搜索 | 3 个技能 · 10 个按来源划分的代理 | 只选出请求深度所需的代理一次性启动，并按标识符合并结果 |
| 2. 验证 | `reference-reviewer` | 在没有撰写上下文的情况下只接收结果表，逐项判定存在与支持 |
| 3. 阻止 | PreToolUse 钩子 | 阻止在 `.md` 中新写入的未注册 DOI · arXiv ID |

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install reference-search@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发词 | 说明 |
|---|---|---|
| paper-search | 找论文 · 前人研究 · 相关研究 · 最新研究 · 有依据吗 · paper · literature | 从学术索引 · 预印本 · 学科数据库 · 国家数据库 · 研究动态代理中选择查找。先找综述，深度模式下做滚雪球 |
| company-case-search | 其他公司怎么做 · 找案例 · 技术博客 · 落地案例 · 故障案例 | 从企业博客 · 演讲 · 故障案例代理中选择查找。注明公司 · 日期 · 规模 |
| technology-usage-search | 官方文档 · 规范 · 标准 · RFC · 实际怎么用 | 从官方文档 · 标准与代码 · issue · 设计文档代理中选择查找。注明文档版本 · 是否废弃 |
| /reference-validate | 直接调用 | 检查文件中 DOI · arXiv ID 是否存在 · 是否撤稿，以及 URL 状态 (`RS-01` ~ `RS-06`) |

0.2.0 中，`/reference-search:company-reference-search` 改为 `company-case-search`，`/reference-search:technical-document-search` 改为 `technology-usage-search`。

## 代理

| 代理 | 说明 |
|---|---|
| academic-index-searcher | 全领域学术索引（OpenAlex · Semantic Scholar · Crossref · Google Scholar 等）。负责滚雪球 |
| preprint-searcher | arXiv · bioRxiv · medRxiv · SSRN · OSF 等预印本。确认是否已有正式出版版本 |
| discipline-database-searcher | 医学 · CS · 心理 · 经济 · 教育 · 人文 · 法律 · 工程 · 化学 · 物理 · 专利 · 学位论文数据库中与问题领域相符的那些 |
| regional-academic-database-searcher | 韩国（RISS · KCI · DBpia · ScienceON 等）优先，日本 · 中国 · 欧洲 · 拉美数据库用该国语言查找 |
| research-trend-searcher | Hugging Face Papers · alphaXiv · 会议 Best Paper · 新闻通讯 · Hacker News 上的热门论文及关注度依据 |
| company-blog-searcher | 国内外企业技术博客 · 架构案例 · 产业界论文 · 技术雷达 |
| conference-talk-searcher | 国内外会议演讲视频 · 幻灯片 |
| postmortem-searcher | 故障事后分析 · incident report · 故障复盘 |
| official-document-searcher | 官方文档 · 发布说明 · RFC · W3C · ISO · NIST · OWASP |
| code-usage-searcher | GitHub 代码 · issue · PR，KEP · PEP · Rust RFC · ADR |
| reference-reviewer | 只接收合并后的结果表，逐项判定存在（`확인` 已确认 · `불일치` 不一致 · `없음` 不存在 · `철회` 已撤稿 · `미확인` 未确认）与支持（`지지` 支持 · `부분` 部分 · `아님` 不支持）。不修改结果 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| reference-validate.sh | PreToolUse (Write\|Edit\|MultiEdit) | 查询 `.md` 中新出现的 DOI · arXiv ID，不存在则**阻止** (`RS-01` · `RS-02`)，已撤稿则提示 (`RS-03`)，无法确认则放行并提示 (`RS-04`) |

## 深度与代理数量

按请求复杂度决定深度；用户指定了值则以其为准。

| 深度 | 代理 | 每个代理的工具调用 | 滚雪球 · 验证 |
|---|---|---|---|
| 快速 | 0 ~ 1 个 | 3 ~ 10 | 仅脚本验证 |
| 普通 | 2 ~ 4 个 | 10 ~ 15 | `reference-reviewer` |
| 深入 | 5 ~ 10 个 | 10 ~ 15 | 滚雪球一次 + `reference-reviewer` |

- 请求中写了 "快速" · "深入" · "N 个代理" · "只要 arXiv" · "只要国内" · "除了 ~" 时照做
- 默认值用环境变量设置：`REFERENCE_SEARCH_DEPTH=quick|normal|deep`，`REFERENCE_SEARCH_MAX_AGENTS=<N>`
- 分组多于上限时，把目录叠加到相近的代理上合并 — 不丢弃来源

## 来源与密钥

`scripts/reference-search.sh` 无需密钥即可调用：`openalex` · `openalex-citing` · `openalex-references` · `semantic-scholar` · `crossref` · `arxiv` · `biorxiv` · `medrxiv` · `pubmed` · `europepmc` · `openreview` · `huggingface` · `huggingface-daily` · `hackernews` · `rfc` · `github-repository` · `github-code` · `github-issue`。

- 需要密钥的来源（KCI · RISS · ScienceON · NTIS · CORE · Unpaywall · IEEE · Springer · Scopus）未加入。在脚本中留作 TODO，代理用 WebSearch `site:` 查找
- Semantic Scholar 和 arXiv 不带密钥调用时经常触发请求限额 (429)（2026-10 开发期间两者都收到过 429）。脚本等待一次后重试，然后报告退出码 6 和替代来源 (OpenAlex)
- `github-*` 需要 `gh` 认证，`arxiv` 需要 `xmllint`

## 注意事项

- 钩子只看**新出现**的标识符（当前文件和 `old_string` 中都没有的）。不会在每次修改已有文档时全部重新查询
- 钩子不检查 URL。URL 只在 `/reference-validate` 中检查
- 行内代码 · 代码块中的标识符视为示例，不检查
- 无网络或触发限额时不阻止。要关闭：`REFERENCE_VALIDATE=off`
- 确认存在的标识符缓存在 `${CLAUDE_PLUGIN_DATA}`。确认不存在的不缓存
- 代理 · 技能通过 `${CLAUDE_PLUGIN_ROOT}` 路径读取目录和脚本

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `RS-01` · `RS-02` | 新写入的 DOI · arXiv ID 未注册 | 阻止 |
| `RS-03` | 已撤稿论文 | 提示 |
| `RS-04` | 无法确认（网络 · 限额 · 上限） | 放行 + 提示 |
| `RS-05` · `RS-06` | URL 404 · 访问受限 (`/reference-validate --urls`) | 失败 · 警告 |
| `RS-10` ~ `RS-20` | 仅用工具结果 · 标识符 · 状态 · 路径 · 搜索记录 · 只写打开看过的要点 · 合并 · 权重 · 撤稿标注 · 企业资料日期 · 通过验证 · 深度 · 指令字段（按条款顺序） | AI 判断 |

原文：[`references/reference-search-rules.md`](references/reference-search-rules.md) · 流程：[`references/search-orchestration.md`](references/search-orchestration.md) · 格式：[`references/result-schema.md`](references/result-schema.md) · 依据：[`references/reference-search-methods.md`](references/reference-search-methods.md) · 来源目录：[`references/sources/`](references/sources/)

## 用法

```bash
scripts/reference-search.sh openalex "agent memory" --from 2024-10-26 --limit 8
scripts/reference-search.sh openalex-citing 10.48550/arXiv.2005.11401
scripts/reference-validate.sh --urls docs/research.md
test/reference-validate.test.sh && test/reference-search.test.sh
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
