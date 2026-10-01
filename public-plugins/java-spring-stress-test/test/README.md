# Spring 부하 측정 설정 테스트

`scripts/spring-stress-config-validate.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/spring-stress-config-validate.test.sh           # 전체
test/spring-stress-config-validate.test.sh TC-S3     # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다.

## 자동 TC (31건)

픽스처는 **규칙을 지키는 프로젝트**(`build.gradle` · `application.properties` · `Dockerfile` · JMH 소스)이고, TC 마다 복사해 한 곳만 깨뜨린다. 과잉 탐지를 막는 TC 를 조항마다 둔다.

### A. CLI 조항 (SPR-01 ~ SPR-10)

| ID | 케이스 |
|---|---|
| TC-S01 | 규칙을 지킨 프로젝트는 조용히 통과한다 |
| TC-S02 | devtools 가 implementation 이면 경고한다 (SPR-01) |
| TC-S03 | devtools 가 developmentOnly · 주석 · Maven optional 이면 경고하지 않는다 (SPR-01 과잉 경고 방지) |
| TC-S04 | Maven devtools 에 optional 이 없으면 경고한다 (SPR-01) |
| TC-S05 | logging.level.root=DEBUG · TRACE 를 막는다 — properties · yml 둘 다 (SPR-02) |
| TC-S06 | root 가 아닌 패키지 DEBUG · dev/local/test 프로필 · src/test 는 막지 않는다 (SPR-02 과잉 차단 방지) |
| TC-S07 | debug=true · trace=true 를 경고한다 (SPR-03) |
| TC-S08 | debug=false · 다른 키 아래 debug 는 경고하지 않는다 (SPR-03 과잉 경고 방지) |
| TC-S09 | show-sql · showSql · hibernate.show_sql 을 경고한다 (SPR-04) |
| TC-S10 | Prometheus 레지스트리가 있는데 히스토그램이 없으면 경고한다 (SPR-05) |
| TC-S11 | 히스토그램이 all · http 접두사 · yml 로 켜졌거나 레지스트리가 없으면 경고하지 않는다 (SPR-05 과잉 경고 방지) |
| TC-S12 | percentiles.* 를 쓰면 경고한다 (SPR-06) |
| TC-S13 | slo · percentiles-histogram 는 SPR-06 으로 보지 않는다 (SPR-06 과잉 경고 방지) |
| TC-S14 | actuator + web 인데 mbeanregistry 가 없으면 경고한다 (SPR-07) |
| TC-S15 | Jetty · WebFlux 만 · actuator 없음이면 경고하지 않는다 (SPR-07 과잉 경고 방지) |
| TC-S16 | 가상 스레드 + server.tomcat.threads.max 를 경고한다 (SPR-08) |
| TC-S17 | 가상 스레드만 · threads.max 만 있으면 경고하지 않는다 (SPR-08 과잉 경고 방지) |
| TC-S18 | Dockerfile 이 힙 상한 없이 java 를 띄우면 경고한다 (SPR-09) |
| TC-S19 | Xmx · JAVA_TOOL_OPTIONS 의 MaxRAMPercentage · java 없는 Dockerfile 은 경고하지 않는다 (SPR-09 과잉 경고 방지) |
| TC-S20 | JMH @Fork(0) · @Fork(value = 0) · jmh { fork = 0 } 을 막는다 (SPR-10) |
| TC-S21 | @Fork(1) · @Fork(10) · fork = 2 는 막지 않는다 (SPR-10 과잉 차단 방지) |
| TC-S22 | build · target · .gradle · node_modules 아래는 보지 않는다 |
| TC-S23 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-S24 | 디렉터리가 아니면 오류 1 |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-S30 | k6 run 이면 위반을 additionalContext 로 알리고 통과한다 |
| TC-S31 | 다른 부하 도구와 docker run grafana/k6 도 알린다 |
| TC-S32 | 부하 도구가 아닌 명령은 조용히 통과한다 |
| TC-S33 | 부하 명령이어도 프로젝트가 깨끗하면 조용히 통과한다 |
| TC-S34 | Bash 가 아닌 도구 · PostToolUse 는 보지 않는다 |
| TC-S35 | 빈 입력 · 명령 없는 입력은 통과한다 |
| TC-S36 | 훅은 차단 조항(SPR-10)도 막지 않고 경고로 알린다 |
