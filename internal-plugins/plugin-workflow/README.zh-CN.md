# plugin-workflow

[English](README.md) · [한국어](README.ko.md) · **简体中文**

负责插件市场在 GitHub 流程上**额外增加的步骤** — 插件创建 · 重命名 · 删除的顺序、运行全部验证、安装确认后按插件打标签 · 发布、运行 eval。

议题 · 分支 · PR · 合并规则（`W-01` ~ `W-10`）及其钩子由所依赖的 `github-workflow` 负责。名称 · 位置 · 版本 · 编写格式 · 依赖关系由各自的插件负责。

## 安装

在本仓库中由 SessionStart 钩子（`.claude/hooks/sync-internal-plugins.sh`）注册·启用·安装。依赖 `github-workflow` 在安装时由 Claude Code 一并安装。
这是 internal 插件，不分发到其他仓库。

## 依赖

| 插件 | 原因 |
|---|---|
| `github-workflow` | 议题 · 分支 · PR · 合并步骤与钩子。本插件在其间增加步骤 |

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| plugin-release-create | 发布、打标签、部署 | 第 9 · 10 步 — 在 main 上确认安装，对当前版本没有标签的每个插件打标签 · 发布 |
| plugin-create | 新建插件 | 判断必要性 → 名称 → 放置位置 → 目录 → 版本 → 规则原文 · 验证器 · 测试 → README → 依赖 → 注册 → eval → 强制有效性确认 → 验证 → 安装确认 |
| plugin-name-update | 插件重命名 | 用户确认 → 新名称 → `--dry-run` → 执行 → 判断剩余引用 → 版本 → 重装提示 → 新名称的首个标签。public 插件保留 `renames` |
| plugin-delete | 删除 · 停用插件 | 确认反向引用 → 断开依赖 → 清理目录 · 注册。标签保留 |

## 文件

| 路径 | 作用 |
|---|---|
| `references/workflow-rules.md` | 本市场增加的步骤（与 `github-workflow` 步骤的顺序） |
| `scripts/verify-all.sh` | 按路径约定找到验证器 · 回归测试 · `claude plugin validate` 并全部运行 |
| `scripts/release-plugins.sh` | 对当前版本没有标签的每个插件打标签 · 发布（`--dry-run` · `--since`） |
| `scripts/plugin-name-update.sh` | 重命名 — 修改目录 · `plugin.json` · 条目 · `renames` · 依赖它的插件的 `dependencies` · `enabledPlugins` 键，并列出剩余引用候选（`--dry-run`） |
| `scripts/eval-all.sh` | 按用例逐个运行所有插件的 eval 用例 — 只授予所需权限，不发布报告（`--quick`） |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 — 创建 · 重命名 · 删除技能的触发 |

## 注意事项

- 在工作树会话中运行的技能 · 钩子是**主检出的**。在工作树中做的修改在合并后生效
- 本插件和 `.github/` 进入 main 之前的分支（`feature/plugin-creater-setting`）作为引导例外，仅一次未经议题合并

## 使用

在仓库根目录运行。

```bash
S=internal-plugins/plugin-workflow
$S/scripts/verify-all.sh .
$S/scripts/release-plugins.sh --dry-run
$S/scripts/eval-all.sh --quick .
$S/test/workflow-scripts.test.sh
```

## 变更记录

见 [`CHANGELOG.md`](CHANGELOG.md)。
