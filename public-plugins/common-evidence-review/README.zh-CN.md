# common-evidence-review

[English](README.md) · [한국어](README.ko.md) · **简体中文**

由没有编写上下文的验证者，依据执行证据判定 AI 所做的修改和主张是否真的必要 · 是否正确 —— 只传递去掉结论的开放式问题，先给证据 · 没有证据则无法判定，bug 主张须复现修复前失败 · 修复后通过，提示测试弱化（skip · 断言减少），修改代码后未经验证就结束则退回一次。

编写的模型重读自己的结果不算验证。而把编写者的结论给验证者看，判定就会被拉向那一边。所以验证在另一个上下文中进行，验证者不接收结论。

| 层 | 何时 | 做什么 |
|---|---|---|
| 1. 机械检查 | 每次修改测试文件时 | skip · focus 标记增加或断言减少时提示 (`E-20`) |
| 2. 独立判定 | 评审时 | 只接收原始请求 · 修改的文件 · 无结论问题的验证者，逐个修改判定必要性 · 正确性 (`E-01` ~ `E-11`) |
| 3. 完成关卡 | 请求结束时 | 修改了代码 · 配置却跳过了第 2 层，则退回一次 (`E-30`) |

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-evidence-review@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| evidence-review | 真的需要吗？ · 事实核查 · 帮我验证 · 确认对不对 · 不必要的修改 | 把主张转成无结论的开放式问题交给验证者，按判定修复 · 回退 · 标记 `미확인`（未确认）。重新验证上限 2 次 |
| /evidence-validate | 手动调用 | 在相对默认分支的修改及未跟踪的文件中查找测试弱化信号 (`E-20`)。带 `--strict` 时有信号则 exit 2 |

## 代理

| 代理 | 说明 |
|---|---|
| evidence-reviewer | 只接收原始请求 · 修改的文件 · 问题。对每个修改按证据 → 判定的顺序给出必要性（`필요함` 必要 · `불필요함` 不必要 · `판정 불가` 无法判定）和正确性（`맞음` 正确 · `틀림` 错误 · `판정 불가` 无法判定）。不修改代码，修改前的行为在临时 worktree 中运行 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| evidence-validate.sh | UserPromptSubmit | 记录原始请求。这是关卡交给验证者的基准 |
| evidence-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | 记录修改的文件 · 行数，若是测试文件则**提示** `E-20` 信号 |
| evidence-validate.sh | PostToolUse (Agent\|Task) | `evidence-reviewer` 同步结束则标记为已验证，在后台启动则标记为验证中 |
| evidence-validate.sh | SubagentStop | 后台 `evidence-reviewer` 结束时标记为已验证 |
| evidence-validate.sh | Stop | 修改了代码 · 配置却未验证，则退回结束一次 (`E-30`)。退回消息包含修改的文件 · 请求记录 · 最终回答中的主张候选。后台 `evidence-reviewer` 验证中时不拦截 |

## 注意事项

- **不要把编写者的理由 · 摘要 · 提交信息传给验证者。** 即使附上"请忽略"，判定仍会被拉偏。
- 验证者以 `sonnet` 运行。与编写者不同的模型可减少自我偏好偏差。
- 验证者会运行测试 · 脚本。需要有运行项目命令的权限，否则判定会落为 `판정 불가`（无法判定）。
- `불필요함`（不必要）的意思是"不对应请求中的任何一句，回退也不会破坏任何东西"。若用户可能想要该修改，技能会在回退前询问。
- 完成关卡
  - 仅当一个请求在项目内修改了 3 行以上的代码 · 配置时运行。用 `EVIDENCE_REVIEW_MIN_LINES` 更改。
  - 文档（`.md` 等）不计入 —— 那是 `common-document-slop-review` 的职责。`requirements.txt` · `CMakeLists.txt` 这类配置计入。
  - 用 Bash 修改的文件钩子看不到。
  - 一个请求中不会拦截两次。但验证后再次修改，会按该修改重新判定。关闭用 `EVIDENCE_REVIEW_GATE=0`
- `E-20` 是提示。测试可能是有意修改的，所以不拦截。
- 脚本使用 bash · jq · grep，`--diff` 使用 git。没有 jq 时钩子静默通过。

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `E-01` ~ `E-03` | 由另一上下文验证 · 不传递结论 · 主张转为开放式问题 | AI（技能） |
| `E-04` ~ `E-09` | 先给证据 · 必要性 · 正确性 · bug 靠复现 · 检查测试本身 · 禁止编造的指摘 | AI（代理） |
| `E-10` | 验证者不修改工作树 | AI（代理） |
| `E-11` | 错误则修复 · 不必要则回退 · 无法判定则标 `미확인` · 重新验证 2 次 | AI（技能） |
| `E-20` | 测试文件中 skip · focus 标记增加 · 断言减少 | 提示 |
| `E-30` | 修改了代码 · 配置的请求未经验证就结束则退回一次 | 关卡 |

原文：[`references/evidence-rules.md`](references/evidence-rules.md) · 依据：[`references/evidence-methods.md`](references/evidence-methods.md)

## 用法

```bash
scripts/evidence-validate.sh --diff            # 相对默认分支的测试弱化信号
scripts/evidence-validate.sh --diff --strict   # 有信号则 exit 2 (CI)
test/evidence-validate.test.sh                 # 回归测试
```

## 依据

| 条款 | 依据 |
|---|---|
| 自我验证无效 | Huang et al. ICLR 2024 · Kamoi et al. TACL 2024 · Self-Correction Bench |
| 不传递结论 | 锚定 CIKM 2026 · 安全代码评审中的上下文偏差 · Chain-of-Verification · sycophancy |
| 先给证据 · 无法判定 | CRITIC · Wang et al. ACL 2024 · Anthropic evals |
| 分离必要性 | 过度编辑 EMNLP 2026 · "Solved Issues" ICSE 2026 |
| 复现 | SWT-Bench · Agentless · SWE-Doctor · Refute-or-Promote |
| 测试弱化 | ImpossibleBench · SWE-Bench+ · Anthropic 长时运行 harness |
| 单一验证者 | 多代理辩论对比研究 (ICML 2024 · NeurIPS 2025) |

各项的出处 · 确认程度见 `references/evidence-methods.md`。

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
