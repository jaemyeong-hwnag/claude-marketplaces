# plugin-authoring

[English](README.md) · [한국어](README.ko.md) · **简体中文**

强制插件文件的**内容格式** — 技能 · 命令 · 代理的 frontmatter、技能正文与参考文档的大小，以及三种语言 README 的章节结构与实际组件是否一致。

名称由 `plugin-naming` 检查，文件位置由 `marketplace-directory-structure` 检查，版本由 `plugin-versioning` 检查。本插件只看**已经放在正确位置的文件内部**。

## 安装

在本仓库中，由 SessionStart 钩子（`.claude/hooks/sync-internal-plugins.sh`）注册、启用并安装。
这是 internal 插件，不分发到其他仓库。要在别处使用，请移到 `public-plugins/`。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| plugin-document-create | 编写 SKILL.md · description · README | 判断 frontmatter 与 description，三种语言 README 模板 |
| /authoring-validate | 直接调用 | 验证仓库中所有插件的编写规则 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-authoring.sh | PreToolUse (Write) | 用 `Write` 写入的 SKILL.md · 命令 · 代理的 frontmatter 有误时**阻止**（`A-01` ~ `A-04`） |
| validate-authoring.sh | PostToolUse (Write\|Edit) | 保存插件文件后检查整个插件并**提示** |

## 文件

| 路径 | 作用 |
|---|---|
| `references/authoring-rules.md` | 编写规则原文（`A-01` ~ `A-09` 技能 · 命令 · 代理 · 参考，`A-20` ~ `A-30` README） |
| `scripts/validate-authoring.sh` | 机器验证。兼作钩子与 CLI |
| `test/` | 回归测试与 TC 说明 |
| `evals/` | `claude plugin eval` 用例 — description 编写技能的触发 · 阻止没有 frontmatter 的 SKILL.md。由 `plugin-workflow` 的 `eval-all.sh` 运行 |

## 阻止什么

| | 条款 |
|---|---|
| Frontmatter | `A-01` 开闭 · `A-02` name = 目录名 · 文件名 · `A-03` description · `A-04` "在……时使用" |
| 大小（警告） | `A-05` description 300 字 · `A-06` SKILL.md 200 行 · `A-07` references 500 行 |
| 引用 | `A-08` 相对链接指向的文件存在 · `A-09` skills · references 中禁止外部 URL |
| README | `A-20` 一级标题 · `A-21` 必需章节 · `A-22` 按组件的章节 · `A-23` 顺序 · `A-24` ~ `A-27` 表格 ↔ 实际 · `A-28` public 安装命令 — 每个语言文件按该语言的章节标题检查 |
| 语言 | `A-29` 三种语言 README 互相链接 · `A-30` 根目录三个 README 收录所有 public 插件 |

## 钩子分两路的原因

创建技能再更新 README 需要两次编辑。如果因 README 不一致而阻止第一次编辑，就什么都创建不了。
因此只有像 frontmatter 这样**只看一个文件就能判定的**才在 `PreToolUse` 中阻止，需要看整个插件的在保存后提示。`--all` 全部阻止。

## 使用

在仓库根目录运行。`--all` 一个插件也找不到时为执行错误（退出码 `1`）。

```bash
internal-plugins/plugin-authoring/scripts/validate-authoring.sh internal-plugins/plugin-authoring   # 单个插件
internal-plugins/plugin-authoring/scripts/validate-authoring.sh --all .                             # 整个仓库（含根目录 README）
internal-plugins/plugin-authoring/test/validate-authoring.test.sh                                   # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
