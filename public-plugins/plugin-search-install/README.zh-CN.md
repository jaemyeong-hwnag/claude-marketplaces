# plugin-search-install

[English](README.md) · [한국어](README.ko.md) · **简体中文**

查询并安装本插件市场的 public 插件 —— 按项目声明 · 文件信号找出所需插件，按插件 · 功能词找出相关插件，按字段 · 标签维度 · 同义词 · 容错拼写进行功能搜索。可全部安装 · 部分安装 · 仅查看。以 CLI 和本地 MCP 服务器形式使用。

**范围仅限安装本插件时所来自的插件市场中 `category: public` 的插件。** 其他插件市场和 internal 插件不会被查询 · 推荐 · 安装。插件市场名称未写死，因此在 fork 出的插件市场中也处理该市场的 public 插件。

```
project   本项目需要什么              声明(设置) · 依赖闭包 · 文件信号推荐
related   与之相关的是什么            依赖 · 反向依赖 · 标签 · 关键词 · 名称 · 组件 · 描述
search    能做这件事的是什么          字段:值 · domain: · tech: · -排除 · a|b · /正则/ · has: · is: · dep:
facets    有哪些                      按领域 · 技术标签(tags.json 描述) · 关键词 · 组件计数
install   安装选中的                  全部 · 按编号/名称部分 · 排除 · 仅查看 · dry-run
```

同一个引擎有三种用法 —— 技能调用的 CLI、Claude 无需 Bash 即可调用的**本地 MCP 服务器**，以及在终端中以表格 · 卡片显示并用方向键选择的 [`plugin-browser`](../plugin-browser/README.md)。逻辑只在引擎一处。

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install plugin-search-install@jaemyeong-hwnag-plugins --scope project
```

需要：`bash` (3.2 及以上)、`jq` (1.6 及以上)、`find` · `grep` · `awk`。没有 `claude` CLI 时读取 `~/.claude/plugins/` 中的记录文件 (安装需要 CLI)。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| plugin-search | 找插件 · 有没有能 ~ 的插件 · 类似的插件 | 把请求转换为查询语法，运行 `search` · `related`，并附上理由展示 |
| plugin-project-requirement-search | 这个项目该装什么 · 缺少的插件 · 入门配置 | 把 `project` 结果分为必需(声明 · 依赖)与推荐(信号)，附上状态 · 依据展示 |
| plugin-install | 帮我装 · 全部安装 · 只要 1 号和 3 号 · 除了这个 | 确定全部 · 部分 · 仅查看及范围，然后 dry-run → 安装 → 提示重启 |

## MCP 服务器

安装插件后，Claude Code 会在本地启动 `plugin-search` MCP 服务器(`scripts/plugin-search-mcp.sh`，stdio)。运行时只需 `bash` · `jq`。

| 工具 | 作用 |
|---|---|
| `search_plugins` | 功能搜索 —— 查询语法 · 标签 · 领域 · 技术 · 组件 · 是否已安装 |
| `list_related_plugins` | 与插件 · 功能词相关的插件 |
| `list_project_plugins` | 本项目需要的插件 |
| `get_plugin` | 单个插件详情 |
| `list_plugin_facets` | 按维度计数 |
| `install_plugins` | 安装 —— **默认 dry-run**，仅在 `dry_run: false` 时安装 |

不安装插件而直接接入时(需指定插件市场名称)：

```bash
claude mcp add plugin-search -e PLUGIN_SEARCH_MARKETPLACE=jaemyeong-hwnag-plugins -- <路径>/scripts/plugin-search-mcp.sh
```

## 注意事项

- 自 0.3.0 起，技能 `project-plugin-search` 更名为 `plugin-project-requirement-search` —— 用 `/plugin-search-install:plugin-project-requirement-search` 调用
- **安装默认 `--scope project`** —— 会修改项目的 `.claude/settings.json`。个人工具请用 `--scope user`
- 无法判断目标插件市场或该市场未注册时会停止 —— 用 `PLUGIN_SEARCH_MARKETPLACE` 指定
- 远程 source(github · url)插件在安装前不知道其技能 · 钩子 (`componentsKnown: false`)。只能按名称 · 描述 · 标签找到
- 需要确认命令执行的插件(command source)不会代为用 `-y` 批准。会告知需自行运行的命令
- 安装的插件需**重启 Claude Code** 才会加载 (`restartRequired`)
- 目录缓存为 10 分钟。更新了插件市场却看不到时用 `--refresh`
- 项目推荐只看文件痕迹。示例目录中的 `pom.xml` 也会成为 Java 信号 —— 技能会查看 `evidence` 加以筛除

## 用法

```bash
S=scripts/plugin-search-install.sh
$S search 테스트 커버리지                         # 功能搜索 (同义词 · 助词 · 容错拼写)
$S search naming has:hook -java --format tsv      # 字段 · 排除 · 表格
$S search tech:spring is:not-installed --sort installs
$S search --domain development --has hook
$S related java-naming --by name,tag              # 相关 —— 选择关系
$S related 문서 동기화                             # 按功能词查相关
$S project . --only missing                       # 已声明但未安装的
$S facets                                         # 按领域 · 技术 · 关键词 · 组件计数
$S search 커버리지 > /tmp/l.json && $S install --from /tmp/l.json --select 1,2 --dry-run
$S install github-workflow --scope user
```

## 文件

| 路径 | 作用 |
|---|---|
| `references/search-rules.md` | 规则原文 —— 目录来源、查询语法、评分、相关 · 项目 · 安装规则、输出字段 |
| `references/search-synonyms.json` | 同义词组 (韩 · 英) · 停用词 |
| `references/project-signals.json` | 33 种文件信号 —— 路径 · 内容模式、搜索词、权重、是否语言互斥 |
| `scripts/plugin-search-install.sh` | `catalog` · `search` · `related` · `project` · `detect` · `show` · `facets` · `install` |
| `scripts/plugin-search-mcp.sh` | 本地 MCP 服务器 (stdio) —— 把引擎封装为 6 个工具 |
| `test/` | 回归测试与 TC 规格 —— 引擎(桩 claude · 假插件市场)、MCP(JSON-RPC 对话) |
| `evals/` | `claude plugin eval` 用例 —— 功能搜索技能触发(`search-request`) |

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
