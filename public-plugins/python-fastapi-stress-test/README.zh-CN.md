# python-fastapi-stress-test

[English](README.md) · [한국어](README.ko.md) · **简体中文**

为 FastAPI 服务器做负载测量准备 —— 延迟直方图 · in-flight 仪表埋点（多 worker 时使用 prometheus 多进程模式），检测开发服务器 · 热重载 · debug 等失效配置，worker · 线程令牌 · DB 池旋钮，pyperf 微基准测试。

负载模型 · 指标 · 统计判定由 `common-stress-test` 负责，本插件只包含 FastAPI · Uvicorn · Gunicorn · prometheus_client 特有的内容。依据是 FastAPI · Starlette · Uvicorn · AnyIO · prometheus client_python · SQLAlchemy · pyperf 的官方文档和源码，以及 Docker 实测。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-fastapi-stress-test@jaemyeong-hwnag-plugins
```

## 依赖

- `common-stress-test` — 编写负载脚本 · 判定结果 · 目标主机安全

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| fastapi-stress-test-apply | FastAPI 负载测试 · uvicorn 性能 · `/metrics` · worker 数 · pyperf | 去除失效配置，应用埋点，用旋钮预测饱和点，微基准测试 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| fastapi-stress-config-validate.sh | PreToolUse (Bash) | 运行负载工具（`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`，使用这些镜像的 `docker run` · compose，`mvn` · `gradle` 的 gatling 任务）时检查项目并**提示**。不阻止 |

## 注意事项

- 钩子只在 FastAPI 项目（依赖文件或 `*.py` 中有 `fastapi`）中提示
- 脚本只读逐行的字面量。不读用变量决定的值，如 `debug=settings.debug` · `--workers "$N"` —— 由技能判断
- 跳过 `#` 注释行、测试文件（`test_*.py` · `*_test.py` · `conftest.py`）以及 `.venv/` · `venv/` · `site-packages/` · `node_modules/` · `build/` · `dist/`
- `FAS-01` 跳过名称中以单词形式含 `dev` · `local` · `test` 的文件、Makefile 中同名目标、CI 文件（`.github/` · `.gitlab-ci.yml`）。其他开发用配置（`docker-compose.override.yml` 等）也会一并报告。用哪个配置测量由人决定
- 需要 `jq`

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `FAS-01` | 不用 `fastapi dev` · `--reload` 测量 | 阻止 |
| `FAS-02` | worker ≥ 2 + prometheus 时需要 `PROMETHEUS_MULTIPROC_DIR` | 阻止 |
| `FAS-03` | Gunicorn + 多进程时在 `child_exit` 中调用 `mark_process_dead` | 警告 |
| `FAS-04` | 不用 `debug=True` 测量 | 警告 |
| `FAS-05` | 不在日志级别 `debug` · `trace` 下测量 | 警告 |
| `FAS-06` | `uvicorn.workers.UvicornWorker` → `uvicorn_worker.UvicornWorker` | 警告 |
| `FAS-07` | 不在 `async def` 中做阻塞调用 | 警告 |
| `FAS-08` | 有服务端埋点和 in-flight 仪表 | 警告 |
| `FAS-09` | 用 `Histogram` 测延迟（不用 `Summary`） | 警告 |
| `FAS-10` ~ `FAS-13` | 桶 · 线程令牌 40 · DB 池 · worker 数 | AI 判断 |
| `FAS-20` | 微基准测试用 pyperf `compare_to` · 重复分布判定 | AI 判断 |

"阻止" 指 CLI 退出码 `2`。钩子不阻止负载命令。

原文: [`references/fastapi-stress-rules.md`](references/fastapi-stress-rules.md)

## 用法

```bash
scripts/fastapi-stress-config-validate.sh .         # 检查项目
test/fastapi-stress-config-validate.test.sh         # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
