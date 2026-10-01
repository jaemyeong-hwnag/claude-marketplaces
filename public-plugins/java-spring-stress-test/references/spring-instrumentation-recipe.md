# Spring Boot 서버 측 계측 레시피

규칙: [`spring-stress-rules.md`](spring-stress-rules.md) `SPR-05` ~ `SPR-09` · `SPR-15`. 확인 기준 Spring Boot 3.5.16 · Micrometer 1.15.12.

## 1. 의존성

```groovy
// build.gradle
implementation 'org.springframework.boot:spring-boot-starter-actuator'
runtimeOnly 'io.micrometer:micrometer-registry-prometheus'
developmentOnly 'org.springframework.boot:spring-boot-devtools'   // 있으면 여기에만 (SPR-01)
```

```xml
<!-- pom.xml -->
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
  <groupId>io.micrometer</groupId>
  <artifactId>micrometer-registry-prometheus</artifactId>
  <scope>runtime</scope>
</dependency>
```

## 2. 설정 (측정용 프로필)

```properties
management.endpoints.web.exposure.include=health,prometheus
# 지연 히스토그램 버킷 — 인스턴스 사이에 합칠 수 있다 (SPR-05)
management.metrics.distribution.percentiles-histogram.http.server.requests=true
# Tomcat 스레드 · 연결 지표 (SPR-07)
server.tomcat.mbeanregistry.enabled=true
logging.level.root=INFO
```

- `management.metrics.distribution.percentiles.*` 는 쓰지 않는다 (`SPR-06`). Prometheus 에 `quantile` 라벨이 붙은 summary 로 나가고 버킷이 없어 인스턴스 사이에 합칠 수 없다
- 버킷 해상도가 오차를 만든다. 실측에서 20 ms sleep 엔드포인트의 서버 p50 이 19.6 ~ 20.0 ms 로 나왔다 (버킷 경계 사이 선형 보간). SLO 경계가 있으면 `management.metrics.distribution.slo.http.server.requests=100ms,300ms` 로 그 경계에 버킷을 더한다
- `/actuator/prometheus` 를 부하 대상과 같은 포트로 열면 스크레이프 요청도 `http.server.requests` 에 들어간다. `uri` 라벨로 거른다

## 3. 지표 이름 (Prometheus 로 실측)

| 신호 | 지표 | 비고 |
|---|---|---|
| 지연 분포 | `http_server_requests_seconds_bucket{uri,status,outcome,le}` | `histogram_quantile(0.99, sum by (le) (rate(...[1m])))` — 버킷을 먼저 합친다 |
| 처리량 · 에러 | `http_server_requests_seconds_count{outcome}` | `rate()` 로 |
| in-flight (Little 의 L) | `http_server_requests_active_seconds_gcount` | 히스토그램을 켰을 때. 끄면 `http_server_requests_active_seconds_count`. 매핑 전이라 `uri="UNKNOWN"` 으로 나오고 스크레이프 요청 1건이 들어간다 |
| 처리 스레드 포화 | `tomcat_threads_busy_threads` · `tomcat_threads_config_max_threads` | `mbeanregistry` 필요. 가상 스레드면 의미가 없다 |
| 연결 | `tomcat_connections_current_connections` · `tomcat_connections_config_max_connections` | 〃 |
| DB 풀 | `hikaricp_connections_active` · `hikaricp_connections_pending` · `hikaricp_connections_max` · `hikaricp_connections_acquire_seconds` | pending > 0 이 지속되면 풀이 L 의 상한이다 |
| 비동기 실행기 | `executor_active_threads` · `executor_queued_tasks` | `ThreadPoolTaskExecutor` 빈 |
| JVM (USE) | `jvm_gc_pause_seconds` · `jvm_memory_used_bytes` · `jvm_threads_live_threads` · `process_cpu_usage` · `system_cpu_usage` | GC 정지는 꼬리 지연과 같은 시각인지 본다 |

in-flight 를 단계 중 0.5 ~ 1초 간격으로 긁어 평균 낸다. 스크레이프 1건을 뺀다.

```bash
curl -s localhost:8080/actuator/prometheus \
  | awk '/^http_server_requests_active_seconds_(g)?count\{/ {a+=$2} END {print a-1}'
```

## 4. JVM 실행 옵션 (`SPR-09` · `SPR-15`)

```dockerfile
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-Xlog:gc*:file=/tmp/gc.log:time,uptime,level,tags", \
            "-XX:StartFlightRecording=filename=/tmp/rec.jfr,settings=profile,dumponexit=true", \
            "-jar", "/app.jar"]
```

- 컨테이너 지원(`UseContainerSupport`)은 기본으로 켜져 있다. 힙 상한 기본값은 컨테이너 메모리의 25% 다 (실측: 1 GB → 256 MB)
- JDK 는 CPU 2개 이상 · 메모리 약 1792 MB 이상일 때만 G1 을 고른다. 실측에서 2 CPU · 1 GB 는 Serial GC 였다. 측정 기록에 `-Xlog:gc` 첫 줄(`Using G1` 등)을 남긴다
- 확인: `java -XX:+PrintFlagsFinal -version | grep -E 'Use(Serial|G1|Parallel)GC |MaxHeapSize'`
- JFR 은 `jcmd <pid> JFR.start duration=60s filename=/tmp/x.jfr` 로 측정 단계에만 켤 수 있다. 가상 스레드 pinning 은 JFR 이벤트 `jdk.VirtualThreadPinned` 로 본다

## 5. 실행 방식 (`SPR-11` · `SPR-12`)

- `./gradlew bootJar` · `mvn package` 로 만든 jar 를 `java -jar` 로 띄운다. `bootRun` · `spring-boot:run` · IDE 는 devtools 와 개발 클래스패스를 끌고 온다
- 측정 전에 가장 높은 단계에 가까운 도착률로 30초 이상 돌려 버린다 (JIT · 스레드 풀 증가 · 커넥션 풀 채움)
- `threads.min-spare` 10 에서 스레드가 늘어나는 구간도 첫 고부하 단계의 꼬리에 섞인다. 가장 높은 단계로 한 번 워밍업한다

## 6. Little's Law 대조

단계마다 `처리량 × 평균 지연(초)` 와 서버 in-flight 평균을 비교한다 (`common-stress-test` `ST-13`).

| 결과 | 뜻 |
|---|---|
| X·W ≈ in-flight (±10%) | 부하기와 서버가 같은 경계를 잰다 |
| X·W > in-flight, 서버 p99 는 정상 | 지연이 서버 **밖**에서 생겼다 — 연결 대기열 · 네트워크 · 부하기 자신. `tomcat_threads_busy_threads` 가 `threads.max` 에 닿았는지 먼저 본다 |
| in-flight 가 `threads.max` 또는 `maximum-pool-size` 에 붙음 | 그 손잡이가 포화점이다 |
