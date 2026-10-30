# java-spring-stress-test

[English](README.md) · [한국어](README.ko.md) · **简体中文**

对 Java · Spring Boot 3.x 服务器做负载测量时承担框架这一部分 —— Actuator · Prometheus 延迟直方图与 in-flight · Tomcat 线程埋点，检测使测量失效的配置（devtools · DEBUG 日志 · show-sql · fork 0 JMH），检查线程 · 连接池旋钮，JMH 微基准测试。

负载模型 · 判定统计 · 目标主机安全由 `common-stress-test` 负责。依据是 Spring Boot 参考文档（Developer Tools · Logging · Metrics · Virtual threads）· `ServerProperties` · Tomcat HTTP Connector 文档 · HikariCP README · JMH 源码。

## 安装

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install java-spring-stress-test@jaemyeong-hwnag-plugins
```

## 依赖

- `common-stress-test` — 编写负载脚本（`stress-test-create`）· 判定结果（`stress-result-review`）· 目标主机安全

## 技能

| 技能 | 触发 | 说明 |
|---|---|---|
| spring-stress-test-apply | Spring 负载测试 · actuator prometheus · Tomcat 线程 · HikariCP 池 · JMH | 去除失效配置 → 服务端埋点 → 记录旋钮 · JVM → 预热 → JMH |

## 钩子

| 脚本 | 事件 | 行为 |
|---|---|---|
| spring-stress-config-validate.sh | PreToolUse (Bash) | 仅在运行负载工具（`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`，使用这些镜像的 `docker run` · compose，`mvn` · `gradle` 的 gatling 任务）时检查项目并以**警告**提示。不阻止 |

## 注意事项

- 配置只读 `application*.properties|yml|yaml`。不读环境变量 · 命令行参数 · Config Server 的值
- 跳过 profile 名为单词 `dev` · `local` · `test` 的文件（`loadtest` · `perftest` 会读）、同一文件内用 `---` · `#---` 分隔且只在这些 profile 下生效的文档，以及 `src/test/`
- 运行方式（`bootRun` · IDE）和预热不由脚本判定 —— 由技能判断
- 以 Spring MVC · 内嵌 Tomcat 为准。WebFlux · Jetty · Undertow 跳过 Tomcat 条款（`SPR-07`）
- 需要 `jq`（钩子模式）

## 规则摘要

| 条款 | 规则 | 判定 |
|---|---|---|
| `SPR-01` | devtools 只能用 `developmentOnly` · `<optional>true</optional>` | 警告 |
| `SPR-02` | 不在 `logging.level.root` 为 DEBUG · TRACE 时测量 | 阻止 |
| `SPR-03` | 关闭 `debug=true` · `trace=true` | 警告 |
| `SPR-04` | 关闭 `spring.jpa.show-sql` · `hibernate.show_sql` | 警告 |
| `SPR-05` | 用 `percentiles-histogram.http.server.requests=true` 输出桶 | 警告 |
| `SPR-06` | 不用 `percentiles.*`（不可合并的分位数）判定 | 警告 |
| `SPR-07` | `server.tomcat.mbeanregistry.enabled=true`（Tomcat 线程指标） | 警告 |
| `SPR-08` | 使用虚拟线程时 `server.tomcat.threads.*` 无效 | 警告 |
| `SPR-09` | 给容器中的 `java` 设置堆上限 | 警告 |
| `SPR-10` | 禁止 JMH fork 0 | 阻止 |
| `SPR-11` ~ `SPR-15` | 运行方式 · 预热 · 旋钮记录 · JMH 比较统计 · JVM 记录 | AI 判断 |

原文: [`references/spring-stress-rules.md`](references/spring-stress-rules.md)

## 用法

```bash
scripts/spring-stress-config-validate.sh .                 # 检查项目 — 0 通过 · 2 违规 · 1 错误
test/spring-stress-config-validate.test.sh                 # 回归测试
```

## 变更记录

参见 [`CHANGELOG.md`](CHANGELOG.md)。
