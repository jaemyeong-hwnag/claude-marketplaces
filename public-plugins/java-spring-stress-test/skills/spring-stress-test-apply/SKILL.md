---
name: spring-stress-test-apply
description: Spring Boot 서버에 부하·스트레스 테스트를 걸기 전에 서버 쪽에서 설정·확인할 것을 정할 때 사용한다 — Actuator 지연 히스토그램·in-flight·Tomcat 스레드 계측, devtools·DEBUG 로그·show-sql 같은 무효 설정, 스레드·Hikari 풀, JMH. 트리거 — "부하 테스트 준비", "스프링 성능 측정", "actuator prometheus", "톰캣 스레드", "HikariCP", "JMH".
---

# Spring Boot 부하 측정 준비

규칙 원본: [`references/spring-stress-rules.md`](../../references/spring-stress-rules.md)
계측 레시피: [`references/spring-instrumentation-recipe.md`](../../references/spring-instrumentation-recipe.md)
JMH 절차: [`references/jmh-benchmark.md`](../../references/jmh-benchmark.md)
기계 검증: [`scripts/spring-stress-config-validate.sh`](../../scripts/spring-stress-config-validate.sh)

이 스킬은 **Spring Boot 쪽**만 맡는다. 부하 스크립트 작성(open 모델 · 단계)은 `common-stress-test` 의 `stress-test-create`, 결과 판정(SLO · knee · Little · 회귀)은 `stress-result-review` 에 넘긴다.

## 1. 무효 설정부터 없앤다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/spring-stress-config-validate.sh" .
```

`❌` 가 있으면 측정하지 않는다. 훅은 부하 도구(`k6 run` · `locust` · `jmeter` · `wrk` · `gatling` …)를 실행할 때 같은 검사를 알림으로 보여 준다.

| 조항 | 고칠 것 |
|---|---|
| `SPR-02` ❌ | `logging.level.root` 를 `INFO` 이상으로. 실측에서 `DEBUG` 는 같은 서버의 지속 처리량을 약 3500 → 2600 rps 로 떨어뜨렸다 |
| `SPR-10` ❌ | JMH `@Fork(0)` · `fork = 0` 을 1 이상으로 |
| `SPR-01` | devtools 를 Gradle `developmentOnly` · Maven `<optional>true</optional>` 로 |
| `SPR-03` · `SPR-04` | `debug` · `trace` · `spring.jpa.show-sql` 을 측정 프로필에서 끈다 |
| `SPR-05` ~ `SPR-07` | 2절 계측을 붙인다 |
| `SPR-08` | 가상 스레드를 켰으면 `server.tomcat.threads.*` 를 지우고 상한을 풀에서 본다 |
| `SPR-09` | 컨테이너 `java` 에 `-XX:MaxRAMPercentage=75` 등 힙 상한을 준다 |

스크립트가 못 보는 것 — 사용자에게 묻거나 실행 명령을 본다:

- **실행 방식** (`SPR-11`): 대상이 `java -jar` · 이미지로 떴는가. `bootRun` · `spring-boot:run` · IDE 실행이면 측정이 아니다
- 환경 변수 · 명령행으로 준 `--debug` · `LOGGING_LEVEL_ROOT` · `SPRING_PROFILES_ACTIVE`

## 2. 서버 측 계측을 붙인다

레시피대로 한다 ([`spring-instrumentation-recipe.md`](../../references/spring-instrumentation-recipe.md) 1 ~ 3절).

1. `spring-boot-starter-actuator` + `micrometer-registry-prometheus`
2. `management.metrics.distribution.percentiles-histogram.http.server.requests=true` — 버킷이라 인스턴스 사이에 합칠 수 있다. `percentiles.*` 는 쓰지 않는다
3. `server.tomcat.mbeanregistry.enabled=true` — `tomcat_threads_busy_threads`
4. 확인: `curl -s localhost:8080/actuator/prometheus | grep -E '^http_server_requests_seconds_bucket|^http_server_requests_active_seconds_g?count|^tomcat_threads_busy'`

in-flight(Little 의 L)는 `http_server_requests_active_seconds_gcount` 다 (히스토그램을 끄면 `_count`). 스크레이프 요청 1건이 들어 있으므로 뺀다.

## 3. 용량 손잡이를 확인하고 기록한다 (`SPR-13`)

| 손잡이 | 기본값 | 볼 지표 |
|---|---|---|
| `server.tomcat.threads.max` | 200 | `tomcat_threads_busy_threads` 가 여기 붙는가 |
| `server.tomcat.max-connections` · `accept-count` | 8192 · 100 | `tomcat_connections_current_connections` |
| `spring.datasource.hikari.maximum-pool-size` | 10 | `hikaricp_connections_pending` > 0 이 지속되는가 |
| `spring.threads.virtual.enabled` | false | 켜면 `threads.max` 는 상한이 아니다 |

- DB 를 쓰는 엔드포인트의 처리량 상한 ≈ `maximum-pool-size / DB 구간 평균 시간`. 기본 10 이면 DB 구간 20 ms 에서 약 500 rps 다
- 손잡이를 바꿔 가며 재는 것은 한 번에 하나씩. 바꾼 값을 측정 기록에 남긴다

## 4. JVM 을 맞추고 기록한다 (`SPR-09` · `SPR-15`)

- 힙: `-XX:MaxRAMPercentage=75` (기본 25%)
- GC: 2 CPU 미만 또는 메모리 약 1792 MB 미만이면 JDK 가 Serial GC 를 고른다. 운영과 같은 CPU · 메모리 제한으로 띄우고 `-Xlog:gc` 첫 줄을 기록한다
- `-Xlog:gc*:file=…` 로 GC 정지를 남기고 꼬리 지연 시각과 맞춰 본다. 원인 분석이 필요하면 JFR(`-XX:StartFlightRecording`)

## 5. 워밍업을 뺀다 (`SPR-12`)

측정 단계 전에 가장 높은 도착률로 30초 이상 돌리고 결과를 버린다. JIT · Tomcat 스레드 증가(`min-spare` 10 → 필요 수) · 커넥션 풀 채움이 첫 단계에 섞인다.

## 6. 마이크로벤치마크 — JMH (`SPR-10` · `SPR-14`)

부하 측정으로 원인을 메서드 하나로 좁혔을 때만 쓴다. 절차는 [`jmh-benchmark.md`](../../references/jmh-benchmark.md).

1. `me.champeau.jmh` 플러그인, 소스는 `src/jmh/java`
2. `@Warmup` · `@Measurement` · `@Fork(2 이상)`, 결과는 반환 또는 `Blackhole`
3. 워밍업 반복값이 측정 반복과 비슷해졌는지 본다
4. 두 버전은 같은 머신에서 번갈아 돌리고, 차이를 `Score ± Error` (99.9% 신뢰구간) 와 효과크기로 말한다. 분포 비교는 `common-stress-test` 의 `ST-20` 에 넘긴다

## 7. 넘길 것

- 부하 스크립트(단계 · open 모델 · thresholds) → `stress-test-create`
- 단계 CSV 판정 · Little 대조 · 회귀 → `stress-result-review`. 이 스킬은 in-flight 열(`inflight`)을 채울 지표 이름을 넘겨준다
