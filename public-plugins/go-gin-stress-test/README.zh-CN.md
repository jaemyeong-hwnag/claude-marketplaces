# go-gin-stress-test

[English](README.md) · [한국어](README.ko.md) · **简体中文**

对 Go · Gin 服务器做负载测量时承担框架这一部分 —— Prometheus 延迟直方图 · in-flight · 运行时埋点，检测使测量失效的配置（debug 模式 · `-race` 构建 · 公开 pprof · 固定 GOMAXPROCS），检查 GOMAXPROCS · GOMEMLIMIT · 服务器超时 · DB 池旋钮，`go test -bench` · `benchstat` 微基准测试。

负载模型 · 判定统计 · 目标主机安全由 `common-stress-test` 负责。依据是 Gin 源码（`mode.go` · `gin.go` · `render/html.go`）· Go 1.25 发布说明 · GODEBUG 文档 · `net/http` · `database/sql` · `net/http/pprof` 文档 · Go GC 指南 · race detector 文档 · Prometheus "Histograms and summaries" · client_golang 源码 · benchstat 文档。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install go-gin-stress-test@jaemyeong-hwnag-plugins
```

## 依赖

- `common-stress-test` — 编写负载脚本（`stress-test-create`）· 判定结果（`stress-result-review`）· 目标主机安全

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| gin-stress-test-apply | Gin 负载测试 · golang 性能 · GIN_MODE · pprof · GOMAXPROCS · benchstat | 去除失效配置 → 服务端埋点 → 记录旋钮 → 微基准测试 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| gin-stress-config-validate.sh | PreToolUse (Bash) | 仅在运行负载工具（`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`，使用这些镜像的 `docker run` · compose，`mvn` · `gradle` 的 gatling 任务）时检查项目并以**警告**提示。不阻止 |

## 注意事项

- 逐行读取。没有语法分析器，只把以 `//` 开头的行当作注释；块注释 · 字符串中看起来像代码的文字也会被读取
- 环境变量只从 `Dockerfile*` · `Containerfile*` · `*.yml` · `*.yaml` · `.env*` 读取。不读 Helm 模板 · 代码中拼出的值 · 运行参数 —— 通过运行中进程的 `/metrics` 确认
- 跳过 `_test.go` · `vendor/` · `testdata/`。`go test -race` 不在范围内
- 跳过名称中以单词形式含 `dev` · `local` · `test` 的文件（`.env.local` · `docker-compose.dev.yml`）和 CI 文件（`.github/` · `.gitlab-ci.yml`）
- pprof 地址是变量时无法判断是否为回环，降为警告
- 需要 `jq`（钩子模式）

## 规则摘要

| 条款 | 规则 | 判定 |
|---|---|---|
| `GIN-01` | 不以 debug 模式启动 | 阻止 |
| `GIN-02` | 在某处指定 release 模式 | 警告 |
| `GIN-03` | 每请求访问日志（`gin.Default` · `gin.Logger`）只在与生产相同时使用 | 警告 |
| `GIN-04` | 不在公开地址上开放 pprof | 阻止 / 警告 |
| `GIN-05` | 不用 `-race` 构建测负载 | 阻止 / 警告 |
| `GIN-06` | 不手动固定 `GOMAXPROCS` | 警告 |
| `GIN-07` | 容器部署时 `go.mod` 的 `go` ≥ 1.25 | 警告 |
| `GIN-08` | 应用服务器使用带超时的 `http.Server` | 警告 |
| `GIN-09` | 设置 `SetMaxOpenConns` · `SetMaxIdleConns` | 警告 |
| `GIN-10` | 延迟用 Histogram（不用 Summary `Objectives`） | 警告 |
| `GIN-11` | 指标标签中不用原始路径 → `c.FullPath()` | 警告 |
| `GIN-12` | 关闭 GC 时同时设置 `GOMEMLIMIT` | 警告 |
| `GIN-20` ~ `GIN-26` | 池大小 · 内存上限 · 性能剖析 · Little · 微基准测试 · 每请求 CPU | AI 判断 |

原文: [`references/gin-stress-rules.md`](references/gin-stress-rules.md)

## 用法

```bash
scripts/gin-stress-config-validate.sh .          # 检查项目 — 退出码 2 表示违反了阻止条款
test/gin-stress-config-validate.test.sh          # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
