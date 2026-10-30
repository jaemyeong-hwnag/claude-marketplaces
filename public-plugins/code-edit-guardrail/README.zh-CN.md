# code-edit-guardrail

[English](README.md) · [한국어](README.ko.md) · **简体中文**

用一个项目配置强制 Claude 修改代码时不可越过的界线 —— 与语言无关。改了代码却没改测试则阻止完成；所改路径的 lint · 格式 · 类型检查命令失败则阻止完成；编辑共享资源前需用户确认。

引擎由插件钩子运行，项目中只放一个配置文件。不向项目复制脚本，因此插件更新后所有项目同步生效。

```json
{
  "test":    { "code": ["src/main/**"], "tests": ["src/test/"] },
  "quality": [{ "name": "api", "paths": ["src/**"], "command": "./gradlew ktlintCheck" }],
  "shared":  { "paths": ["db/migration/"] }
}
```

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install code-edit-guardrail@jaemyeong-hwnag-plugins --scope project
```

安装后说"帮我设置护栏"，调用 `code-edit-guardrail-apply` 生成 `.claude/code-edit-guardrail.json`。没有配置时钩子什么也不做。

需要 `jq`。没有时钩子静默放行 (fail-open)。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| code-edit-guardrail-apply | 没有测试不许结束 · 结束时跑 lint · 改迁移前先问我 · 设置护栏 | 检测技术栈，填写代码 · 测试 glob 和质量 lane；共享资源只给出候选，由用户确定 |

## 钩子

| 脚本 | 事件 | 动作 |
|---|---|---|
| code-edit-guardrail.sh reset | UserPromptSubmit | 清空本次请求的编辑记录 · 豁免 |
| code-edit-guardrail.sh shared | PreToolUse (Edit\|Write\|MultiEdit) | 命中共享资源路径 · 内容模式时**请用户确认** (`G-03`) |
| code-edit-guardrail.sh track | PostToolUse (Edit\|Write\|MultiEdit\|NotebookEdit) | 记录被修改的文件 |
| code-edit-guardrail.sh stop | Stop | 只改代码没改测试 (`G-01`)，或所改路径的质量 lane 失败 (`G-02`) 时**阻止**完成。拦过一次之后只向用户警告 (`systemMessage`) |

## 注意事项

- 判定单位是一次请求。只看 Claude 编辑工具改过的文件 —— 通过 Bash 改的文件（代码生成器 · `sed`）不看。与 git 无关
- `G-01` 只看"是否至少改了一个测试文件"。不看覆盖率
- 行为不变的修改在告知用户后豁免 —— 阻止消息中会给出豁免文件路径。豁免只对该次请求有效
- 编辑记录 · 豁免文件放在项目的 `.claude/code-edit-guardrail/`。目录自带 ignore，不会被提交
- 质量 lane 仅在本次请求修改的文件命中其 `paths` 时于 Stop 运行。使用快速检查命令，而不是完整构建 · 测试（时间限制是整个 Stop 钩子 600 秒 —— lane 依次运行）
- 项目下其他 git 工作树（`.claude/worktrees/<id>` · 嵌套仓库）中的文件，若该工作树有自己的配置，则以该工作树为根 —— 配置、glob 和 lane 执行位置都以它为准。没有自己的配置时使用项目配置
- 配置路径可用环境变量 `CODE_EDIT_GUARDRAIL_CONFIG` 修改（默认 `.claude/code-edit-guardrail.json`）
- 不处理密钥 · 代码 ↔ 文档同步

## 拦截什么

| | 条款 |
|---|---|
| 关卡（钩子） | `G-01` 测试随附 · `G-02` 质量 lane · `G-03` 共享资源确认 |
| 配置 (`validate`) | `C-01` 文件 · JSON · `C-02` 顶层键 · `C-03` 节结构 · `C-04` 正则 · `C-05` 匹配不到文件的 glob（警告） |

## 文件

| 路径 | 作用 |
|---|---|
| `references/code-edit-guardrail-rules.md` | 规则原本 —— 配置格式、glob 语法、条款、豁免 |
| `scripts/code-edit-guardrail.sh` | 四种钩子模式 + CLI `validate` |
| `test/` | 回归测试与 TC 说明 |
| `evals/` | `claude plugin eval` 用例 —— 配置技能触发 (`guardrail-config-request`) · 无测试时阻止完成 (`test-missing-blocked`) |

## 用法

```bash
scripts/code-edit-guardrail.sh validate .   # 校验配置
test/code-edit-guardrail.test.sh            # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
