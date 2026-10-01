# Spring Boot 스트레스 측정 규칙 (단일 원본)

Spring Boot 3.x(Spring MVC · 내장 Tomcat · HikariCP) 서버를 부하 측정할 때 **그 프레임워크에만 해당하는 것**을 정한다.
부하 모델 · 판정 통계 · 대상 호스트 안전은 `common-stress-test` 의 `stress-test-rules.md` 가 맡는다.

계측 방법은 [`spring-instrumentation-recipe.md`](spring-instrumentation-recipe.md), 마이크로벤치마크는 [`jmh-benchmark.md`](jmh-benchmark.md) 에 있다.
기계 검증은 `scripts/spring-stress-config-validate.sh` 다.

확인 기준: Spring Boot 3.5.16 · Micrometer 1.15.12 · Tomcat 10.1.55 · HikariCP 6.3.3 · JDK 21 (Temurin 21.0.12) · JMH 1.36.

## 1. 조항

| 조항 | 내용 | 판정 | 근거 |
|---|---|---|---|
| `SPR-01` | `spring-boot-devtools` 는 Gradle `developmentOnly`, Maven `<optional>true</optional>` 로만 둔다 | 경고 | Spring Boot 문서 "Developer Tools" — 운영 빌드에서 빼는 방법 · `java -jar` 면 운영 앱으로 보고 끈다 |
| `SPR-02` | `logging.level.root` 를 `DEBUG` · `TRACE` 로 두고 재지 않는다 | **차단** | Spring Boot 문서 "Logging" — Log Levels · 실측(아래 3절) |
| `SPR-03` | `debug=true` · `trace=true` 를 끄고 잰다 | 경고 | Spring Boot 문서 "Logging" — Console Output (debug 는 핵심 로거만, trace 는 Spring 전체) |
| `SPR-04` | `spring.jpa.show-sql` · `hibernate.show_sql` 을 끄고 잰다 | 경고 | Spring Boot `JpaProperties.showSql` · Hibernate `JdbcSettings.SHOW_SQL` ("logging of generated SQL to the console") |
| `SPR-05` | Prometheus 레지스트리를 쓰면 `management.metrics.distribution.percentiles-histogram.http.server.requests=true` 로 지연 **버킷**을 낸다 | 경고 | Spring Boot 문서 "Metrics" — Per-meter properties · Prometheus 문서 "Histograms and summaries" |
| `SPR-06` | `management.metrics.distribution.percentiles.*` (앱이 계산한 분위수)로 판정하지 않는다 | 경고 | 같은 절 — "computed non-aggregable percentiles" |
| `SPR-07` | in-flight · 스레드 포화를 보려면 `server.tomcat.mbeanregistry.enabled=true` | 경고 | Spring Boot 문서 "Metrics" — Tomcat Metrics (MBean Registry 가 꺼져 있으면 Tomcat 지표가 없다) |
| `SPR-08` | `spring.threads.virtual.enabled=true` 면 `server.tomcat.threads.*` 는 효과가 없다 | 경고 | Spring Boot 문서 "SpringApplication" — Virtual threads · `ServerProperties.Tomcat.Threads` Javadoc |
| `SPR-09` | 컨테이너에서 `java` 를 띄울 때 힙 상한을 준다 (`-XX:MaxRAMPercentage` · `-Xmx`) | 경고 | JDK `gc_globals.hpp` `MaxRAMPercentage=25.0` · 실측 |
| `SPR-10` | JMH 를 fork 0 으로 돌리지 않는다 (`@Fork(0)` · `jmh { fork = 0 }`) | **차단** | JMH `BaseRunner` 경고문 "Use non-forked runs only for debugging purposes, not for actual performance runs" |
| `SPR-11` | 부하 대상은 패키징한 jar(`java -jar`)나 이미지로 띄운다. `bootRun` · `spring-boot:run` · IDE 실행은 측정이 아니다 | AI 판단 | Spring Boot 문서 "Developer Tools" — 운영 앱 판정 기준 |
| `SPR-12` | JIT 워밍업 구간을 측정에서 뺀다 — 같은 도착률로 먼저 돌리고 버린다 | AI 판단 | Georges et al. OOPSLA 2007 · Barrett et al. OOPSLA 2017 |
| `SPR-13` | 용량 손잡이를 측정 기록에 남기고 Little 의 L 상한과 대조한다 (2절) | AI 판단 | `ServerProperties` · HikariCP README · Tomcat HTTP Connector 문서 |
| `SPR-14` | JMH 결과는 fork 2 이상 · 워밍업 확인 · 오차 구간으로 비교한다 | AI 판단 | Traini et al. EMSE 28 (2023) · Georges et al. 2007 · Kalibera & Jones 2013 |
| `SPR-15` | JVM 을 기록한다 — GC 종류 · 힙 상한 · CPU 제한. 2 CPU 미만이거나 메모리 1792 MB 미만이면 JDK 가 Serial GC 를 고른다 | AI 판단 | JDK `os::is_server_class_machine` · 실측 |

판정의 뜻: **차단**은 CLI 종료 코드 2, 경고는 0 으로 알린다. 훅은 둘 다 차단하지 않고 경고로 알린다.

### 탐지 범위

- 설정은 `application*.properties` · `application*.yml|yaml` 를 본다. `src/test/` 와 프로필 이름에 `dev` · `local` · `test` 가 들어간 파일은 보지 않는다
- 키는 relaxed binding 으로 맞춘다 — 소문자로 바꾸고 `-` · `_` 를 뺀다 (`show-sql` = `showSql`)
- 환경 변수 · 명령행 인자 · Config Server 로 준 값은 보지 않는다. 실행 명령은 AI 가 본다 (`SPR-11`)
- `SPR-05` 는 빌드 파일에 `micrometer-registry-prometheus` 가 있을 때, `SPR-07` 은 `spring-boot-starter-actuator` 와 `spring-boot-starter-web` 이 있고 Jetty · Undertow 가 없을 때만 본다
- `SPR-05` 는 `percentiles-histogram.all` · `.http` · `.http.server` 처럼 앞부분이 맞는 키도 인정한다 (가장 긴 접두사가 이긴다)

## 2. 용량 손잡이 (`SPR-13`)

| 손잡이 | 키 | 기본값 | 포화점에 미치는 영향 |
|---|---|---|---|
| 요청 처리 스레드 | `server.tomcat.threads.max` | 200 | 동시에 처리하는 요청 수의 상한. 서버 in-flight(L) 가 여기 붙으면 나머지는 연결 큐에서 기다린다 |
| 최소 스레드 | `server.tomcat.threads.min-spare` | 10 | 처음엔 10개에서 늘린다. 첫 단계의 꼬리 지연에 스레드 생성 비용이 섞인다 |
| 연결 수 | `server.tomcat.max-connections` | 8192 | 받아서 처리하는 연결 수 상한 (NIO) |
| 연결 대기열 | `server.tomcat.accept-count` | 100 | `max-connections` 에 닿은 뒤 OS 가 쥐고 있는 대기열. 차면 연결 거부 · 타임아웃 |
| DB 커넥션 풀 | `spring.datasource.hikari.maximum-pool-size` | 10 | DB 를 쓰는 요청의 동시 실행 상한. 차면 `connection-timeout`(기본 30000 ms)까지 막혀 기다린다 |
| 가상 스레드 | `spring.threads.virtual.enabled` | false | 켜면 Tomcat 이 요청마다 가상 스레드를 쓴다. `threads.max` 가 상한이 아니게 되고 풀(Hikari 10)이 상한이 된다 |

- **Little 상한**: 엔드포인트가 DB 를 쓰면 서버 L 은 `min(threads.max, maximum-pool-size + DB 없는 구간)` 에서 멈춘다. 처리량 상한 ≈ `maximum-pool-size / DB 구간 평균 시간`
- 풀 대기는 서버 측 지연에 들어가고 in-flight 에도 들어간다. 연결 대기열(`accept-count`)에서 기다린 시간은 **서버 지표에 없다** — 부하기 지연과 서버 지연의 차이로 본다
- `server.tomcat.accept-count` 의 Spring Boot Javadoc 은 "모든 처리 스레드가 쓰일 때" 라고 적었고 Tomcat 문서는 "`maxConnections` 에 닿았을 때" 라고 적었다. Tomcat 문서를 따른다

## 3. 근거 실측 요약

Spring Boot 3.5.16 · JDK 21 · 컨테이너 2 CPU · 1 GB, `/work` 는 20 ms sleep, k6 `constant-arrival-rate` 15초 단계.

- `percentiles-histogram` 을 켜면 `http_server_requests_seconds_bucket` 이 나오고, in-flight 는 `http_server_requests_active_seconds_gcount` 로 나온다. 끄면 같은 값이 `http_server_requests_active_seconds_count` (summary) 로 나온다
- `percentiles` 만 주면 `http_server_requests_seconds{quantile="0.95"}` 처럼 summary 로 나온다 — 버킷이 없다
- `server.tomcat.mbeanregistry.enabled` 를 빼면 `tomcat_threads_busy_threads` 가 사라진다
- 2 CPU · 1 GB 컨테이너에서 JDK 21 은 Serial GC 와 힙 256 MB 를 골랐다. 2 GB 면 G1 이다
- devtools 를 `implementation` 으로 넣어 `java -jar` 로 띄우면 재시작 · 속성 기본값이 꺼진다. `-Dspring.devtools.restart.enabled=true` 를 주면 켜진다
- 같은 jar 를 `--logging.level.root=DEBUG` 로 띄우면 15초 단계 8개(200 ~ 3500 rps) 동안 로그가 150만 줄 나왔다. 정상은 3500 rps 까지 처리량 3493 · 서버 평균 21.7 ms 였고, DEBUG 는 2000 ~ 3500 rps 네 단계 모두 목표를 못 냈다 — 정상은 같은 구간에서 0 ~ 2 단계 (3500 rps 에서 처리량 2643 · 서버 평균 51.6 ms · 서버 p99 661 ms)
