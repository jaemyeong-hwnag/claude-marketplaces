# java-spring-stress-test

Java · Spring Boot 3.x 서버를 부하 측정할 때 프레임워크 몫을 맡는다 — Actuator · Prometheus 지연 히스토그램과 in-flight · Tomcat 스레드 계측, 측정을 무효로 만드는 설정(devtools · DEBUG 로그 · show-sql · fork 0 JMH) 탐지, 스레드 · 커넥션 풀 손잡이 점검, JMH 마이크로벤치마크.

부하 모델 · 판정 통계 · 대상 호스트 안전은 `common-stress-test` 가 맡는다. 근거는 Spring Boot 레퍼런스(Developer Tools · Logging · Metrics · Virtual threads) · `ServerProperties` · Tomcat HTTP Connector 문서 · HikariCP README · JMH 소스다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install java-spring-stress-test@plugin-marketplace
```

## 의존성

- `common-stress-test` — 부하 스크립트 작성(`stress-test-create`) · 결과 판정(`stress-result-review`) · 대상 호스트 안전

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| spring-stress-test-apply | Spring 부하 테스트 · actuator prometheus · 톰캣 스레드 · HikariCP 풀 · JMH | 무효 설정 제거 → 서버 측 계측 → 손잡이 · JVM 기록 → 워밍업 → JMH |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| spring-stress-config-validate.sh | PreToolUse (Bash) | 부하 도구 실행(`k6 run` · `locust` · `jmeter` · `gatling` · `wrk` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon` · `docker run … grafana/k6`)일 때만 프로젝트를 검사해 **경고**로 알린다. 막지 않는다 |

## 주의

- 설정은 `application*.properties|yml|yaml` 만 본다. 환경 변수 · 명령행 인자 · Config Server 값은 보지 않는다
- `dev` · `local` · `test` 가 이름에 든 프로필 파일과 `src/test/` 는 보지 않는다
- 실행 방식(`bootRun` · IDE)과 워밍업은 스크립트가 판정하지 않는다 — 스킬이 본다
- Spring MVC · 내장 Tomcat 기준이다. WebFlux · Jetty · Undertow 는 Tomcat 조항(`SPR-07`)을 건너뛴다
- `jq` 가 필요하다 (훅 모드)

## 규칙 요약

| 조항 | 규칙 | 판정 |
|---|---|---|
| `SPR-01` | devtools 는 `developmentOnly` · `<optional>true</optional>` 로만 | 경고 |
| `SPR-02` | `logging.level.root` DEBUG · TRACE 로 재지 않는다 | 차단 |
| `SPR-03` | `debug=true` · `trace=true` 를 끈다 | 경고 |
| `SPR-04` | `spring.jpa.show-sql` · `hibernate.show_sql` 을 끈다 | 경고 |
| `SPR-05` | `percentiles-histogram.http.server.requests=true` 로 버킷을 낸다 | 경고 |
| `SPR-06` | `percentiles.*` (합칠 수 없는 분위수)로 판정하지 않는다 | 경고 |
| `SPR-07` | `server.tomcat.mbeanregistry.enabled=true` (Tomcat 스레드 지표) | 경고 |
| `SPR-08` | 가상 스레드면 `server.tomcat.threads.*` 는 효과가 없다 | 경고 |
| `SPR-09` | 컨테이너 `java` 에 힙 상한을 준다 | 경고 |
| `SPR-10` | JMH fork 0 금지 | 차단 |
| `SPR-11` ~ `SPR-15` | 실행 방식 · 워밍업 · 손잡이 기록 · JMH 비교 통계 · JVM 기록 | AI 판단 |

원본: [`references/spring-stress-rules.md`](references/spring-stress-rules.md)

## 사용

```bash
scripts/spring-stress-config-validate.sh .                 # 프로젝트 검사 — 0 통과 · 2 위반 · 1 오류
test/spring-stress-config-validate.test.sh                 # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
