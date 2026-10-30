# project-completeness

[English](README.md) · [한국어](README.ko.md) · **简体中文**

衡量并补齐项目作为服务应具备的东西 —— 自动探测仓库，用 69 项清单诊断风险 · 实践范围；按配方应用配置 · CI 后验证 · 回滚；用实测值判定 DORA · SLO · 值班 18 项指标。不靠猜测通过。

有的服务拿到 linter A 级评分，却由开发者打开数据库处理每一个客户咨询。代码质量工具不看空状态 · 退款路径 · 备份恢复 · 值班 · 回滚。本插件把这些问题也纳入，分别衡量**有没有**（清单）和**好不好用**（实测指标）。

```
completeness-review      诊断（只读）          → 风险 + 实践范围 + 最空缺的轴
completeness-apply       按配方配置 · CI        → 验证 → 失败则回滚
service-health-review    实测数值              → 按指标判定 + 未测量列表
```

## 安装

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install project-completeness@jaemyeong-hwnag-plugins --scope project
```

需要：`bash`、`jq`、`find`、`grep`。应用配方时还需要该配方的工具（Node · Python · Go 工具链、Docker 等）。

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| completeness-review | 完成度检查 · 质量诊断 · 先引入什么 | `detect` → 选择测量范围 → 按 ⚡ 自动 · ▶️ 运行 · 💬 提问判定 → `score` |
| completeness-apply | 帮我应用 · 接入 CI · 引入 linter | 每次一个轴：配方 → 计划确认 → 应用 → 验证 → 失败则回滚。不提交 |
| service-health-review | 服务健康度 · DORA · 值班 · 告警疲劳 | 只收集已知值，用 `health` 判定。未测量的指标单独报告 |

## 注意事项

- **不靠猜测通过。** 无法确认的项目计为未通过 —— 分数偏低是正常的
- `detect` 的 `hints` 不是判定。即使源码里有 `refund`，它是否是可用的退款路径，要读代码或询问后再定
- **风险和实践范围是不同的问题。** 具备 12 项核心的库，即使范围只有 20% 也不危险
- 语言配方只有 Node · Python · Go。Java · Kotlin 能被探测，但只适用通用 · 运维 · 服务配方
- 配方中的版本 · 配置格式会过时。若已安装版本的格式不同，技能会停下并告知
- `completeness-apply` 会修改文件但不提交。首次引入的检查不会让 CI 失败（密钥 · Critical 漏洞除外）

## 衡量内容

| 轴 | 项目 | 核心 | 示例 |
|---|---:|---:|---|
| `code` 代码 | 10 | 2 | CI 强制 linter · 新代码门禁 · CODEOWNERS · 架构边界 |
| `test` 测试 | 7 | 1 | 覆盖率 · 变异测试 · 核心流程 E2E · 真实数据库集成 |
| `security` 安全 | 8 | 3 | 密钥扫描 · SAST · SCA + SBOM · 依赖自动更新 |
| `perf` 性能 | 7 | 0 | Core Web Vitals · 性能 · 包体积预算 · 负载测试 |
| `ux` 无障碍 · UX | 6 | 0 | axe 违规为 0 · 手动屏幕阅读器 · WCAG 2.2 |
| `ops` 运维 | 7 | 3 | 链路追踪 · SLO · 值班 · 运行手册 · 回滚 · 事后复盘 |
| `service` 服务完成度 | 19 | 3 | 空 · 错误 · 加载状态 · 退款路径 · 运营工具 · 备份恢复 · 渲染冒烟 · 规格 ↔ 实现 |
| `product` 产品 · 组织 | 5 | 0 | 漏斗 · 实验 · DORA 采集 · DevEx |

按项目类型（`backend-api` · `library` · `cli` …）结构上不适用的项目以 N/A 排除。

## 文件

| 路径 | 作用 |
|---|---|
| `references/completeness-rules.md` | 规则原本 —— 判定原则 `Q-01` ~ `Q-07`、应用原则 `Q-11` ~ `Q-19`、门禁阶段、轴顺序、配方格式 |
| `references/completeness-checklist.json` | 项目 · 核心 · 测量方式 · 各项目类型的 N/A · 等级边界 |
| `references/service-health-metrics.json` | 健康度指标 · 基准 |
| `references/recipe-*.md` | 引入配方 —— 通用 · Node · Python · Go · 运维 · 服务 |
| `scripts/project-completeness.sh` | `detect` · `scope` · `score` · `health` · `recipe` |
| `test/` | 回归测试与 TC 规格 |
| `evals/` | `claude plugin eval` 用例 —— 诊断技能触发（`completeness-request`） |

## 用法

```bash
S=scripts/project-completeness.sh
$S detect .                                          # 仓库痕迹 → JSON
$S scope --type backend-api                          # 可测量的项目
$S score --type backend-api --pass code.lint-ci,security.secret-scan --na code.ai-provenance
$S health cfr=8 recovery=45 pages_week=12            # 无参数时列出指标
$S recipe security.secret-scan                       # 补齐该项目的配方
test/project-completeness.test.sh                    # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
