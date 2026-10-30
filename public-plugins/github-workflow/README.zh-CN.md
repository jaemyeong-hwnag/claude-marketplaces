# github-workflow

[English](README.md) · [한국어](README.ko.md) · **简体中文**

强制 GitHub 仓库中的变更**从 issue 到合并所走的路径** — feature · bugfix 的 issue 与 PR 模板、带 issue 编号的分支、默认分支保护、变基后的合并提交、只在默认分支上打标签。

验证 · 测试什么、如何升级版本由项目决定。这里只检查 **在 git 和 GitHub 上执行的步骤顺序**。

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install github-workflow@jaemyeong-hwnag-plugins --scope project
```

安装后若缺少模板 · 标签，用 "准备 issue · PR 模板" 调用 `github-template-create`。

需要：`git`、`jq`、`gh`（已登录）。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| github-template-create | 引入流程、issue · PR 模板、标签 | 第 0 步 — 复制 `.github/` issue 表单 · PR 模板（不覆盖），标签 `feature` · `bugfix` |
| issue-create | 开始工作，创建 issue · 分支 · 工作树 | 第 1 · 2 步 — 判断类型，创建 issue，从默认分支创建分支 · 工作树 |
| pull-request-create | 提交 PR、变基、验证 | 第 4 ~ 6 步 — 项目验证 · 测试，变基后重新验证，带模板 · 标签的 PR |
| pull-request-merge | 合并、清理 | 第 7 · 8 步 — 合并提交，拉取默认分支，清理工作树 · 分支，确认 issue 已关闭 |
| /github-workflow-validate | 直接调用 | 模板 · 当前分支 · 是否最新 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-workflow.sh | PreToolUse (Bash) | `git` · `gh` · `claude plugin tag` 命令违反 `W-03` ~ `W-10` 时**拦截**。工作树位置（`W-04`）仅提示 |

## 注意事项

- 安装后，在本仓库的**默认分支上会拦截 `git commit` · `git push` · `cherry-pick` · `revert` · `am`，以及非 `--ff-only` 的 `git merge` · `git pull`（`pull.ff=only` 时放行）**（`W-09`）。请在 `{feature|bugfix}/{issue}-{slug}` 分支上工作
- 默认分支从 `origin/HEAD` 读取。没有时按 `origin/main` → `origin/master` → `main` 的顺序查找 — 用 `git remote set-head origin --auto` 设置
- 没有 `jq` 时无法检查 `git` · `gh` · `claude` 命令，因此会拦截
- 子 shell · `bash -c` · `eval` · `$( )` 中的命令也会检查。用变量拼出的命令（`$CMD`）无法检查
- 无法拦截 Web UI 上的合并 · 推送。能开启分支保护时请一并开启
- 自 0.2.0 起，`/github-workflow:workflow-validate` 改为 `/github-workflow:github-workflow-validate`

## 拦截内容

| | 条款 |
|---|---|
| 模板 | `W-01` issue 表单 `feature` · `bugfix` + 禁止空白 issue · `W-02` 两个 PR 模板，禁止单一默认文件 |
| 分支 | `W-03` `{feature\|bugfix}/{issue}-{slug}` · `W-04` 工作树位置（提示） |
| PR · 合并 | `W-05` 模板 · 标签 · 禁止 `--fill` · `W-06` 包含最新默认分支 · `W-07` 仅合并提交 |
| 默认分支 | `W-08` 强制推送只用 `--force-with-lease` · `W-09` 禁止直接提交 · 合并 · 推送 · `W-10` 只在默认分支上打标签 |

## 文件

| 路径 | 作用 |
|---|---|
| `references/workflow-rules.md` | 规则原文（`W-01` ~ `W-10`，步骤） |
| `scripts/validate-workflow.sh` | 钩子 · CLI 共用的验证（`--templates` · `--branch` · `--up-to-date`） |
| `scripts/branch-create.sh` | 第 2 步 — 从默认分支创建符合规则的分支和工作树 |
| `skills/github-template-create/templates/` | 默认 issue 表单 · PR 模板 |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 — PR 技能触发 · main 提交被拦截 |

## 用法

```bash
scripts/validate-workflow.sh --templates .
scripts/branch-create.sh feature 12 order-sync
test/validate-workflow.test.sh
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
