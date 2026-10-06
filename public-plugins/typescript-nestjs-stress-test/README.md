# typescript-nestjs-stress-test

NestJS 서버 부하 측정을 준비한다 — prom-client 지연 히스토그램 · in-flight 게이지 계측, `nest start` · ts-node · debug 로그 같은 무효 설정 탐지, Express/Fastify 어댑터 · 요청 스코프 · DB 풀 손잡이 확인, tinybench 마이크로벤치마크.

부하 모델 · 판정 통계 · 대상 호스트 안전은 `common-stress-test` 가 맡고, 이 플러그인은 NestJS 서버 쪽만 본다. 근거는 Nest 문서(CLI · Logger · Injection scopes · Request lifecycle · Performance), Fastify · Prometheus · prom-client 문서와 Docker 실측이다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install typescript-nestjs-stress-test@jaemyeong-hwnag-plugins
```

## 의존성

- `common-stress-test` — 부하 스크립트 작성(`stress-test-create`) · 결과 판정(`stress-result-review`) · 회귀 통계

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| nestjs-stress-test-apply | NestJS 성능 측정 · 부하 테스트 준비 · nestjs-prometheus · Scope.REQUEST · Fastify 어댑터 | 무효 설정 제거, 히스토그램 · in-flight 계측, 손잡이 확인, 마이크로벤치마크 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| nestjs-stress-config-validate.sh | PreToolUse (Bash) | 명령이 부하 도구(k6 · locust · wrk · autocannon · `docker run grafana/k6` …)면 프로젝트를 검사해 **알린다**. 막지 않는다 |

## 주의

- 훅은 경고만 한다. 부하 대상 호스트를 막는 것은 `common-stress-test` 의 훅이다
- 운영 기동 명령은 Dockerfile · compose · Procfile 에서 찾고, 없으면 `package.json` 의 `start:prod` (없으면 `start`) 를 본다. `npm run x` 는 한 단계 풀어 본다
- 이름에 `dev` · `local` · `test` 가 들어간 Dockerfile · compose 는 보지 않는다
- 문법 분석기 없이 줄 단위로 본다. `logger` 옵션을 변수로 넘기면 값을 따라가지 않는다
- `@nestjs/core` 가 `package.json` 에 없으면 아무것도 보지 않는다. 모노레포는 앱 디렉터리를 인자로 준다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `NST-01` | `nest start` (`--watch` · `--debug`) 로 띄우지 않는다 → `node dist/main` | 차단 |
| `NST-02` | ts-node · tsx 로 `.ts` 를 직접 실행하지 않는다 | 경고 |
| `NST-03` | Nest 로그 레벨에 debug · verbose 를 켜지 않는다 (logger 옵션이 없으면 기본 6레벨 전부) | 경고 |
| `NST-04` | `FastifyAdapter({ logger: true })` 로 재지 않는다 | 경고 |
| `NST-05` | Fastify 어댑터의 `listen` 에 `'0.0.0.0'` | 경고 |
| `NST-06` | 지연은 Histogram — Summary 금지 | 경고 |
| `NST-07` · `NST-08` | 지연 히스토그램 · in-flight 게이지가 있다 | 경고 |
| `NST-09` | `Scope.REQUEST` 는 비용을 재고 쓴다 | 경고 |
| `NST-10` ~ `NST-13` | 계측 위치 · 어댑터 · 프로세스 수 · DB 풀 | AI 판단 |
| `NST-20` | 마이크로벤치마크는 tinybench · mitata + 반복 분포 | AI 판단 |

원본: [`references/nestjs-stress-rules.md`](references/nestjs-stress-rules.md) · 레시피: [`references/nestjs-stress-recipes.md`](references/nestjs-stress-recipes.md)

## 사용

```bash
scripts/nestjs-stress-config-validate.sh .            # 프로젝트 검사 (0 통과 · 2 위반 · 1 오류)
test/nestjs-stress-config-validate.test.sh            # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
