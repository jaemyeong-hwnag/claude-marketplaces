# kotlin-spring-aitest-coverage

[English](README.md) · [한국어](README.ko.md) · **简体中文**

在 Kotlin · Spring Boot（Gradle Kotlin DSL）项目中**让 AI 修改的代码由 `@AiTest` 覆盖** —— 为变更方法生成用例矩阵测试、生成 testcontainer 测试环境，并在任务完成时对变更方法执行 JaCoCo 100% 门禁。

防止 AI 改完代码不写测试，或只写一个成功用例就宣称"完成"。判定依据是 git 本地 diff。

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install kotlin-spring-aitest-coverage@jaemyeong-hwnag-plugins --scope project
```

安装后如果没有 `@AiTest` 环境，用"创建 Kotlin AiTest 环境"调用 `kotlin-aitest-environment-create`。环境建好之前门禁处于关闭状态。

需要：`git`、JDK（含 `javap`）、Docker（testcontainer）、Gradle Wrapper（`./gradlew`）。使用配置文件（`.claude/kotlin-spring-aitest-coverage.json`）时还需要 `jq`。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| kotlin-aitest-generate | 写测试、集成测试、提高覆盖率、完成被挂起 | 对每个变更方法按成功 · 失败 · 边界 · 数据状态 · 向后兼容 · 副作用 · 并发矩阵，用 Kotlin（构造器注入 · MockK · `runTest` · 反引号名称）编写 `@AiTest` · `@AiWebTest` → 运行 → 变更方法 100% |
| kotlin-aitest-environment-create | Kotlin AiTest 环境、测试基础设施、testcontainers 配置 | 读取项目，创建目标模块 `build.gradle.kts` 中的 `aiTest` 块 · Kotlin 支持模块 · Docker 准备脚本 · 冒烟测试，并运行冒烟测试（经用户确认后） |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| aitest-coverage-validate.sh | UserPromptSubmit | 记录请求开始时 `src/main` · `src/aiTest` diff 的指纹 |
| aitest-coverage-validate.sh | Stop | 若本次请求中 diff 有变化，检查变更 Controller 的 aiTest（`C-01`）· 变更方法 JaCoCo 100%（`C-02`）· 报告是否最新（`C-03`）· 无法确定消费模块的 main 变更是否有 aiTest diff（`C-04`）· 判定工具（`C-09`），未满足则**阻止完成**（exit 2） |

## 注意事项

- 门禁只在 `build.gradle.kts` 中有 `// >>> kotlin-spring-aitest-coverage` 块的仓库中运行。否则每个会话只提示一次。在 Gradle Groovy DSL 仓库中什么都不做
- Stop 钩子不运行 Gradle，而是用**已有报告和类文件**判定。改完代码后需用 `scripts/diff-coverage-validate.sh <基准>` 刷新报告才能通过 —— 由 `kotlin-aitest-generate` 完成。`<基准>` 是阻止消息给出的 ref（若在请求内已提交，用 `HEAD` 会得到空 diff 而直接通过）
- 变更行属于哪个方法，由类文件的行号表（`javap`）决定。没有 `javap` 或类文件时，以无法判定为由阻止
- 被阻止一次后再次完成时允许通过，只留下警告（防止无限循环）。只改注释 · 格式等情况使用 `aitest: skip <原因>` 豁免 —— 门禁消息会给出 ACK 文件路径（`<Gradle 根>/.claude/kotlin-spring-aitest-coverage/`）
- 只检查 `.kt`。`.java` 由 `java-spring-aitest-coverage` 检查 —— 两个版本同时安装时状态 · 配置 · 技能名称互不重叠。同一模块不能同时放两个版本的 `aiTest` 环境
- 支持范围：Kotlin 2.x · Spring Boot 3.1 ~ 4.x · Gradle 8 · 9（Kotlin DSL）· JDK 17+ · MockMvc · MySQL · PostgreSQL · Redis · RabbitMQ。不检查 WebFlux（`WebTestClient`）· Groovy DSL · Maven · Boot 2
- 实测组合（`test/README.md` 手动确认）

  | Boot | Gradle | Kotlin | JDK | Testcontainers | 结构 | 基础设施 | 已确认 |
  |---|---|---|---|---|---|---|---|
  | 3.5.16 | 8.14.4 | 2.2.21 | 17 | 1.21 (Boot BOM) | 多模块 + 库 | PostgreSQL | 环境生成 → 冒烟 → 阻止 → 75% FAIL → 100% PASS · 钩子通过 · 库 `C-04` · `C-03` · `C-02` |
  | 4.1.1 | 9.8.0 | 2.4.21 | 17 | 2.0.5 (Boot BOM) | 单模块 · 包 ≠ 目录 | MySQL · Redis | 环境生成 → 冒烟 → 阻止（与文件名不同的 Controller）→ 50% FAIL → 100% PASS（含 `suspend`）· 钩子通过 · `C-03` · 仅变更 aiTest |

## 门禁条款

| 条款 | 内容 |
|---|---|
| `C-01` | 每个变更 Controller（`@RestController` · `@Controller`）的类名出现在 `src/aiTest/kotlin` 正文中 |
| `C-02` | 变更行所在方法的 JaCoCo INSTRUCTION 100% —— 排除 `@JvmStatic` 桥接 · 同一行的 `$default` · 主构造器行的访问器 |
| `C-03` | 报告比本地 diff 新 |
| `C-04` | 无法确定消费模块的 main 变更必须有 aiTest diff |
| `C-05` ~ `C-08` | 仅在本次请求中 diff 有变化时 · 无环境则关闭 · 豁免 · 防止无限循环 |
| `C-09` | 缺少判定工具（`javap` · 类文件）时以无法判定为由阻止 |

完整内容见 [`references/coverage-rules.md`](references/coverage-rules.md)。

## 项目配置

`.claude/kotlin-spring-aitest-coverage.json` —— 可选。

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"] },
  "jdkVersion": "17"
}
```

- 没有 `modules` 时使用含环境块的 `build.gradle.kts` 所在模块，再没有则视为根单模块
- `libraryModules` —— core · common 等库模块变更时，用消费模块的 `aiTest` 测量，并在消费模块的报告中判定

## 文件

| 路径 | 作用 |
|---|---|
| `references/coverage-rules.md` | 规则原本 —— 约定 · 条款 · 变更行 → 方法 · 目标模块 · 配置 · 理由 |
| `scripts/aitest-coverage-validate.sh` | 钩子 —— 指纹（`snapshot`）· Stop 门禁 |
| `scripts/diff-coverage-validate.sh` | 基于本地 diff 运行 `aiTest` + 判定（`--check-only` · `--report-only`） |
| `scripts/method-coverage-get.sh` | 每个变更方法的 JaCoCo %（`javap` 行号表） |
| `skills/kotlin-aitest-environment-create/templates/` | Gradle 块 · 支持模块 · Docker 脚本骨架 |
| `skills/kotlin-aitest-generate/examples.md` | 测试代码形态 · 种子数据陷阱 |
| `test/` | 脚本回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 —— 技能触发 · 门禁阻止 |

## 用法

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" <基准>               # aiTest + JaCoCo + 判定（<基准> = 阻止消息中的 ref）
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" --check-only <基准>  # 仅检查 Controller aiTest 是否存在
test/diff-coverage-validate.test.sh                                           # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
