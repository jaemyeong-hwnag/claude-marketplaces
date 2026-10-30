# node-express-stress-test

[English](README.md) · [한국어](README.ko.md) · **简体中文**

为 Node.js · Express 应用做负载测量准备 —— prom-client 延迟直方图 · in-flight 仪表埋点，检测使测量失效的配置（`NODE_ENV` · nodemon · `--watch` · 性能分析器 · `DEBUG` · view cache），cluster worker · `UV_THREADPOOL_SIZE` · keep-alive 旋钮，tinybench · mitata 微基准测试。钩子在运行负载工具前发出警告。

负载模型 · 指标定义 · 统计判定由 `common-stress-test` 负责，本插件只包含 Express · Node.js 特有的内容。依据是 Express 文档（Production best practices: performance · Debugging）· Express 4.x/5.x 源码 · Node.js API 文档（cli · http · cluster · perf_hooks · process · dns）· libuv 文档 · prom-client 源码和 README，并在 Express 5.2.1 · Node.js 22 上实测。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install node-express-stress-test@jaemyeong-hwnag-plugins
```

## 依赖

| 插件 | 用途 |
|---|---|
| common-stress-test | 编写负载场景（`stress-test-create`）· 判定结果（`stress-result-review`） |

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| express-stress-test-apply | express 负载 · node 性能测量 · prom-client · 事件循环延迟 | 去除失效配置 → 埋点 → 记录容量旋钮 → 微基准测试，场景 · 判定交给 common-stress-test |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| express-stress-config-validate.sh | PreToolUse (Bash) | 仅当命令是负载工具（`k6 run` · `k6 cloud` · `wrk` · `wrk2` · `autocannon` · `locust` · `jmeter` · `gatling` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery`，使用这些镜像的 `docker run` · compose，`mvn` · `gradle` 的 gatling 任务）时检查项目并**警告**。不阻止 |

## 注意事项

- 跳过 `package.json` 中没有 `express` 的目录。钩子从命令运行的目录（含 `cd`）向上查找最近的 express 应用
- 只读生产启动配置 —— `package.json` 的 `start` · `start:prod` · `prod` · `serve`、`Dockerfile`、`compose*.yml`、`Procfile`、PM2 `ecosystem.config.*`。跳过名称中以单词形式含 `dev` · `local` · `test` 的文件（`loadtest` · `perftest` 会读）和 `.env`
- 看不到 Kubernetes 清单 · systemd 单元注入的环境变量。因此缺少 `NODE_ENV=production`（`NEX-02`）是警告
- 是逐行 grep。会漏掉跨多行的命令 · 用变量拼出的命令
- 在 Express 核心中，`NODE_ENV` 只改变 view cache 和错误响应。JSON API 的实测差异在噪声之内，pug 渲染在 production 下快 3~4 倍（顺序请求的中位数）
- 同步处理器的排队不会出现在服务端 in-flight 仪表中（`NEX-11`）—— 做 Little 校验时与施压机侧的 L 一起看
- 需要 `jq`

## 规则摘要

| 条款 | 对象 | 判定 |
|---|---|---|
| `NEX-01` | 生产启动的 `NODE_ENV` 不是 production | 违规 |
| `NEX-02` | 哪里都找不到 `NODE_ENV=production` | 警告 |
| `NEX-03` | nodemon · `--watch` · `tsx watch` · `ts-node-dev` · PM2 `watch: true` | 违规 |
| `NEX-04` | `--prof` · `--cpu-prof` · `--heap-prof` · `--trace-sync-io` · `--trace-gc` · 0x · clinic | 违规 |
| `NEX-05` | `--inspect` | 警告 |
| `NEX-06` | `DEBUG=express:*` · `router` · `*` | 违规 |
| `NEX-07` | 关闭 `view cache` | 违规 |
| `NEX-08` | prom-client Summary | 警告 |
| `NEX-09` | 路由文件中的 `*Sync(` | 警告 |
| `NEX-10` ~ `NEX-13` | 直方图 · in-flight · 事件循环 · cluster 聚合 | AI 判断 |
| `NEX-20` ~ `NEX-24` | worker 数 · 线程池 · keep-alive · Agent · 循环阻塞 | AI 判断 |

原文: [`references/express-stress-rules.md`](references/express-stress-rules.md)

## 用法

```bash
scripts/express-stress-config-validate.sh .          # 检查项目（0 通过 · 2 违规 · 1 错误）
test/express-stress-config-validate.test.sh          # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
