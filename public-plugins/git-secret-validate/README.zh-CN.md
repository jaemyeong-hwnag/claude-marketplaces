# git-secret-validate

[English](README.md) · [한국어](README.ko.md) · **简体中文**

防止密钥、令牌、密码进入 Git — 在 `git commit` · `git push` 之前拦截将要提交的变更中的密钥和敏感文件（`.env` · 密钥文件），写文件时若新密钥写入未被 ignore 的文件、或敏感文件未被 ignore，则发出警告。

检测交给 gitleaks，本插件负责 **何时 · 检查什么** 以及 ignore 判定。没有 gitleaks 时改用内置模式。是否真的泄露、如何修复由 `secret-review` 技能判断。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install git-secret-validate@jaemyeong-hwnag-plugins
brew install gitleaks    # 推荐 — 没有时使用内置模式
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| secret-review | 确认密钥 · 令牌是否被提交 · 确认 gitignore · 被钩子拦截时 · 泄露 | 区分误报 · 工作中暴露 · 泄露并处理（移到环境变量 · ignore · 吊销密钥 · 清理历史由用户决定） |
| /secret-validate | 直接调用 | 检查工作树（参数为 `history` 时检查提交历史，为路径时只检查该文件 · 目录），按条款报告 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| validate-git-secret.sh | PreToolUse (Bash) | 在 `git commit` · `git push` 将要提交的变更中发现密钥 · 敏感文件时 **拦截** |
| validate-git-secret.sh | PreToolUse (Write\|Edit\|MultiEdit) | 编辑新产生的密钥 · 敏感文件未被 ignore 时 **警告** |

## 注意事项

- 提交会被拦截，写文件只警告。向已 ignore 的 `.env` 写密钥是正常的，不提示
- 像 `git add … && git commit` 这样的单条命令尚未暂存，因此检查传给 `git add` 的路径（`.` · `-A` · `-u` 时检查全部已改文件 · 未被 ignore 的新文件）
- `git push` 只检查当前分支上任何远程都没有的提交
- 只检查 Claude 执行的命令。若要拦截在终端直接进行的提交，请另在 pre-commit 和 CI 中配置 gitleaks
- 误报可用该行的 `gitleaks:allow` 注释，或仓库根目录的 `.git-secret-allow`（每行一个 glob）排除。是否加入由用户决定
- 不检查二进制文件和超过 1MB 的文件。需要 `jq` · `git`（没有 jq 时会拦截 `git commit` · `git push`）

## 规则摘要

| 条款 | 何时 | 检查什么 | 判定 |
|---|---|---|---|
| `GS-01` | commit · push | 新增行中的密钥 | 拦截 |
| `GS-02` | commit · push | 敏感文件（`.env` · `*.pem` · `id_rsa` · `credentials.json` …） | 拦截 |
| `GS-03` | Write · Edit | 未被 ignore 的文件中的新密钥 | 警告 |
| `GS-04` | Write · Edit | 未被 ignore 或已被跟踪的敏感文件 | 警告 |
| `GS-05` | 始终 | gitleaks 缺失或失败时改用内置模式并提示 | 提示 |

原文：[`references/secret-rules.md`](references/secret-rules.md) · 模式与文件列表：[`references/secret-rules.json`](references/secret-rules.json)

## 用法

```bash
scripts/validate-git-secret.sh --all .                   # 工作树
scripts/validate-git-secret.sh --history .               # 提交历史
scripts/validate-git-secret.sh src/ config.yml           # 只检查这些路径
GIT_SECRET_ENGINE=builtin scripts/validate-git-secret.sh --all .   # 固定引擎
test/validate-git-secret.test.sh                         # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
