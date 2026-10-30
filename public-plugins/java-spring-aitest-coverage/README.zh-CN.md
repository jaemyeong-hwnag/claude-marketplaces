# java-spring-aitest-coverage

[English](README.md) · [한국어](README.ko.md) · **简体中文**

在 Java · Spring Boot（Gradle）项目中**让 AI 修改的代码由 `@AiTest` 覆盖** —— 为变更方法生成用例矩阵测试、生成 testcontainer 测试环境，并在任务完成时对变更方法执行 JaCoCo 100% 门禁。

防止 AI 改完代码不写测试，或只写一个成功用例就宣称"完成"。判定依据是 git 本地 diff。

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install java-spring-aitest-coverage@jaemyeong-hwnag-plugins --scope project
```

安装后如果没有 `@AiTest` 环境，用"创建 AiTest 环境"调用 `aitest-environment-create`。环境建好之前门禁处于关闭状态。

需要：`git`、JDK、Docker（testcontainer）、Gradle Wrapper（`./gradlew`）。使用配置文件（`.claude/java-spring-aitest-coverage.json`）时还需要 `jq`。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| aitest-generate | 写测试、集成测试、提高覆盖率、完成被挂起 | 对每个变更方法按成功 · 失败 · 边界 · 数据状态 · 向后兼容 · 副作用 · 并发矩阵编写 `@AiTest` · `@AiWebTest` · 单元测试 → 运行 → 变更方法 100% |
| aitest-environment-create | AiTest 环境、测试基础设施、testcontainers 配置 | 读取项目，创建 test-support 模块 · `gradle/ai-test.gradle` · Docker 准备脚本 · 冒烟测试，并运行冒烟测试（经用户确认后） |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| aitest-coverage-validate.sh | UserPromptSubmit | 记录请求开始时 `src/main` · `src/test` diff 的指纹 |
| aitest-coverage-validate.sh | Stop | 若本次请求中 diff 有变化，检查变更 Controller 的 `@AiTest`（`C-01`）· 修改方法 JaCoCo 100%（`C-02`）· 报告是否最新（`C-03`）· 无法确定消费模块的 main 变更是否有 `*AiTest*` diff（`C-04`），未满足则**阻止完成**（exit 2） |

## 注意事项

- 门禁只在有 `gradle/ai-test.gradle` 或 `@interface AiTest` 的仓库中运行。否则每个会话只提示一次
- Stop 钩子不运行 Gradle，而是用**已有报告**判定。改完代码后需用 `scripts/diff-coverage-validate.sh <基准>` 刷新报告才能通过 —— 由 `aitest-generate` 完成。`<基准>` 是阻止消息给出的 ref（若在请求内已提交，用 `HEAD` 会得到空 diff 而直接通过）
- 被阻止一次后再次完成时允许通过，只留下警告（防止无限循环）。只改注释 · 格式等情况使用 `aitest: skip <原因>` 豁免 —— 门禁消息会给出 ACK 文件路径
- 支持范围：Gradle **Groovy DSL** · Spring Boot 2.x ~ 4.x · Testcontainers 1.x / 2.x · MySQL · PostgreSQL · Redis · RabbitMQ。不检查 Kotlin DSL · Maven · Kotlin 源码（`src/main/kotlin`）
- 实测组合（`test/README.md` 手动确认）

  | Boot | Gradle | JDK | Testcontainers | 结构 | 基础设施 | 已确认 |
  |---|---|---|---|---|---|---|
  | 2.5.6 | 7.2 | 11 | 1.19.7 | 单模块 | MySQL | 冒烟 → 80% FAIL → 钩子阻止 |
  | 3.3.1 | 8.8 | 17 | 1.20.4 | 多模块 + 库 | MySQL | 冒烟 → `C-01` 阻止 → 低于 100% FAIL → 100% PASS · 钩子通过 → `C-03` 阻止 |
  | 3.5.6 | 9.3.0 | 17 | 1.20.4 | 嵌套模块（`apps:api`）+ 库 · local 配置文件 | PostgreSQL · Redis · RabbitMQ | 同 3.3.1 + Redis 写入 · RabbitMQ 通道 · local 配置文件的主机被容器覆盖 |
  | 4.0.2 | 9.3.0 | 17 | 2.0.3 | 单模块 | MySQL · PostgreSQL | 冒烟 → 80% FAIL → 补充 → 100% PASS · 钩子通过 |

## 门禁条款

| 条款 | 内容 |
|---|---|
| `C-01` | 每个变更 Controller 都有覆盖该类的 `*AiTest*`（文件名以类名开头，或正文中以单词形式出现类名） |
| `C-02` | 变更行所在方法的 JaCoCo INSTRUCTION 100% |
| `C-03` | 报告比本地 diff 新 |
| `C-04` | 无法确定消费模块的 main 变更必须有 `*AiTest*` diff |
| `C-05` ~ `C-08` | 仅在本次请求中 diff 有变化时 · 无环境则关闭 · 豁免 · 防止无限循环 |

完整内容见 [`references/coverage-rules.md`](references/coverage-rules.md)。

## 项目配置

`.claude/java-spring-aitest-coverage.json` —— 可选。

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"] },
  "javaVersion": "11"
}
```

- 没有 `modules` 时使用根 `build.gradle` 的 `aiTestModules`，再没有则视为根单模块
- `libraryModules` —— core · common 等库模块变更时，用消费模块的 `aiTest` 测量，并在消费模块的报告中判定

## 文件

| 路径 | 作用 |
|---|---|
| `references/coverage-rules.md` | 规则原本 —— 约定 · 条款 · 目标模块 · 配置 · 理由 |
| `scripts/aitest-coverage-validate.sh` | 钩子 —— 指纹（`snapshot`）· Stop 门禁 |
| `scripts/diff-coverage-validate.sh` | 基于本地 diff 运行 `aiTest` + 判定（`--check-only` · `--report-only`） |
| `scripts/method-coverage-get.sh` | 每个变更方法的 JaCoCo % |
| `skills/aitest-environment-create/templates/` | test-support 模块 · Gradle · Docker 脚本骨架 |
| `skills/aitest-generate/examples.md` | 测试代码形态 · 种子数据陷阱 |
| `test/` | 脚本回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 —— 技能触发 · 门禁阻止 |

## 用法

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" <基准>               # aiTest + JaCoCo + 判定（<基准> = 阻止消息中的 ref）
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" --check-only <基准>  # 仅检查 Controller @AiTest 是否存在
test/diff-coverage-validate.test.sh                                           # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
