# java-spring-stress-test

**English** · [한국어](README.ko.md) · [简体中文](README.zh-CN.md)

Handles the framework's share when load-testing a Java · Spring Boot 3.x server — Actuator · Prometheus latency histograms with in-flight · Tomcat thread instrumentation, detection of settings that invalidate a measurement (devtools · DEBUG logging · show-sql · fork 0 JMH), thread · connection pool knob checks, JMH microbenchmarks.

Load model · verdict statistics · target host safety belong to `common-stress-test`. Evidence: Spring Boot reference (Developer Tools · Logging · Metrics · Virtual threads) · `ServerProperties` · Tomcat HTTP Connector docs · HikariCP README · JMH source.

## Installation

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install java-spring-stress-test@jaemyeong-hwnag-plugins
```

## Dependencies

- `common-stress-test` — writing load scripts (`stress-test-create`) · judging results (`stress-result-review`) · target host safety

## Skills

| Skill | Trigger | Description |
|---|---|---|
| spring-stress-test-apply | Spring load test · actuator prometheus · Tomcat threads · HikariCP pool · JMH | Remove invalidating settings → server-side instrumentation → record knobs · JVM → warm-up → JMH |

## Hooks

| Script | Event | Behavior |
|---|---|---|
| spring-stress-config-validate.sh | PreToolUse (Bash) | Only when running a load tool (`k6 run` · `k6 cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon`, `docker run` · compose with those images, the gatling task of `mvn` · `gradle`), checks the project and reports **warnings**. Does not block |

## Notes

- Only `application*.properties|yml|yaml` are read for settings. Environment variables · command-line arguments · Config Server values are not read
- Files whose profile name is the word `dev` · `local` · `test` (`loadtest` · `perftest` are read), documents in one file split by `---` · `#---` that only activate under those profiles, and `src/test/` are skipped
- The scripts do not judge how the app is run (`bootRun` · IDE) or warm-up — the skill does
- Based on Spring MVC · embedded Tomcat. WebFlux · Jetty · Undertow skip the Tomcat clause (`SPR-07`)
- Requires `jq` (hook mode)

## Rule summary

| Clause | Rule | Verdict |
|---|---|---|
| `SPR-01` | devtools only as `developmentOnly` · `<optional>true</optional>` | Warning |
| `SPR-02` | Do not measure with `logging.level.root` DEBUG · TRACE | Block |
| `SPR-03` | Turn off `debug=true` · `trace=true` | Warning |
| `SPR-04` | Turn off `spring.jpa.show-sql` · `hibernate.show_sql` | Warning |
| `SPR-05` | Emit buckets with `percentiles-histogram.http.server.requests=true` | Warning |
| `SPR-06` | Do not judge by `percentiles.*` (non-aggregable quantiles) | Warning |
| `SPR-07` | `server.tomcat.mbeanregistry.enabled=true` (Tomcat thread metrics) | Warning |
| `SPR-08` | With virtual threads, `server.tomcat.threads.*` has no effect | Warning |
| `SPR-09` | Give container `java` a heap limit | Warning |
| `SPR-10` | No JMH fork 0 | Block |
| `SPR-11` ~ `SPR-15` | How it runs · warm-up · knob record · JMH comparison statistics · JVM record | AI judgment |

Source: [`references/spring-stress-rules.md`](references/spring-stress-rules.md)

## Usage

```bash
scripts/spring-stress-config-validate.sh .                 # check the project — 0 pass · 2 violation · 1 error
test/spring-stress-config-validate.test.sh                 # regression tests
```

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).
