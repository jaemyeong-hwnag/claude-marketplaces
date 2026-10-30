# domain-document-sync

[English](README.md) · [한국어](README.ko.md) · **简体中文**

将领域知识文档按**三层**（目录 `_index` → 领域元信息 `_meta` → 概念 concept）组织，并与代码保持同步 —— 通过与语言 · 框架无关的代码分析生成文档、只读取需要的领域、注入编辑约定、代码变更时的文档同步门禁。

哪段代码属于哪个领域，不由脚本决定，而由各领域 `_meta.md` 前置元数据中的 `code:` glob 说明。因此无论 Java · TypeScript · Python · Go …，无论单体仓库还是单模块，都按同一套规则运行。

```
docs/domain/
  _index.md            # 目录 —— 每个领域 1 行，触发词（用语 · 标识符 · 路径 · 症状）
  order/
    _meta.md           # code: glob · 关系 · 分部表（何时看哪个文件）
    entities.md        # concept —— 规则 · 实体 · 流程
    flows.md
```

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install domain-document-sync@jaemyeong-hwnag-plugins --scope project
```

安装后如果没有文档，用"创建领域文档"调用 `domain-document-create`。文档根目录不存在期间，钩子什么都不做。

需要：`git`、`jq`。缺少时钩子静默放行（fail-open）。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| domain-document-get | 领域规则 · 哪个领域 · 受影响的领域 | 按 `_index → _meta → concept` 顺序只读取需要的部分 |
| domain-document-create | 创建领域文档 · 整理领域 · 新领域 | 与语言无关地分析代码库，划分领域并创建三层文档 |
| domain-document-update | 更新文档 · 同步门禁阻止 | 把代码变更反映到 concept，仅在有变化时调整 `_meta` · `_index`。豁免流程 |
| /domain-document-validate | 直接调用 | 校验文档树（`D-01` ~ `D-08`）+ 各领域的代码映射 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| domain-document-sync.sh session | SessionStart | 文档根目录存在时**注入**目录位置 · 领域列表 · 阅读顺序。清理超过 7 天的状态文件 |
| domain-document-sync.sh snapshot | UserPromptSubmit | 在请求开始时保存各领域的代码 · 文档指纹，并清除过去的豁免 |
| domain-document-sync.sh pre-edit | PreToolUse (Edit\|Write\|MultiEdit) | 编辑文档根目录时**注入**三层约定（按目录 · 元信息 · concept · 新领域区分） |
| domain-document-sync.sh post-edit | PostToolUse (Edit\|Write\|MultiEdit) | concept 超过 300 行（`D-07`）或不在 `_meta` 分部表中（`D-05`）时**提示** |
| domain-document-sync.sh stop | Stop | 本次请求中代码有变更的领域若没有文档变更则**阻止**完成（`S-01`）。阻止一次后只警告 |

## 注意事项

- `S-01` 以请求开始时的 HEAD 为基准，按工作树（变更 + untracked）判定。请求内提交也能捕获，只提问的请求不会被阻止。文档也必须在本次请求中有变更
- 项目下的工作树（`.claude/worktrees/{x}` 等）也按各自的工作树判定
- 状态 · 豁免文件放在项目的 `.claude/domain-document-sync/` —— 自行忽略，在 Bash 沙箱内也能写入
- 领域知识不变的变更（重构 · 测试 · 格式）在告知用户后豁免 —— 阻止消息会给出豁免文件路径。豁免只对该请求有效
- `code:` 写得过宽（`src/**`）会让所有变更都要求该领域的文档。用 `map` 查看匹配的文件数并收窄
- 路径可以包含韩文 · 空格。通过符号链接进入的项目路径也能识别
- 配置放在项目 `.claude/settings.json` 的 `env` 中 —— `DOMAIN_DOCUMENT_ROOT`（默认 `docs/domain`）、`DOMAIN_DOCUMENT_MAX_LINES`（默认 `300`）

## 阻止什么

| | 条款 |
|---|---|
| 文档树（`validate`） | `D-01` 根目录 · `_index.md` · `D-02` 每个领域的 `_meta.md` · `D-03` slug 为 kebab-case · `D-04` 登记在目录中 · `D-05` 登记在元信息分部表中 · `D-06` 相对链接 |
| 警告 | `D-07` concept 300 行 · `D-08` 匹配不到文件的 `code:` glob |
| 同步（Stop 钩子） | `S-01` 领域代码变更时，该领域文档也要变更 |

## 文件

| 路径 | 作用 |
|---|---|
| `references/domain-document-rules.md` | 规则原本 —— 三层、条款、`code:` glob 语法、门禁行为、读 · 写流程、配置 |
| `references/templates.md` | `_index` · `_meta` · concept 骨架，concept 拆分方法 |
| `scripts/domain-document-sync.sh` | 五种钩子模式 + CLI `validate` · `map` |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 —— 领域查询顺序（`domain-lookup`）· 文档编辑约定注入（`edit-protocol-injected`） |

## 用法

```bash
scripts/domain-document-sync.sh validate .   # 校验文档树
scripts/domain-document-sync.sh map .        # 领域 → code glob → 匹配的文件数
test/domain-document-sync.test.sh            # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
