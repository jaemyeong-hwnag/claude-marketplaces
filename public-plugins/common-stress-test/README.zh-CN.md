# common-stress-test

[English](README.md) · [한국어](README.ko.md) · **简体中文**

定量地设计和判定负载 · 压力测试 —— 与语言无关。阻止对生产主机施加负载，检查 open 模型 · thresholds · p99，用分阶段结果计算可持续容量 · knee · USL · Little 一致性，用 Mann-Whitney U · Cliff's delta 判定回归，并提供 local · Docker · k8s 环境模板。

本插件负责不绑定语言和框架的测量方法。服务端埋点（延迟直方图 · in-flight）和使测量失效的配置由 `{语言}-{框架}-stress-test` 插件负责。这些插件依赖本插件。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-stress-test@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| stress-test-create | 编写负载 · 压力测试，k6 · locust · gatling · jmeter，"能扛多少 rps" | 测试类型选择 · open 模型 · 阶段计划 · thresholds |
| stress-result-review | 结果分析 · 瓶颈 · p99 · 性能回归 | 可持续容量 · knee · USL · Little，原因资源，两个版本的回归判定 |
| stress-environment-create | 负载测试环境 · docker compose · k8s | 分离施压机与目标 · 固定资源 · 关闭自动扩缩容 · 记录环境 |
| /stress-script-validate | 直接调用 | 用 `ST-02` ~ `ST-06` 检查项目的负载脚本 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| stress-target-validate.sh | PreToolUse (Bash) | 负载工具指向允许列表外的主机时**阻止** (`ST-01`) |
| stress-script-validate.sh | PostToolUse (Write\|Edit) | **提示**已保存的 k6 · Gatling · Locust · JMeter 脚本的测量设计 (`ST-02` ~ `ST-06`) |

## 注意事项

- 允许列表如下。
  - 回环地址、私有 IPv4
  - 不含点的名称（容器 · 服务名）
  - `*.localhost` · `*.local` · `*.test` · `*.internal` · `host.docker.internal`
- 专用测试域名放在 `.claude/settings.json` 的 `env.STRESS_TEST_ALLOWED_HOSTS` 中（逗号或空格分隔，允许 `*.perf.example.com` 形式）
- 目标主机从以下位置查找。
  - 负载命令中的 URL
  - `--host` · locust 的 `-H`
  - 名称含 `URL` · `HOST` 的变量赋值
  - 命令指向的脚本文件中的 URL
- 脚本在运行时从别处读取目标（配置服务器等）时无法看到
- 如果系统确实是 closed 模型，在脚本中加 `stress-test: closed-model` 注释。`ST-02` 警告会关闭
- 分析脚本只使用 bash · awk · jq。负载工具（k6 等）由项目安装或以 Docker 镜像运行
- SLO 值（p99 标准 · 错误率）由服务决定。文档中的 `300 ms` · `1%` 是示例

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `ST-01` | 负载目标在允许列表内 | 阻止 |
| `ST-02` | 延迟判定使用 open 模型（closed 则标注） | 警告 |
| `ST-03` | 有 thresholds · assertions | 警告 |
| `ST-04` | 报告 p99 | 警告 |
| `ST-05` · `ST-06` | k6 arrival-rate 设 `maxVUs`，不用 `sleep` | 警告 |
| `ST-10` | 阶段合格 = p99 · 错误率 · 吞吐量 · dropped | 判定 |
| `ST-11` | knee · USL 需要 6 个以上阶段 | 警告 |
| `ST-12` | dropped 阶段的延迟被低估 | 警告 |
| `ST-13` | Little's Law 一致性 | 警告 |
| `ST-20` | 回归 = Mann-Whitney U p < 0.05 · \|Cliff's delta\| ≥ 0.147 · 变差方向 | 阻止 (exit 2) |
| `ST-30` ~ `ST-35` | 稳态区间 · 合并分位数 · 分离失败延迟 · 记录环境 · 分离施压机 · 关闭自动扩缩容 | AI 判断 |

原文: [`references/stress-test-rules.md`](references/stress-test-rules.md) · 依据: [`references/stress-test-methods.md`](references/stress-test-methods.md) · 模板: [`references/stress-test-templates.md`](references/stress-test-templates.md)

## 用法

```bash
scripts/stress-step-generate.sh --header > steps.csv
scripts/stress-step-generate.sh --load 200 summary.json >> steps.csv         # k6 · Locust · JMeter · Gatling
scripts/stress-report-generate.sh --model open --slo-p99 300 steps.csv       # 容量 · knee · USL · Little
scripts/stress-regression-validate.sh baseline.txt candidate.txt              # 回归 (exit 2)
test/common-stress-test.test.sh                                               # 回归测试
```

## 依据

ISTQB 术语表 v3.2 · ISO/IEC 25010:2023 · Little (1961 · 2011) · Gunther USL · Satopää et al. 2011 (Kneedle) · Schroeder et al. NSDI 2006 · Tene 2013 (coordinated omission) · Dean & Barroso CACM 2013 · Georges et al. OOPSLA 2007 · Kalibera & Jones ISMM 2013 · Arcuri & Briand ICSE 2011 · Laaber et al. EMSE 2019 · Daly et al. ICPE 2020 · Papadopoulos et al. TSE 2019 · k6 · Prometheus 官方文档。各数值的出处和确认程度见 `references/stress-test-methods.md`。

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
