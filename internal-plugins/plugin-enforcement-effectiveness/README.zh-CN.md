# plugin-enforcement-effectiveness

[English](README.md) · [한국어](README.ko.md) · **简体中文**

复现并阻止插件在钩子配置 · 代理前置元数据 · 规则原文中写明的强制措施**在运行时被悄悄关闭**的情况。

阻断钩子的脚本不存在、没有执行权限或使用相对路径时，钩子会失败，工具调用照常通过。插件代理的 `permissionMode` · `hooks` · `mcpServers` 会被忽略。`claude plugin validate --strict` 对这些全部放行（复现命令见规则原文第 5 节）。

格式由 `plugin-authoring`、文件位置由 `marketplace-directory-structure`、创建顺序由 `plugin-workflow` 负责。这里检查的是即使格式正确**在运行时也不生效的东西**。

## 安装

在本仓库中由 SessionStart 钩子（`.claude/hooks/sync-internal-plugins.sh`）注册·启用·安装。
这是 internal 插件，不分发到其他仓库。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| enforcement-effectiveness-review | 检查插件构成 · 职责划分 · 钩子是否真的拦截 | 脚本 → 审查代理 → 复现确认指摘 → 报告 |
| /enforcement-effectiveness-validate | 直接调用 | 验证整个仓库，包括实际运行钩子 · MCP |

## 代理

| 代理 | 说明 |
|---|---|
| enforcement-effectiveness-reviewer | 在没有编写上下文的情况下判定职责划分（`EF-40` ~ `EF-44`），每条指摘附上复现命令。不修改文件 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-enforcement-effectiveness.sh | PreToolUse (Write) | 要写入的 `hooks.json` · `plugin.json` · 代理 · 技能 · 命令违反仅凭单个文件即可判定的条款时**阻断**（`EF-01` · `EF-04` · `EF-10` · `EF-11` · `EF-13`）。`onFailure: "block"` |
| validate-enforcement-effectiveness.sh | PostToolUse (Write\|Edit) | 插件文件保存后检查该插件整体并**提醒** |

## 文件

| 路径 | 作用 |
|---|---|
| `references/enforcement-effectiveness-rules.md` | 规则原文 — 条款、判定时机、依据与复现命令 |
| `scripts/validate-enforcement-effectiveness.sh` | 机器验证。钩子与 CLI 两用 |
| `test/` | 回归测试 · 变异测试结果与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 — 阻断被忽略的代理字段 · 审查技能触发。通过 `plugin-workflow` 的 `eval-all.sh` 运行 |

## 拦截什么

| | 条款 |
|---|---|
| 强制链 | `EF-01` 相对路径 · `EF-02` 指向的文件 · `EF-03` 执行权限 · `EF-04` 不接受 matcher 的事件 · `EF-05` 条款 ID ↔ TC · `EF-06` 有条款则需验证器 · 钩子 · `EF-07` `onFailure: "block"`（仅 `--since` 阻断） |
| 声明生效 | `EF-10` 被忽略的代理字段 · `EF-11` 声明 `tools` · `EF-12` 编辑工具（警告） · `EF-13` 命令 · 技能重名 |
| 运行 | `EF-20` 对无关输入运行钩子（警告） · `EF-21` MCP `initialize` · `EF-22` 所引用的 MCP 工具名 |
| eval | `EF-30` trigger · hook 用例 · `EF-31` 每个技能的触发评分器（`--since` 仅对新插件阻断） |

## 为什么不立即对现有插件阻断

`EF-07` · `EF-31` 在 `--all` 中是警告。截至 2026-10-30，没有触发评分器的技能有 17 个（缺少 `onFailure` 的 26 个钩子已全部修复）— 一次性修复会让大多数插件升版本。
由于 `verify-all.sh` 也会运行 `--since origin/main`，**新建或修改的插件**会被阻断（`EF-31` 仅限新插件）。

## 使用

在仓库根目录运行。`--all` 一个插件都没找到时为运行错误（退出码 `1`）。`--all` · `--since` 会在临时目录中实际运行钩子脚本和 MCP 服务器（`--no-run` 时跳过）。

```bash
S=internal-plugins/plugin-enforcement-effectiveness
$S/scripts/validate-enforcement-effectiveness.sh $S                          # 单个插件（不做运行检查）
$S/scripts/validate-enforcement-effectiveness.sh --all .                     # 整个仓库
$S/scripts/validate-enforcement-effectiveness.sh --since origin/main .       # 仅变更的插件
$S/test/validate-enforcement-effectiveness.test.sh                           # 回归测试
```

## 变更记录

见 [`CHANGELOG.md`](CHANGELOG.md)。
