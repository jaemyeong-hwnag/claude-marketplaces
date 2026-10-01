# node-express-stress-test

Node.js · Express 앱의 부하 측정을 준비한다 — prom-client 지연 히스토그램 · in-flight 게이지 계측, 측정을 무효로 만드는 설정(`NODE_ENV` · nodemon · `--watch` · 프로파일러 · `DEBUG` · view cache) 탐지, cluster 워커 · `UV_THREADPOOL_SIZE` · keep-alive 손잡이, tinybench · mitata 마이크로벤치마크. 부하 도구 실행 전에 훅이 경고한다.

부하 모델 · 지표 정의 · 통계 판정은 `common-stress-test` 가 맡고, 이 플러그인은 Express · Node.js 에만 해당하는 것을 담는다. 근거는 Express 문서(Production best practices: performance · Debugging) · Express 4.x/5.x 소스 · Node.js API 문서(cli · http · cluster · perf_hooks · process · dns) · libuv 문서 · prom-client 소스와 README 이고, Express 5.2.1 · Node.js 22 에서 실측했다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install node-express-stress-test@plugin-marketplace
```

## 의존성

| 플러그인 | 쓰는 것 |
|---|---|
| common-stress-test | 부하 시나리오 작성(`stress-test-create`) · 결과 판정(`stress-result-review`) |

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| express-stress-test-apply | express 부하 · node 성능 측정 · prom-client · 이벤트 루프 지연 | 무효 설정 제거 → 계측 → 용량 손잡이 기록 → 마이크로벤치마크, 시나리오 · 판정은 common-stress-test 로 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| express-stress-config-validate.sh | PreToolUse (Bash) | 명령이 부하 도구(k6 run · wrk · autocannon · locust · jmeter · gatling · vegeta attack · hey · ab · oha · artillery · `docker run … grafana/k6`)일 때만 프로젝트를 검사해 **경고**한다. 막지 않는다 |

## 주의

- `package.json` 에 `express` 가 없는 디렉터리는 보지 않는다
- 운영 기동 설정만 본다 — `package.json` 의 `start` · `start:prod` · `prod` · `serve`, `Dockerfile`, `compose*.yml`, `Procfile`, PM2 `ecosystem.config.*`. 이름에 `dev` · `local` · `test` 가 든 파일과 `.env` 는 보지 않는다
- 쿠버네티스 매니페스트 · systemd 유닛에서 넣는 환경 변수는 보지 못한다. 그래서 `NODE_ENV=production` 누락(`NEX-02`)은 경고다
- 줄 단위 grep 이다. 여러 줄에 걸친 명령 · 변수로 조립한 명령은 놓친다
- `NODE_ENV` 는 Express 코어에서 뷰 캐시와 오류 응답만 바꾼다. JSON API 는 실측 차이가 노이즈 안이었고, pug 렌더링은 production 이 3~4배 빨랐다 (순차 요청 중앙값)
- 동기 핸들러의 대기열은 서버 in-flight 게이지에 잡히지 않는다 (`NEX-11`) — Little 검증 때 부하기 쪽 L 과 함께 본다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 대상 | 판정 |
|---|---|---|
| `NEX-01` | 운영 기동의 `NODE_ENV` 가 production 이 아님 | 위반 |
| `NEX-02` | `NODE_ENV=production` 을 어디서도 못 찾음 | 경고 |
| `NEX-03` | nodemon · `--watch` · `tsx watch` · PM2 `watch: true` | 위반 |
| `NEX-04` | `--prof` · `--cpu-prof` · `--trace-sync-io` · 0x · clinic | 위반 |
| `NEX-05` | `--inspect` | 경고 |
| `NEX-06` | `DEBUG=express:*` · `router` · `*` | 위반 |
| `NEX-07` | `view cache` 끄기 | 위반 |
| `NEX-08` | prom-client Summary | 경고 |
| `NEX-09` | 라우트 파일의 `*Sync(` | 경고 |
| `NEX-10` ~ `NEX-13` | 히스토그램 · in-flight · 이벤트 루프 · cluster 집계 | AI 판단 |
| `NEX-20` ~ `NEX-24` | 워커 수 · 스레드풀 · keep-alive · Agent · 루프 블로킹 | AI 판단 |

원본: [`references/express-stress-rules.md`](references/express-stress-rules.md)

## 사용

```bash
scripts/express-stress-config-validate.sh .          # 프로젝트 검사 (0 통과 · 2 위반 · 1 오류)
test/express-stress-config-validate.test.sh          # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
