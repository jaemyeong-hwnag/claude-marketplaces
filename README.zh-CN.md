# claude-marketplaces

[English](README.md) · [한국어](README.ko.md) · **简体中文**

Claude Code 插件市场仓库。市场名称为 `jaemyeong-hwnag-plugins`。

- **想使用插件的人** — [快速开始](#快速开始) · [查找插件](#查找插件) · [自动安装项目所需插件](#自动安装项目所需插件) · [收录插件](#收录插件)
- **为本仓库做贡献的人** — [在本仓库中工作](#在本仓库中工作)

## 快速开始

需要：Claude Code、`bash`、`jq`。

**1. 添加市场**（每台电脑一次）

在 Claude Code 会话中：

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
```

**2. 安装查询 · 安装插件**

```
/plugin install plugin-search-install@jaemyeong-hwnag-plugins
```

会询问安装范围 — 想让团队获得相同设置选 `project`，只给自己用选 `user`。这个插件负责查找并安装其他插件（包含本地 MCP 服务器 `plugin-search`）。

**3. 重启 Claude Code**

插件和 MCP 服务器在会话启动时加载。`/mcp` 中出现 `plugin-search` 即完成。

> 在终端中可用 `claude plugin marketplace add …` · `claude plugin install … --scope project` 完成同样的操作。

## 查找插件

对象是**本市场的 public 插件**（[收录插件](#收录插件)）。

### 直接告诉 Claude

| 想做的事 | 这样说 |
|---|---|
| 按功能查找 | "有提高测试覆盖率的插件吗？" |
| 查找相关插件 | "给我看和 github-workflow 类似或一起用的插件" |
| 浏览有哪些 | "按标签列出有哪些插件" |
| 详细了解一个插件 | "java-naming 有哪些技能和钩子？" |

Claude 用 `plugin-search` MCP 工具（或 `plugin-search` 技能）查找，并附上理由展示结果。

### 查询语法（精确查找时）

| 形式 | 含义 | 例 |
|---|---|---|
| `词` | 名称 · 描述 · 标签 · 关键词 · 技能 · 钩子 · MCP 任意位置 | `naming` |
| `字段:值` | 仅在该字段 | `tag:spring` · `tech:spring` · `domain:development` · `skill:issue-create` |
| `-词` | 排除 | `naming -java` |
| `a\|b` | 二者之一 | `github\|gitlab` |
| `has:类型` | 含有该组件 | `has:hook` · `has:mcp` |
| `is:状态` | 安装状态 | `is:not-installed` |

允许同义词（韩 · 英）、韩语助词和错别字 — 用 "네이밍" 也能找到 `naming`。完整语法见 [`search-rules.md`](public-plugins/plugin-search-install/references/search-rules.md)。

### 终端界面

想以表格 · 卡片浏览并用方向键 · 空格选择安装，请安装 [`plugin-browser`](public-plugins/plugin-browser)。

```
/plugin install plugin-browser@jaemyeong-hwnag-plugins
```

在终端（Claude 之外）：

```bash
PB="$(claude plugin list --json | jq -r '[.[] | select(.id=="plugin-browser@jaemyeong-hwnag-plugins")][0].installPath')/scripts/plugin-browser.sh"
bash "$PB"                        # 菜单 — 项目 · 功能搜索 · 相关 · 标签 · 已安装
bash "$PB" search 测试覆盖率
```

## 自动安装项目所需插件

在项目目录中告诉 Claude：

```
安装这个项目需要的插件
```

1. 分三路查找并附上依据
   - **必需** — 在项目 `.claude/settings.json` 中声明但未安装的插件，以及它们依赖的插件
   - **推荐** — 根据文件信号挑选（例：`build.gradle` + Spring → `java-spring-*`，`.github/` → `github-workflow`）
2. 先展示安装计划 — **不会立即安装**
3. 选择 "全部" · "只要 1 和 3" · "不要推荐的" · "只查看" 后照此安装（默认范围 `project`）
4. 重启 Claude Code 后加载

### 用 CLI（脚本 · CI）

```bash
PSI="$(claude plugin list --json | jq -r '[.[] | select(.id=="plugin-search-install@jaemyeong-hwnag-plugins")][0].installPath')/scripts/plugin-search-install.sh"

"$PSI" project . --format tsv                          # 查看所需（必需 + 推荐，含依据）
"$PSI" project . --only declared > /tmp/need.json      # 仅必需（声明 · 依赖）
"$PSI" install --from /tmp/need.json --all --dry-run   # 计划 — 跳过已安装的
"$PSI" install --from /tmp/need.json --all             # 安装
"$PSI" project . > /tmp/all.json && "$PSI" install --from /tmp/all.json --select 1,3-5   # 按编号选择
```

### 让整个团队使用相同插件

把市场和插件写进项目的 `.claude/settings.json` 并提交。团队成员添加市场后，说一次 "安装这个项目需要的插件" 即可 — 这里写的插件都算作**必需**。

```json
{
  "extraKnownMarketplaces": {
    "jaemyeong-hwnag-plugins": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": {
    "plugin-search-install@jaemyeong-hwnag-plugins": true,
    "<名称>@jaemyeong-hwnag-plugins": true
  }
}
```

### 更新 · 故障排查

```
/plugin marketplace update jaemyeong-hwnag-plugins     # 获取新插件 · 新版本
```

| 症状 | 解决 |
|---|---|
| `/mcp` 中没有 `plugin-search` | 重启 Claude Code。仍然没有就查看 `claude plugin list` 中的 `Error:` |
| 工具提示 "需要 jq" | `brew install jq`（macOS）· `apt install jq` |
| 以 `…@plugin-marketplace` 安装 | 那是旧的市场名称 — 执行 `claude plugin marketplace remove plugin-marketplace` 后从第 1 步开始 |
| 找不到想要的插件 | 只搜索本市场的 **public** 插件。其他市场和 internal 插件不会出现 |

## 收录插件

安装：`/plugin install <名称>@jaemyeong-hwnag-plugins`。每个插件都有英文 · 韩文 · 中文 README。

| 领域 | 插件 | 作用 |
|---|---|---|
| 查找 · 安装插件 | [`plugin-search-install`](public-plugins/plugin-search-install) | 本市场 public 插件的搜索 · 相关 · 项目所需 · 安装。包含本地 MCP 服务器 |
| | [`plugin-browser`](public-plugins/plugin-browser) | 以终端界面（表格 · 卡片 · 方向键选择）显示上述结果 |
| 代码命名 | [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming) | 用钩子阻止违反各语言官方指南的名称形式，用技能判断用词 |
| 测试 | [`java-spring-aitest-coverage`](public-plugins/java-spring-aitest-coverage) · [`kotlin-spring-aitest-coverage`](public-plugins/kotlin-spring-aitest-coverage) | 用 `@AiTest` 覆盖 Java · Kotlin Spring Boot 中变更的方法，并设 JaCoCo 100% 门槛 |
| 代码编辑护栏 | [`code-edit-guardrail`](public-plugins/code-edit-guardrail) | 只改代码不改测试、或改动路径的 lint · 格式检查失败时阻止完成；编辑共享资源前需用户确认。与语言无关 |
| 验证 · 评审 | [`common-evidence-review`](public-plugins/common-evidence-review) | 由没有编写上下文的验证者根据执行证据判定变更是否必要 · 论断是否属实 |
| | [`common-design-soundness-review`](public-plugins/common-design-soundness-review) | 由没有编写上下文的验证者在实现前判定设计（结构 · 流程 · 决策）是否前后一致 |
| | [`common-performance-review`](public-plugins/common-performance-review) | 从 9 个类别（复杂度 · 查询 · IO · 并发 · 缓存 …）全面评审代码变更的性能，编写时提示循环内查询 · await 等 19 种模式。与语言无关 |
| 安全 | [`git-secret-validate`](public-plugins/git-secret-validate) | 在 `git commit` · `git push` 前阻止密钥 · 令牌 · 密码和 `.env` · 密钥文件，写入未被 ignore 的文件时警告。检测用 gitleaks（没有则用内置模式） |
| 负载 · 性能 | [`common-stress-test`](public-plugins/common-stress-test) | 定量设计并判定负载测试（阻止生产主机 · 可持续容量 · 回归统计）。与语言无关 |
| | [`java-spring`](public-plugins/java-spring-stress-test) · [`python-fastapi`](public-plugins/python-fastapi-stress-test) · [`python-django`](public-plugins/python-django-stress-test) · [`node-express`](public-plugins/node-express-stress-test) · [`typescript-nestjs`](public-plugins/typescript-nestjs-stress-test) · [`go-gin`](public-plugins/go-gin-stress-test) `-stress-test` | 按框架的服务器埋点、检测使测量无效的配置、微基准测试 |
| 项目质量 | [`project-completeness`](public-plugins/project-completeness) | 诊断项目是否具备服务应有的一切，应用修复并判定运维指标 |
| 文档 | [`domain-document-sync`](public-plugins/domain-document-sync) | 将领域知识文档分三层存放，并与代码变更保持一致 |
| | [`common-document-slop-review`](public-plugins/common-document-slop-review) | 每次编写或修改文档时阻止 slop（对话残留 · 失效链接 · 无依据的论断），并要求事实核查 |
| 查找参考资料 | [`reference-search`](public-plugins/reference-search) | 用按来源划分的代理查找论文、其他公司的技术案例、官方文档和标准，并阻止引用不存在的 DOI · arXiv ID |
| GitHub 流程 | [`github-workflow`](public-plugins/github-workflow) | 强制 issue → 带 issue 编号的分支 → PR → 合并提交 → 标签 的流程 |

仅用于开发本仓库的 internal 插件 — [`plugin-naming`](internal-plugins/plugin-naming) · [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) · [`plugin-versioning`](internal-plugins/plugin-versioning) · [`plugin-authoring`](internal-plugins/plugin-authoring) · [`plugin-dependency`](internal-plugins/plugin-dependency) · [`plugin-enforcement-effectiveness`](internal-plugins/plugin-enforcement-effectiveness) · [`plugin-workflow`](internal-plugins/plugin-workflow)。

## 在本仓库中工作

完整的工作规则在 [`CLAUDE.md`](CLAUDE.md)（韩文）中 — Claude Code 每次会话都会读取，人读也一样。细节由下表中的规则原文规定。

| 路径 | 性质 | 分发 |
|---|---|---|
| [`public-plugins/`](public-plugins) | 分发用插件 | GitHub 市场 — 合并后其他仓库才能获取 |
| [`internal-plugins/`](internal-plugins) | 仅本仓库使用的插件 | 不分发 — 会话启动时由钩子注册 · 安装 |

### 开发流程

```
issue → worktree · 分支 → 工作 → 版本 → 验证 · 测试 → rebase 后重新验证 → PR
→ 合并 → 在 main 上确认安装 → 标签 · 发布 → 清理
```

- issue · 分支 · PR · 提交类型只有 `feature` / `bugfix`。issue 表单和 PR 模板在 [`.github/`](.github)
- 修改了文件的插件要升级版本 — 先 CHANGELOG，再 `plugin.json`
- 只用合并提交。合并并在 main 上确认安装后，用 `plugin-release-create` 技能打标签 · 发布
- 创建插件用 `plugin-create`，重命名用 `plugin-name-update`，删除用 `plugin-delete` 技能

### 各关注点的负责方

一个关注点只由一个插件负责。规则由 `Write` · `Edit` · `Bash` 钩子阻止或提示。

| 关注点 | 插件 | 规则原文 |
|---|---|---|
| 名称 | `plugin-naming` | [`naming-rules.md`](internal-plugins/plugin-naming/references/naming-rules.md) · [`glossary.json`](internal-plugins/plugin-naming/references/glossary.json) |
| 文件位置 | `marketplace-directory-structure` | [`directory-structure-rules.md`](internal-plugins/marketplace-directory-structure/references/directory-structure-rules.md) |
| 版本 · CHANGELOG | `plugin-versioning` | [`versioning-rules.md`](internal-plugins/plugin-versioning/references/versioning-rules.md) |
| 文件内容格式（frontmatter · 三种语言 README） | `plugin-authoring` | [`authoring-rules.md`](internal-plugins/plugin-authoring/references/authoring-rules.md) |
| 插件之间的依赖 | `plugin-dependency` | [`dependency-rules.md`](internal-plugins/plugin-dependency/references/dependency-rules.md) |
| 写下的强制在运行时是否生效 | `plugin-enforcement-effectiveness` | [`enforcement-effectiveness-rules.md`](internal-plugins/plugin-enforcement-effectiveness/references/enforcement-effectiveness-rules.md) |
| issue → 分支 → PR → 合并 | `github-workflow` | [`workflow-rules.md`](public-plugins/github-workflow/references/workflow-rules.md) |
| 安装确认 · 标签 · 发布，创建 · 重命名 · 删除流程 | `plugin-workflow` | [`workflow-rules.md`](internal-plugins/plugin-workflow/references/workflow-rules.md) |
| 放置 · 市场注册 · 安装同步 | 仓库 [`.claude/hooks/`](.claude/hooks) | [`test/README.md`](test/README.md) |

### 验证

PR 前运行，rebase 到 `origin/main` 之后再运行一次。

```bash
internal-plugins/plugin-workflow/scripts/verify-all.sh .        # 全部验证器 · 回归测试 · claude plugin validate --strict
internal-plugins/plugin-workflow/scripts/eval-all.sh --quick .  # 技能触发 · 钩子阻止 eval（调用模型，不发布）
```

### README 使用三种语言

所有插件和本仓库都以相同内容保留 `README.md`（英文，默认）· `README.ko.md` · `README.zh-CN.md`。缺少其中之一、组件表与实际不符、或根目录 README 漏掉 public 插件时，`verify-all.sh` 会阻止（`P-01` · `A-20` ~ `A-30`）。

## 许可证

[MIT](LICENSE)
