# common-design-soundness-review

[English](README.md) · [한국어](README.ko.md) · **简体中文**

由没有编写上下文的验证者在实现前判定软件设计（结构 · 流程 · 决策）是否前后一致——对象是计划模式的计划 · 对话中的设计方案 · 设计文档。先给出设计摘要，再检查依据 · 反驳、矛盾 · 展开、流程的阻塞与不服务于任何需求的步骤，以及每条需求对应的决策。未经审查就退出计划模式，或修改设计文档后直接结束，会被退回一次。

UI · 视觉设计不在范围内。安装到其他项目中，在工作中做设计时使用。

设计者重读自己的设计不算审查。因此判定由不了解形成设计之对话的验证者做出，验证者只接收设计文件 · 需求来源 · 不含结论的问题。

| 层 | 何时 | 做什么 |
|---|---|---|
| 1. 机械检查 | 编写设计文档时 · 退出计划模式时 | 提示必需章节 · mermaid 流程可达性 · 需求 ID · 没有数字的质量需求 · 定义前使用的术语（`DD-20` ~ `DD-24`） |
| 2. 独立判定 | 技能调用时 | 验证者给出设计摘要后，以引用判定论证 · 反驳 · 矛盾 · 展开 · 流程健全性 · 流程适当性 · 需求契合 · 决策记录（`DD-01` ~ `DD-15`） |
| 3. 闸门 | 即将进入实现之前 | 阻止一次退出计划模式（`DD-31`），退回一次修改了设计文档 3 行以上的请求的结束（`DD-30`），在设计请求后的首次代码编辑时提示（`DD-32`） |

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-design-soundness-review@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| design-soundness-review | 帮我设计 · 搭一下结构 · 设计流程 · 审查设计 · 前后一致吗？ · 这个设计行吗？ | 把设计固定为文件，找到需求来源（没有则从设计中提取并请用户确认），以不含结论的问题交给验证者。自己的设计按判定修改（最多复审 2 次），他人的设计给出报告和要问设计者的问题 |
| /design-soundness-validate | 直接调用 | 在设计文档 · 计划文件（`--plan`）中查找 `DD-20` ~ `DD-24`。加 `--strict` 时有信号则 exit 2 |

## 代理

| 代理 | 说明 |
|---|---|
| design-soundness-reviewer | 只接收设计文件 · 需求来源 · 问题。给出设计摘要（组件 · 决策 · 流程表 · 需求 ↔ 决策）后，按视角给出引用 → 判定（`결함`（缺陷）· `빈 곳`（空缺）· `판정 불가`（无法判定））。不修改设计 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| design-soundness-validate.sh | UserPromptSubmit | 记录请求原文（需求来源）。含设计信号词时标记为设计请求 |
| design-soundness-validate.sh | PreToolUse (ExitPlanMode) | 未经审查退出计划模式时**阻止**一次，并提示计划文件 · 机械信号（`DD-31`） |
| design-soundness-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | 若是设计文档，**提示**新的机械信号。若是设计请求后的首次代码编辑，提示进行审查（`DD-32`） |
| design-soundness-validate.sh | PostToolUse (Agent\|Task) | `design-soundness-reviewer` 同步结束则标记为已审查，在后台启动则标记为审查中 |
| design-soundness-validate.sh | SubagentStop | 后台 `design-soundness-reviewer` 结束时标记为已审查。审查中，计划模式闸门对相同计划也会阻止 |
| design-soundness-validate.sh | Stop | 修改了项目内设计文档 3 行以上却未审查时，退回一次结束（`DD-30`） |

## 注意事项

- **不要把形成设计的对话 · 理由交给验证者。** 对话中的设计方案只把方案本身移到临时文件后交出。
- 验证者以 `sonnet` 运行。这是为了使用与设计者不同的模型（与 `common-evidence-review` 相同）。
- 没有需求来源时，需求契合与流程适当性为 `판정 불가`（无法判定）。技能从设计中提取需求并得到确认后即可判定。
- 设计文档是 `.md` · `.mdx` · `.markdown` 文件，按路径（`adr/` · `adrs/` · `decisions/` · `rfc/` · `rfcs/` · `design/` · `designs/`，`*-design.md` · `*-rfc.md`）或前 20 行中的 `<!-- design-document -->` 判别。在 `DESIGN_SOUNDNESS_PATHS` 中给出以逗号分隔的 glob 时，用它代替默认路径。
- 机械信号只是候选，不阻止。同一文件中已提示过的信号不再提示。若某行是有意为之，在该行或上一行加 `<!-- design-soundness-ignore -->`。
- `DD-24` 仅在术语章节位于决策章节之前或没有决策章节时检查——文档末尾的术语表仅供参考。韩语术语按子串查找。
- `DD-22` 的需求 ID 可用 `DESIGN_SOUNDNESS_REQUIREMENT_ID` 更改（默认 `(R|FR|NFR|QA|REQ)-[0-9]+`）。
- `DD-21` 只看 mermaid 的边。不看嵌套状态 · `--x` · `--o` · `---` 边。
- 计划模式闸门
  - 以相同计划再次退出时不阻止。但后台验证者仍在判定时，相同计划也会被阻止。`DESIGN_SOUNDNESS_PLAN_GATE=0` 只关闭这一项。
  - `claude -p`（非交互）中没有 `ExitPlanMode` 工具，因此不运行（2026-10-30，在 Claude Code 2.1.314 中确认）。
- `DESIGN_SOUNDNESS_GATE=0` 关闭全部三个闸门。机械信号照常提示。
- 对话中的设计不阻止，只提示。机器无法区分设计到哪里为止。
- 修改设计文档时，`common-document-slop-review` 的闸门也可能一起运行。两个审查一起运行可以一次结束。
- 脚本使用 bash · awk · jq。没有 jq 时钩子静默通过。

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `DD-01` · `DD-02` | 由另一个上下文判定 · 只交出设计文件 · 需求来源 · 问题 | AI（技能） |
| `DD-03` · `DD-15` | 确定需求来源（没有则提取后确认） · 先给设计摘要 | AI |
| `DD-04` · `DD-05` | 论证结构 · 每个核心决策 2 个反驳 | AI（代理） |
| `DD-06` · `DD-14` | 矛盾 · 术语 · 展开 | AI（代理） |
| `DD-07` · `DD-13` | 流程健全性 · 适当性（不服务于需求的步骤、与替代方案的比较） | AI（代理） |
| `DD-08` · `DD-09` | 每个需求场景对应的决策 · 决策的替代方案 · 确认方法 | AI（代理） |
| `DD-10` ~ `DD-12` | 先引用 · 禁止编造问题 · 自己的设计修改，他人的设计给报告和问题 | AI |
| `DD-20` ~ `DD-24` | 必需章节 · 流程可达性 · 需求 ID · 没有数字的质量需求 · 定义前术语 | 提示 |
| `DD-30` | 修改设计文档的请求未经审查结束时退回一次 | 闸门 |
| `DD-31` | 未经审查退出计划模式时阻止一次 | 闸门 |
| `DD-32` | 设计请求后的首次代码编辑时提示 | 提示 |

原文：[`references/design-soundness-rules.md`](references/design-soundness-rules.md) · 依据：[`references/design-soundness-methods.md`](references/design-soundness-methods.md)

## 使用

```bash
scripts/design-soundness-validate.sh docs/adr/0003-cancel.md          # 设计文档的机械信号
scripts/design-soundness-validate.sh --plan ~/.claude/plans/x.md      # 计划
scripts/design-soundness-validate.sh --strict docs/adr/*.md           # 有信号则 exit 2（CI）
test/design-soundness-validate.test.sh                                # 回归测试
```

## 依据

| 条款 | 依据 |
|---|---|
| 用场景检查需求契合 | ATAM (ICECCS 1998) · 基于场景的评估比较 (APSEC 2004) · arc42 质量场景 |
| 决策单元 · 确认方法 | DCAR (IEEE Software 2014) · MADR 4.0.0 · 适应度函数 (Thoughtworks Radar) |
| 主张 · 反驳 | SACM 2.3 · 以消除的疑点衡量置信度 (ASSURE 2013) · LLM 反驳生成 (ISSRE 2024) · pre-mortem (HBR 2007) |
| 矛盾 · 不一致 | 规格不一致管理 (TOSEM 1998 · RE 1995) · LLM 需求不一致检测 (RE 2023) |
| 流程 | 工作流健全性 (TU/e 2008) · 多视图一致性 · AWS TLA+ (CACM 2015) |
| 他人的设计 | ARID (SEI 2000) · 审查 (IBM Systems Journal 1976) |
| 另一个上下文 · 不含结论的输入 | 与 `common-evidence-review` 的依据相同 |

各项的出处 · 确认程度，以及"选择"（没有直接依据而沿用或自定的部分）见 `references/design-soundness-methods.md`。

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
