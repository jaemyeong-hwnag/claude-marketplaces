# claude-marketplaces

[English](README.md) · [한국어](README.ko.md) · **简体中文**

用钩子而不是模型可以跳过的指令来强制规则的 Claude Code 插件集合。改了代码却没改测试或 lint 失败时退回完成，把 AI 的改动交给看不到作者结论的验证者，阻止指向生产主机的压测，阻止提交密钥，并强制 Java · Kotlin · TypeScript · Node.js · Python · Go 的命名规范。面向希望在每个 Claude Code 会话中都应用这些规则的个人和团队。完成（`Stop`）关卡每个请求只退回一次，不能代替人工审查。

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install code-edit-guardrail@jaemyeong-hwnag-plugins
```

市场名称为 `jaemyeong-hwnag-plugins`。

- **想使用插件的人** — [快速开始](#快速开始) · [收录插件](#收录插件) · [常见问题](#常见问题)
- **为本仓库做贡献的人** — [在本仓库中工作](#在本仓库中工作)

## 快速开始

需要：Claude Code、`bash`、`jq`。

**1. 添加市场**（每台电脑一次）

在 Claude Code 会话中：

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
```

**2. 安装插件**

从[收录插件](#收录插件)表中选择名称安装。也可以打开 `/plugin` 从列表中选择。

```
/plugin install <名称>@jaemyeong-hwnag-plugins
```

会询问安装范围 — 想让团队获得相同配置选 `project`，只给自己用选 `user`。

**3. 重启 Claude Code**

钩子 · 技能 · MCP 服务器在会话启动时加载。

> 在终端中可用 `claude plugin marketplace add …` · `claude plugin install … --scope project` 完成同样的操作。

### 让整个团队使用相同插件

把市场和插件写入项目的 `.claude/settings.json` 并提交。团队成员信任该文件夹后，市场会被注册，`enabledPlugins` 中的插件会被启用。

```json
{
  "extraKnownMarketplaces": {
    "jaemyeong-hwnag-plugins": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": {
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
| 钩子不起作用或报错 | 查看 `claude plugin list` 中的错误。钩子脚本需要 `jq` — `brew install jq`（macOS）· `apt install jq` |
| 以 `…@plugin-marketplace` 安装 | 那是旧的市场名称 — 执行 `claude plugin marketplace remove plugin-marketplace` 后从第 1 步开始 |

## 收录插件

安装：`/plugin install <名称>@jaemyeong-hwnag-plugins`。每个插件都有英文 · 韩文 · 中文 README。

| 领域 | 插件 | 作用 |
|---|---|---|
| 代码编辑护栏 | [`code-edit-guardrail`](public-plugins/code-edit-guardrail) | 只改代码不改测试、或改动路径的 lint · 格式检查失败时阻止完成；编辑共享资源前需用户确认。与语言无关 |
| 验证 · 评审 | [`common-evidence-review`](public-plugins/common-evidence-review) | 由没有编写上下文的验证者根据执行证据判定变更是否必要 · 论断是否属实 |
| | [`common-design-soundness-review`](public-plugins/common-design-soundness-review) | 由没有编写上下文的验证者在实现前判定设计（结构 · 流程 · 决策）是否前后一致 |
| | [`common-performance-review`](public-plugins/common-performance-review) | 从 9 个类别（复杂度 · 查询 · IO · 并发 · 缓存 …）全面评审代码变更的性能，编写时提示循环内查询 · await 等 19 种模式。与语言无关 |
| 负载 · 性能 | [`common-stress-test`](public-plugins/common-stress-test) | 定量设计并判定负载测试（阻止生产主机 · 可持续容量 · 回归统计）。与语言无关 |
| | [`java-spring`](public-plugins/java-spring-stress-test) · [`python-fastapi`](public-plugins/python-fastapi-stress-test) · [`python-django`](public-plugins/python-django-stress-test) · [`node-express`](public-plugins/node-express-stress-test) · [`typescript-nestjs`](public-plugins/typescript-nestjs-stress-test) · [`go-gin`](public-plugins/go-gin-stress-test) `-stress-test` | 按框架的服务器埋点、检测使测量无效的配置、微基准测试 |
| 安全 | [`git-secret-validate`](public-plugins/git-secret-validate) | 在 `git commit` · `git push` 前阻止密钥 · 令牌 · 密码和 `.env` · 密钥文件，写入未被 ignore 的文件时警告。检测用 gitleaks（没有则用内置模式） |
| 测试 | [`java-spring-aitest-coverage`](public-plugins/java-spring-aitest-coverage) · [`kotlin-spring-aitest-coverage`](public-plugins/kotlin-spring-aitest-coverage) | 用 `@AiTest` 覆盖 Java · Kotlin Spring Boot 中变更的方法，并设 JaCoCo 100% 门槛 |
| 代码命名 | [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming) | 用钩子阻止违反各语言官方指南的名称形式，用技能判断用词 |
| 文档 | [`domain-document-sync`](public-plugins/domain-document-sync) | 将领域知识文档分三层存放，并与代码变更保持一致 |
| | [`common-document-slop-review`](public-plugins/common-document-slop-review) | 每次编写或修改文档时阻止 slop（对话残留 · 失效链接 · 无依据的论断），并要求事实核查 |
| 查找参考资料 | [`reference-search`](public-plugins/reference-search) | 用按来源划分的代理查找论文、其他公司的技术案例、官方文档和标准，并阻止引用不存在的 DOI · arXiv ID |
| GitHub 流程 | [`github-workflow`](public-plugins/github-workflow) | 强制 issue → 带 issue 编号的分支 → PR → 合并提交 → 标签 的流程 |

仅用于开发本仓库的 internal 插件 — [`plugin-naming`](internal-plugins/plugin-naming) · [`marketplace-directory-structure`](internal-plugins/marketplace-directory-structure) · [`plugin-versioning`](internal-plugins/plugin-versioning) · [`plugin-authoring`](internal-plugins/plugin-authoring) · [`plugin-dependency`](internal-plugins/plugin-dependency) · [`plugin-enforcement-effectiveness`](internal-plugins/plugin-enforcement-effectiveness) · [`plugin-workflow`](internal-plugins/plugin-workflow)。

## 常见问题

### 如何让 Claude Code 不写测试就无法结束任务？

安装 [`code-edit-guardrail`](public-plugins/code-edit-guardrail) 并说"帮我设置护栏"。一次请求中改了代码却没有改任何测试文件，或所改路径的 lint · 格式 · 类型检查命令失败时，`Stop` 钩子会退回一次完成。行为不变的修改只要 Claude 在豁免文件中写下理由即可通过 —— 钩子不检查用户是否同意。

### 如何让 Claude 以外的一方来验证 Claude Code 的改动？

[`common-evidence-review`](public-plugins/common-evidence-review) 只把原始请求 · 改动的文件 · 去掉结论的问题交给单独的验证代理，验证者按执行证据逐项判定。一次请求中改了 3 行以上代码 · 配置却未经此验证就要结束时，会退回一次。关卡只检查是否调用了验证者，不检查是否遵循了判定。

### 如何防止 Claude Code 提交 API 密钥或 `.env` 文件？

[`git-secret-validate`](public-plugins/git-secret-validate) 会阻止带有密钥 · 敏感文件的 `git commit` · `git push`。检测使用 gitleaks，没有时使用内置模式。用 `bash -c` · `sh -c` · `eval` 包裹的命令也会检查。

### Claude Code 能否在不触及生产环境的情况下做压测？

[`common-stress-test`](public-plugins/common-stress-test) 会阻止目标主机不在允许列表（回环 · 私有 IP · `*.local` · `*.test` · `*.internal` · 自行添加的主机）中的压测命令（k6 · Gatling · Locust · JMeter · wrk · hey · bombardier · siege 等）。经 `make` · `npm run` 的间接执行以及由变量构成的命令 · 目标无法识别。

### 如何让 Claude Code 遵守语言的命名规范？

安装对应语言的插件 — [`java-naming`](public-plugins/java-naming) · [`kotlin-naming`](public-plugins/kotlin-naming) · [`typescript-naming`](public-plugins/typescript-naming) · [`node-naming`](public-plugins/node-naming) · [`python-naming`](public-plugins/python-naming) · [`go-naming`](public-plugins/go-naming)。钩子只阻止本次编辑新引入的违规，已有代码不会阻挡你。

### 为什么用钩子而不是 `CLAUDE.md` 指令？

钩子由 Claude Code 在模型之外直接执行。指令可以被跳过，而 `PreToolUse` 钩子可以拒绝工具调用，`Stop` 钩子可以拒绝结束回合。不过本仓库的 `Stop` 关卡在同一请求中只退回一次 —— 模型第二次结束时可以通过。

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
