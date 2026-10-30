# common-document-slop-review

[English](README.md) · [한국어](README.ko.md) · **简体中文**

每当 AI 创建或修改文档时拦截 slop —— 对话残留、占位符、聊天机器人标记、失效链接直接阻止；无出处的说法、无日期的时间表述、无依据的数字、套话、格式过度则提示。在修改过文档的会话结束时，要求进行一次将说法与文件、代码、链接对照的审查。

检查分三层。

| 层 | 时机 | 对象 | 做什么 |
|---|---|---|---|
| 1. 机械检查 | 每次写文档 | 本次写入的行 | 阻止明显痕迹，提示文风信号 |
| 2. 判断审查 | 审查时 | 整个文档 | 检查内容是否正确、必要、有条理 |
| 3. 完成门禁 | 会话结束时 | 该会话中修改的文档 | 若跳过了第 2 层，退回一次 |

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-document-slop-review@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| document-slop-review | 审查文档 · 看看 README · 核对事实 · 有没有错 · 多余内容 · slop | 机械检查 → 无写作上下文的事实核对 → 判定可删句子、重复、结构、格式、术语 → 只修缺陷 |
| /document-slop-validate | 直接调用 | 在变更的行（默认）或指定路径中查找 `DS-01` ~ `DS-16` |

## 代理

| 代理 | 说明 |
|---|---|
| document-slop-reviewer | 只接收文档路径，提取事实性说法并与仓库文件、命令、链接对照。判定为 `확인함`（已确认）· `틀림`（错误）· `미확인`（未确认）。不修改文档 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| document-slop-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | 在本次写入的行中**阻止** `DS-01` ~ `DS-04`（exit 2），**提示** `DS-05` ~ `DS-16` |
| document-slop-validate.sh | PostToolUse (Skill\|Agent\|Task) | `document-slop-review` 或 `document-slop-reviewer` 运行后清除门禁记录。后台启动的 `document-slop-reviewer` 标记为审查中 |
| document-slop-validate.sh | SubagentStop | 后台 `document-slop-reviewer` 结束时清除门禁记录 |
| document-slop-validate.sh | Stop | 修改了文档却未审查时，退回一次结束（`DS-30`） |

## 注意事项

- **不判定"是否由 AI 写成"。** 只指出可修正的模式及其所在行。人写的文字有同样模式也会被标出。
- 只阻止四种明显痕迹：对话残留、占位符、聊天机器人引用标记、指向不存在路径的相对链接。
- 警告只是候选。由技能做判定。
- 依据类警告（`DS-05` ~ `DS-07`）**不是要求删除。** 补上出处或标注 `미확인`（未确认）即可通过。为求简洁而删掉依据反而会降低准确性。
- 检查的文件：`.md` · `.mdx` · `.markdown` · `.rst` · `.txt` · `.adoc`
  - `requirements*.txt` · `constraints*.txt` · `*-lock.txt` · `CMakeLists.txt` · `robots.txt` · `LICENSE*` 不检查（不区分大小写）。
- 不检查的部分：front matter、代码围栏、行内代码、引用（`>`）、HTML 注释（含多行）、超过 4000 字节的行
- 有意保留的行，在该行或上一行放 `<!-- document-slop-ignore -->`。
- 韩语词表（`DS-10`）的依据弱于英语。因此只在 3 个以上不同的词聚集时提示。
- 完成门禁只在项目内文档一次修改 3 行以上时记录。
  - 同一请求中不会阻止两次。
  - 关闭：`DOCUMENT_SLOP_REVIEW_GATE=0`
- 脚本使用 bash · awk · jq，`--diff` 和目录列表使用 git。没有 jq 时钩子静默放行。

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `DS-01` ~ `DS-04` | 对话残留 · 占位符 · 聊天机器人标记 · 失效相对链接 | 阻止 |
| `DS-05` ~ `DS-07` | 没有出处的出处表述 · 无日期的时间表述 · 无依据的数字 | 警告 |
| `DS-08` ~ `DS-13` | 元叙述 · 结尾总结节 · 过度使用的词汇聚集 · 重复的对比句式 · 夸张词汇 · 叠加的模糊限定 | 警告 |
| `DS-14` ~ `DS-16` | 格式过度 · 标题层级跳跃 · 同一句重复 | 警告 |
| `DS-20` ~ `DS-27` | 事实核对 · 可删句子 · 相关性 · 重复 · 结构 · 格式适配 · 读者成本 · 术语一致性 | AI 判断 |
| `DS-30` | 修改过文档的会话未经审查就结束时退回一次 | 门禁 |

原文：[`references/document-slop-rules.md`](references/document-slop-rules.md) · 模式：[`references/document-slop-patterns.json`](references/document-slop-patterns.json) · 依据：[`references/document-slop-methods.md`](references/document-slop-methods.md)

## 用法

```bash
scripts/document-slop-validate.sh --diff              # 相对默认分支变更的行
scripts/document-slop-validate.sh --diff origin/main  # 相对指定基准变更的行
scripts/document-slop-validate.sh docs/ README.md     # 整个路径
scripts/document-slop-validate.sh --strict docs/      # 有警告也 exit 2（CI）
test/document-slop-validate.test.sh                   # 回归测试
```

## 依据

| 条款 | 依据 |
|---|---|
| 阻止标准 | Wikipedia 快速删除标准 G15 · Signs of AI writing |
| 词典定义 | Merriam-Webster · Macquarie · American Dialect Society 的 2025 年度词汇 |
| slop 分类 | Shaib et al. 2025 · Kommers et al. 2025 |
| 过度使用的词汇 | Kobak et al. 2025 · Liang et al. 2024 · Antislop (ICLR 2026) |
| 事实核对 | FActScore · SAFE · Chain-of-Verification · Huang et al. ICLR 2024 |
| 文档规范 | GitLab · Grafana 文档风格指南，Anthropic · OpenAI 的写作指南 |
| 成本 | workslop (HBR 2025) |

各项的出处和确认程度见 `references/document-slop-methods.md`。

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
