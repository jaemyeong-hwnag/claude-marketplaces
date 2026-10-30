# typescript-nestjs-stress-test

[English](README.md) · [한국어](README.ko.md) · **简体中文**

为 NestJS 服务器做负载测量准备 —— prom-client 延迟直方图 · in-flight 仪表埋点，检测 `nest start` · ts-node · debug 日志等失效配置，检查 Express/Fastify 适配器 · 请求作用域 · DB 池旋钮，tinybench 微基准测试。

负载模型 · 判定统计 · 目标主机安全由 `common-stress-test` 负责，本插件只看 NestJS 服务端。依据是 Nest 文档（CLI · Logger · Injection scopes · Request lifecycle · Performance）、Fastify · Prometheus · prom-client 文档和 Docker 实测。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install typescript-nestjs-stress-test@jaemyeong-hwnag-plugins
```

## 依赖

- `common-stress-test` — 编写负载脚本（`stress-test-create`）· 判定结果（`stress-result-review`）· 回归统计

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| nestjs-stress-test-apply | NestJS 性能测量 · 负载测试准备 · nestjs-prometheus · Scope.REQUEST · Fastify 适配器 | 去除失效配置，直方图 · in-flight 埋点，检查旋钮，微基准测试 |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| nestjs-stress-config-validate.sh | PreToolUse (Bash) | 命令是负载工具（k6 · locust · wrk · autocannon · `docker run grafana/k6` …）时检查项目并**提示**。不阻止 |

## 注意事项

- 钩子只发警告。阻止负载目标主机的是 `common-stress-test` 的钩子
- 生产启动命令从 Dockerfile · compose · Procfile 中查找，没有则读 `package.json` 的 `start:prod`（没有则 `start`）。`npm run x` 展开一层
- 跳过名称中以单词形式含 `dev` · `local` · `test` 的 Dockerfile · compose（`loadtest` · `perftest` 会读）
- 不用语法分析器，逐行读取。`logger` 选项以变量传入时不追踪其值
- `package.json` 中没有 `@nestjs/core` 时什么都不检查。monorepo 请把应用目录作为参数传给 CLI。钩子从命令运行的目录（含 `cd`）向上查找最近的应用
- 需要 `jq`

## 规则摘要

| 条款 | 内容 | 判定 |
|---|---|---|
| `NST-01` | 不用 `nest start`（`--watch` · `--debug`）启动 → `node dist/main` | 阻止 |
| `NST-02` | 不用 ts-node · tsx 直接运行 `.ts` | 警告 |
| `NST-03` | Nest 日志级别不开启 debug · verbose（没有 logger 选项时默认 6 个级别全开） | 警告 |
| `NST-04` | 不用 `FastifyAdapter({ logger: true })` 测量 | 警告 |
| `NST-05` | Fastify 适配器的 `listen` 中写 `'0.0.0.0'` | 警告 |
| `NST-06` | 延迟用 Histogram —— 禁用 Summary | 警告 |
| `NST-07` · `NST-08` | 有延迟直方图 · in-flight 仪表 | 警告 |
| `NST-09` | `Scope.REQUEST` 要衡量成本后再用 | 警告 |
| `NST-10` ~ `NST-13` | 埋点位置 · 适配器 · 进程数 · DB 池 | AI 判断 |
| `NST-20` | 微基准测试用 tinybench · mitata + 重复分布 | AI 判断 |

原文: [`references/nestjs-stress-rules.md`](references/nestjs-stress-rules.md) · 配方: [`references/nestjs-stress-recipes.md`](references/nestjs-stress-recipes.md)

## 用法

```bash
scripts/nestjs-stress-config-validate.sh .            # 检查项目（0 通过 · 2 违规 · 1 错误）
test/nestjs-stress-config-validate.test.sh            # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
