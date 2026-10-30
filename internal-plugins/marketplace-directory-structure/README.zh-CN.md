# marketplace-directory-structure

[English](README.md) · [한국어](README.ko.md) · **简体中文**

强制市场根目录和各插件的**目录结构**。

只处理**什么放在哪里**。名称是否正确（`plugin-naming`）、是 public 还是 internal 以及注册是否正确（仓库 `.claude/hooks/`）不属于本插件的范围。

## 安装

在本仓库中由 SessionStart 钩子（`.claude/hooks/sync-internal-plugins.sh`）注册 · 启用 · 安装。
这是 internal 插件，不分发到其他仓库。要在别处使用，请移到 `public-plugins/`。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| plugin-directory-create | 创建插件，组件放在哪里 | 按目录结构规则创建插件及其组件 |
| /directory-structure-validate | 直接调用 | 验证根目录和所有插件的结构 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-directory-structure.sh | PreToolUse (Write\|Edit) | 插件内的路径不在规则允许的位置时**阻止** |

## 文件

| 路径 | 作用 |
|---|---|
| `references/directory-structure-rules.md` | 结构规则原文。唯一标准（`R-0x` 根目录 / `P-0x` 插件） |
| `scripts/validate-directory-structure.sh` | 机械验证。钩子与 CLI 共用 |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 — 位置指引技能触发 · 阻止 `docs/`。由 `plugin-workflow` 的 `eval-all.sh` 运行 |

## 行为

`Write` / `Edit` 时，若路径在插件内（`public-plugins/<名称>/...` · `internal-plugins/<名称>/...`），检查**该文件能否放在该位置**，违反则以退出码 2 阻止。

| 路径 | 结果 |
|---|---|
| `internal-plugins/order-sync/scripts/run.sh` | 通过 |
| `internal-plugins/order-sync/hooks/run.sh` | 阻止 — `hooks/` 只放清单（`*.json`） |
| `internal-plugins/order-sync/docs/guide.md` | 阻止 — 未知目录 |
| `internal-plugins/order-sync/NOTES.md` | 阻止 — 根目录只能放 README·README.ko·README.zh-CN·CHANGELOG·LICENSE·.gitignore |
| `.agent-tasks/order/plan.md` | 不响应 |

钩子**只看位置**。必需文件是否齐全（`README.md`、`CHANGELOG.md`、`SKILL.md` …）在逐个创建文件的过程中无法判定，所以由 CLI 全量检查负责。

## CLI

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" --all .            # 根目录 + 所有插件
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" --marketplace .    # 仅根目录
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" internal-plugins/order-sync
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-directory-structure.sh" internal-plugins/order-sync/docs/guide.md
```

退出码：`0` 通过 / `2` 违反 / `1` 执行错误。

## 规则摘要

冲突时以 [`references/directory-structure-rules.md`](references/directory-structure-rules.md) 为准。

插件根目录：`.claude-plugin/plugin.json` · `README.md` · `README.ko.md` · `README.zh-CN.md` · `CHANGELOG.md` 为必需。根目录只能放 `README.md` · `README.ko.md` · `README.zh-CN.md` · `CHANGELOG.md` · `LICENSE` · `.gitignore`。

| 目录 | 可放内容 |
|---|---|
| `.claude-plugin/` | `plugin.json` |
| `skills/` | `{skill-name}/SKILL.md`（目录内部自由） |
| `hooks/` | `*.json` |
| `scripts/` | `*.sh` |
| `commands/` | `*.md` |
| `references/` | `*.md` `*.json` |
| `agents/` | `*.md` |
| `test/` | `*.test.sh` `README.md` |
| `evals/` | `{case-name}/` 目录。其内部遵循 Claude Code eval 格式（`prompt.md` · `graders/*.md` · `case.yaml` · 夹具），因此自由 |

市场根目录：`.claude-plugin/marketplace.json` · `README.md` · `README.ko.md` · `README.zh-CN.md` · `CHANGELOG.md` 为必需；`.claude-plugin/` 只放 `marketplace.json` `tags.json` `categories.json` `plugins.json` `keywords.json`；插件只能直接放在 `public-plugins/<名称>/` · `internal-plugins/<名称>/` 下。

## 测试

```bash
test/validate-directory-structure.test.sh          # 全部
test/validate-directory-structure.test.sh TC-D1    # 按 ID 前缀过滤
```

TC 规格见 [`test/README.md`](test/README.md)。

## 变更记录

见 [`CHANGELOG.md`](CHANGELOG.md)。
