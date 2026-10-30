# common-performance-review

[English](README.md) · [한국어](README.ko.md) · **简体中文**

全面审查代码变更的性能 — 与语言无关。必须对 9 个类别作出判定：时间 · 空间复杂度、DB 查询（N+1 · 索引 · 分页）、网络 · IO、并发、缓存、负载、资源释放、正则表达式。检测循环内查询 · await · 无上限查询等 19 种模式并在写入时提示，给出测量方法。

本插件通过**阅读代码**发现性能风险。确定性的模式检查给出候选，技能再读取调用上下文和数据规模作出判定。对运行中的系统施加负载进行测量由 `common-stress-test` 负责 — 审查中标为 `측정필요`（需测量）的项交给它。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-performance-review@jaemyeong-hwnag-plugins
```

## 依赖

无

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| performance-review | 看看性能 · 会不会变慢 · N+1 · 复杂度 · 查询多不多 · 内存 | 模式检查 → 9 个类别必须判定 → 附带规模假设 · 置信度 · 验证方法的问题 |
| /performance-validate | 直接调用 | 在变更行（默认）或指定路径中查找 `PF-01` ~ `PF-20` 模式 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| performance-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | **提示**本次写入行中发现的模式（`PF-01` ~ `PF-20`）。不阻止 |

## 注意事项

- 模式只是**候选**。集合是否已是 Set、循环次数是否为常量、是否已批处理，需要读上下文才知道 — 由技能判定
- 循环按行估算（花括号 · Python 缩进）。经由其他函数在循环内发生的调用、延迟加载的关联访问（`order.getCustomer()`）模式看不到 — 由技能的类别判定负责
- 检查的文件：`.py` · `.java` · `.kt` · `.kts` · `.scala` · `.go` · `.js` · `.jsx` · `.mjs` · `.cjs` · `.ts` · `.tsx` · `.cs` · `.php` · `.swift` · `.rs` · `.sql`
- 不检查测试路径。要检查请加 `--include-tests`
- 有意为之的行，在该行末尾或正上方一行加 `performance-ignore` 注释
- 数字（100 ms · 100 条查询等）是出处中的示例。阈值由服务自己定
- 脚本只使用 bash · awk · jq

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `PF-01` ~ `PF-08` | 循环内 DB 调用 · 远程调用 · 顺序 await · 正则编译 · 线性查找 · 字符串累加 · 集合复制 · 重对象创建 | 警告 |
| `PF-10` ~ `PF-14` | `SELECT *` · OFFSET 分页 · 无上限查询 · 前置 `%` 的 LIKE · `ORDER BY RAND()` | 警告 |
| `PF-15` ~ `PF-20` | 异步中的阻塞 · 无超时 HTTP · 疑似 ReDoS 正则 · EAGER 关联 · 无上限缓存 · 为计数加载全部 | 警告 |
| `PF-30` ~ `PF-38` | 9 个类别 — 时间 · 空间 · 查询 · 网络 · 并发 · 缓存 · 负载 · 资源释放 · 正则 — 全部判定 | AI 判断 |
| `PF-40` ~ `PF-47` | 问题格式 · 必须有规模假设 · 严重度与置信度分开 · 变更前后对比 · 确认上下文 · 微优化为低 · 功能等价 · 缓存失效 | AI 判断 |

原文：[`references/performance-rules.md`](references/performance-rules.md) · 依据：[`references/performance-methods.md`](references/performance-methods.md)

## 用法

```bash
scripts/performance-validate.sh --diff                # 相对默认分支的变更行
scripts/performance-validate.sh --diff HEAD~3         # 指定基准
scripts/performance-validate.sh src/                  # 整个路径
scripts/performance-validate.sh --strict src/         # 有警告则 exit 2 (CI)
test/performance-validate.test.sh                     # 回归测试
```

## 依据

ISO/IEC 25010:2023 · ISO/IEC 5055 (CWE-1309) · CWE-400 · CWE-1333 · OWASP API4:2023 · Jin et al. PLDI 2012 · Chen et al. ICSE 2014 · Yang et al. ICSE 2018 · Davis et al. FSE 2018 · Infer Cost · Dean & Barroso CACM 2013 · GitLab 数据库 · MR 性能指南 · Amazon Builders' Library · Azure 性能反模式 · SWE-Perf · SWR-Bench。各项的出处与核实程度见 `references/performance-methods.md`。

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
