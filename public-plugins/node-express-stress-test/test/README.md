# Express 부하 측정 설정 테스트

`scripts/express-stress-config-validate.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/express-stress-config-validate.test.sh          # 전체
test/express-stress-config-validate.test.sh TC-E1    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. macOS 기본 bash 3.2 에서도 돈다.

## 자동 TC (29건)

픽스처는 **규칙을 지키는 Express 프로젝트**(`start` 는 `node`, Dockerfile `ENV NODE_ENV=production`, prom-client Histogram)이고, TC 마다 한 곳만 깨뜨린다. 조항마다 과잉 탐지를 막는 TC 를 둔다.

### A. CLI (NEX-01 ~ NEX-09)

| ID | 케이스 |
|---|---|
| TC-E01 | 규칙을 지킨 프로젝트는 조용히 통과한다 |
| TC-E02 | express 가 없는 프로젝트는 보지 않는다 |
| TC-E03 | package.json 이 없으면 통과하고, 디렉터리가 아니면 오류다 |
| TC-E04 | start 스크립트의 NODE_ENV=development 를 막는다 (NEX-01) |
| TC-E05 | Dockerfile ENV · compose environment 의 non-production 을 막는다 (NEX-01) |
| TC-E06 | dev · local · test 변형 파일과 dev 스크립트는 보지 않는다 (NEX-01 · NEX-03 과잉 탐지 방지) |
| TC-E07 | NODE_ENV=production 이 어디에도 없으면 경고만 한다 (NEX-02) |
| TC-E08 | PM2 ecosystem 의 NODE_ENV production 으로 NEX-02 가 풀리고, env 의 development 는 위반으로 보지 않는다 |
| TC-E09 | start 의 nodemon · node --watch · tsx watch 를 막는다 (NEX-03) |
| TC-E10 | Dockerfile CMD · Procfile · PM2 watch: true 의 자동 리로드를 막는다 (NEX-03) |
| TC-E11 | --watch 와 비슷한 이름 · watch: false 는 막지 않는다 (NEX-03 과잉 탐지 방지) |
| TC-E12 | 프로파일러 · 추적 플래그를 막는다 (NEX-04) |
| TC-E13 | --inspect 는 경고만 한다 (NEX-05) |
| TC-E14 | dev 스크립트의 --inspect · 비슷한 플래그는 보지 않는다 (NEX-04 · NEX-05 과잉 탐지 방지) |
| TC-E15 | DEBUG=express:* · router · * 를 막는다 (NEX-06) |
| TC-E16 | 앱 네임스페이스만 켠 DEBUG 는 막지 않는다 (NEX-06 과잉 탐지 방지) |
| TC-E17 | view cache 를 끄면 막는다 (NEX-07) |
| TC-E18 | view cache 를 켜거나 주석에 쓴 것은 막지 않는다 (NEX-07 과잉 탐지 방지) |
| TC-E19 | prom-client Summary 를 경고한다 (NEX-08) |
| TC-E20 | prom-client 가 아닌 Summary 클래스는 경고하지 않는다 (NEX-08 과잉 탐지 방지) |
| TC-E21 | 라우트 파일의 *Sync 호출을 경고한다 (NEX-09) |
| TC-E22 | 라우트가 없는 파일 · 테스트 · node_modules 의 *Sync 는 보지 않는다 (NEX-09 과잉 탐지 방지) |
| TC-E23 | 위반과 경고가 함께 있으면 둘 다 보고하고 2 로 끝난다 |

### B. 훅 (PreToolUse Bash)

| ID | 케이스 |
|---|---|
| TC-E30 | k6 run 이면 위반을 additionalContext 로 알리고 막지 않는다 |
| TC-E31 | 부하 도구 여러 형태를 알아본다 (docker grafana/k6 · npx autocannon · 환경 변수 · 경로 · 체인 · wrk · vegeta · ab · hey · oha · locust · jmeter · artillery · gatling) |
| TC-E32 | 부하 도구가 아닌 명령은 조용히 통과한다 (`echo hey` · `grep k6` · `k6 version` …) |
| TC-E33 | 부하 명령이어도 프로젝트가 규칙을 지키면 조용하다 |
| TC-E34 | 빈 입력 · Bash 가 아닌 도구 · PostToolUse · 잘못된 JSON 은 통과한다 |
| TC-E35 | 경고만 있는 프로젝트도 알린다 |
