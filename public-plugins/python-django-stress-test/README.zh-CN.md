# python-django-stress-test

[English](README.md) · [한국어](README.ko.md) · **简体中文**

按 Django 的方式为 Django 服务器做负载测量准备 —— 检测 runserver · DEBUG=True · 自动重载 · debug-toolbar · DEBUG 日志等失效配置，django-prometheus 延迟直方图与 in-flight 仪表 · 多进程埋点，Gunicorn worker · 线程 · `CONN_MAX_AGE` · DB 池旋钮，pyperf 微基准测试。

负载模型 · 指标 · 统计判定 · 目标主机安全由 `common-stress-test` 负责。本插件只包含 Django 特有的内容。依据是 Django 文档（django-admin runserver · Settings · Databases · Logging）· Gunicorn 设置说明 · prometheus client_python "Multiprocess Mode" · django-prometheus 源码和文档 · pyperf 文档，并且每个条款都在 Docker 中实际运行确认过。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-django-stress-test@jaemyeong-hwnag-plugins
```

## 依赖

- `common-stress-test` — 编写负载脚本 · 判定结果 · 目标主机安全

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| django-stress-test-apply | Django 负载测试 · gunicorn 性能 · `/metrics` · worker 数 · `CONN_MAX_AGE` · pyperf | 去除失效配置，应用埋点，用旋钮预测饱和点，微基准测试 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| django-stress-config-validate.sh | PreToolUse (Bash) | 运行负载工具（`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`，使用这些镜像的 `docker run` · compose，`mvn` · `gradle` 的 gatling 任务）时检查项目并**提示**。不阻止 |

## 注意事项

- 不做语法分析，逐行读取。像 `DEBUG = env("DEBUG", default=True)` 这样值为变量时不读 —— 由技能查看默认值
- 文件名中以单词形式含 `dev` · `local` · `test` 的配置（`settings/dev.py` · `docker-compose.dev.yml`）、CI 文件（`.github/` · `.gitlab-ci.yml`）、`Makefile` 视为开发用而跳过。如果测量目标由这些文件启动，不要只凭 CLI 结果放心
- django-prometheus 没有 in-flight 仪表。自行加入配方中的中间件
- 需要 `jq`（钩子模式）

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `DJ-01` | 不用 `manage.py runserver` 测量 | 阻止 |
| `DJ-02` | 不在 `DEBUG = True` 下测量 | 阻止 |
| `DJ-03` | 不在 Gunicorn · Uvicorn 自动重载下测量 | 阻止 |
| `DJ-04` | 不把 django-debug-toolbar 放进被测配置 | 警告 |
| `DJ-05` | 不在日志级别 DEBUG 下测量 | 警告 |
| `DJ-06` | 多 worker + prometheus 时需要 `PROMETHEUS_MULTIPROC_DIR` | 阻止 |
| `DJ-07` | 在 Gunicorn `child_exit` 中调用 `mark_process_dead` | 警告 |
| `DJ-08` | 有延迟直方图和 in-flight 仪表 | 警告 |
| `DJ-09` | django-prometheus Before 中间件在最前，After 在最后 | 警告 |
| `DJ-10` | 直方图桶覆盖 SLO 附近 | AI 判断 |
| `DJ-11` | 先确定 Gunicorn worker 数再测量（默认 1） | 警告 |
| `DJ-12` | ASGI 时 `CONN_MAX_AGE = 0` | 警告 |
| `DJ-13` ~ `DJ-15` | `CONN_MAX_AGE` · DB 连接数 · worker 模型的并发上限 | AI 判断 |
| `DJ-20` | 微基准测试用 pyperf · pytest-benchmark 的重复分布 | AI 判断 |

原文: [`references/django-stress-rules.md`](references/django-stress-rules.md) · 埋点: [`references/django-instrumentation-recipe.md`](references/django-instrumentation-recipe.md) · 微基准测试: [`references/django-microbenchmark.md`](references/django-microbenchmark.md)

## 用法

```bash
scripts/django-stress-config-validate.sh .               # 检查项目（0 通过 · 2 违规）
test/django-stress-config-validate.test.sh               # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
