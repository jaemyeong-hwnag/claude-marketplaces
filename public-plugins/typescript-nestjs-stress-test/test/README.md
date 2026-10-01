# NestJS 스트레스 설정 테스트

`scripts/nestjs-stress-config-validate.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/nestjs-stress-config-validate.test.sh          # 전체
test/nestjs-stress-config-validate.test.sh TC-N1    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다.

## 자동 TC (31건)

픽스처는 **규칙을 지키는 NestJS 프로젝트**(기본 스타터 스크립트 · `node dist/main` Dockerfile · logger 옵션 · 히스토그램 · 게이지)이고, TC 마다 한 곳만 깨뜨린다. 조항마다 과잉 탐지를 막는 TC 를 둔다.

### A. CLI 조항 (NST-01 ~ NST-09)

| ID | 케이스 |
|---|---|
| TC-N01 | 이 저장소 전체가 통과한다 (NestJS 프로젝트가 아니다) |
| TC-N02 | 규칙을 지킨 프로젝트는 조용히 통과한다 |
| TC-N03 | Dockerfile 이 npm run start:dev 로 띄우면 막는다 — 스크립트를 풀어 nest start 를 본다 (NST-01) |
| TC-N04 | 배포 설정과 start:prod 가 없고 start 가 nest start 면 막는다 (NST-01) |
| TC-N05 | 배포 설정이 없으면 start:prod 를 본다 — 기본 스타터의 start · start:dev 로는 막지 않는다 (NST-01 과잉 차단 방지) |
| TC-N06 | compose command 의 nest start --debug 도 막는다 (NST-01) |
| TC-N07 | 이름에 dev · local · test 가 있는 compose 는 운영 기동으로 보지 않는다 (NST-01 과잉 차단 방지) |
| TC-N08 | ts-node · tsx 로 .ts 를 직접 실행하면 경고한다 (NST-02) |
| TC-N09 | node dist/main.js 는 경고하지 않는다 (NST-02 과잉 경고 방지) |
| TC-N10 | logger 옵션에 debug · verbose 가 있으면 경고한다 (NST-03) |
| TC-N11 | logger 옵션이 없고 코드에 .debug() 가 있으면 기본 레벨 6개로 찍힌다고 경고한다 (NST-03) |
| TC-N12 | logger 옵션이 없어도 .debug() 호출이 없거나 useLogger 가 있으면 경고하지 않는다 (NST-03 과잉 경고 방지) |
| TC-N13 | logger 옵션이 없을 때 NEST_LOG_LEVEL 이 debug 를 켜면 경고하고, warn · >debug 면 조용하다 (NST-03) |
| TC-N13b | logger 옵션을 명시하면 NEST_LOG_LEVEL 은 무시된다 (NST-03 과잉 경고 방지) |
| TC-N14 | FastifyAdapter 에 logger 를 켜면 경고한다 — 여러 줄 옵션도 본다 (NST-04) |
| TC-N15 | disableRequestLogging: true 거나 logger 를 켜지 않으면 경고하지 않는다 (NST-04 과잉 경고 방지) |
| TC-N16 | Fastify 어댑터에서 listen 에 호스트가 없으면 경고한다 (NST-05) |
| TC-N17 | Express 어댑터의 listen(3000) 은 경고하지 않는다 (NST-05 과잉 경고 방지) |
| TC-N18 | makeSummaryProvider · new Summary 를 경고하고 주석은 보지 않는다 (NST-06) |
| TC-N19 | 지연 히스토그램이 없으면 NST-07, in-flight 게이지가 없으면 NST-08 을 경고한다 |
| TC-N20 | new Histogram · new Gauge 로 직접 만들어도 인정하고, OpenTelemetry SDK 를 쓰면 보지 않는다 (NST-07 · NST-08 과잉 경고 방지) |
| TC-N21 | Scope.REQUEST 프로바이더를 경고한다 (NST-09) |
| TC-N22 | durable: true 인 요청 스코프와 Scope.TRANSIENT 는 경고하지 않는다 (NST-09 과잉 경고 방지) |
| TC-N23 | @nestjs/core 가 없는 프로젝트는 보지 않는다 |
| TC-N24 | node_modules · dist · *.spec.ts 는 보지 않는다 |
| TC-N25 | 디렉터리가 아니면 오류 (종료 1) |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-N30 | k6 run 이면 프로젝트를 검사해 additionalContext 로 알리고 막지 않는다 |
| TC-N31 | docker run grafana/k6 · autocannon · 환경 변수 접두어도 부하 명령으로 본다 |
| TC-N32 | 부하 명령이 아니면 조용히 통과한다 |
| TC-N33 | 부하 명령이어도 프로젝트가 깨끗하면 조용하다 |
| TC-N34 | 빈 입력 · Bash 가 아닌 도구 · PostToolUse 는 통과한다 |
