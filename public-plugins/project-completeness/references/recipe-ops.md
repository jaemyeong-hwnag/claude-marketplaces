# 서비스 · 운영 레시피

배포된 뒤의 완성도를 다룬다. 코드 품질 도구가 답하지 못하는 질문들이다 —
**터지는 걸 아는가 / 얼마나 나쁜지 아는가 / 누가 받는가 / 되돌릴 수 있는가.**

> **순서를 지켜라.** 관측성 없이 SLO 를 만들면 측정할 데이터가 없고,
> SLO 없이 온콜을 만들면 무엇으로 깨울지 정의되지 않는다.
> `관측성 → SLO → 알림·온콜 → 롤백 수단 → 커뮤니케이션 → 포스트모템` 순으로 간다.

---

## OpenTelemetry — 계측 (모든 운영 항목의 선행 조건)

- **메우는 항목**: `ops.tracing` end-to-end 트레이스
- **선행 조건**: 실행 중인 서비스. 수집 백엔드는 나중에 정해도 된다(OTLP 로 보내두면 교체 자유)
- **설치**
  - Node: `npm i @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-trace-otlp-http import-in-the-middle`
  - Python: `uv add opentelemetry-distro opentelemetry-exporter-otlp` → `opentelemetry-bootstrap -a install`
  - Go: `go get go.opentelemetry.io/otel go.opentelemetry.io/otel/sdk go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp`
- **설정** — Node 예시. **앱 코드보다 먼저 로드되어야** 자동 계측이 붙는다:
  ```javascript
  // otel.js — 엔트리보다 먼저 require/import 한다
  import { register } from 'node:module';
  // ⚠️ ESM(import 문) 프로젝트에서는 이 훅 등록이 필수다.
  //    없으면 자동 계측이 모듈을 후킹하지 못해 트레이스가 "조용히 0건" 이 된다.
  //    에러도 나지 않아 설정이 된 줄 착각하기 쉽다. CommonJS 라면 생략 가능.
  //    설치: npm i import-in-the-middle
  register('import-in-the-middle/hook.mjs', import.meta.url);

  import { NodeSDK } from '@opentelemetry/sdk-node';
  import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
  import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

  const sdk = new NodeSDK({
    serviceName: process.env.OTEL_SERVICE_NAME ?? 'my-service',
    traceExporter: new OTLPTraceExporter({
      url: `${process.env.OTEL_TRACES_BASE}/v1/traces`,   // 수집기 주소 (로컬 Jaeger 면 4318 포트)
    }),
    instrumentations: [getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },   // 노이즈가 크다
    })],
  });
  sdk.start();
  process.on('SIGTERM', () => sdk.shutdown().finally(() => process.exit(0)));
  ```
  실행: `node --import ./otel.js src/index.js`
  ⚠️ `OTEL_EXPORTER_OTLP_ENDPOINT` 환경변수를 설정하면 SDK 가 **메트릭도** 같은 엔드포인트로
  보내려 한다. Jaeger 처럼 트레이스만 받는 백엔드는 `/v1/metrics` 에서 `Not Found` 를 반환한다.
  트레이스 주소를 코드에서 명시(`OTEL_TRACES_BASE`)하고 `OTEL_EXPORTER_OTLP_ENDPOINT` 는 비워두면 이 오류가 사라진다.
  Python: 코드 수정 없이 `opentelemetry-instrument python -m app` 로 감쌀 수 있다.
- **검증**: 로컬에 수집기를 띄우고 요청 1건이 트레이스로 잡히는지 확인한다.
  ```bash
  docker run -d --name jaeger -p 16686:16686 -p 4318:4318 jaegertracing/all-in-one:latest
  OTEL_TRACES_BASE=<수집기 주소 — localhost:4318> OTEL_SERVICE_NAME=my-service node --import ./otel.js src/index.js
  curl localhost:3000/health
  sleep 10                                   # BatchSpanProcessor 플러시 대기
  curl -s localhost:16686/api/services
  #  {"data":["my-service"], ...}   ← 서비스 이름이 나오면 성공
  #  {"data":["jaeger-all-in-one"]} ← 자기 자신만 있으면 계측이 안 붙은 것이다
  ```
  **이 확인을 건너뛰지 마라.** 계측 실패는 에러 없이 통과하므로,
  실제 트레이스 도착을 보지 않으면 안 되는 걸 된다고 믿게 된다.
- **롤백**: `otel.js` 와 `--import` 플래그 제거, 의존성 삭제
- **비고**: **백엔드(Grafana/Datadog/SigNoz)를 먼저 고르지 마라.** OTLP 로 내보내두면
  엔드포인트만 바꿔 교체할 수 있다. 벤더 SDK 를 직접 심으면 락인된다.
  `OTEL_TRACES_SAMPLER=parentbased_traceidratio` 와 `OTEL_TRACES_SAMPLER_ARG=0.1` 로
  샘플링을 걸지 않으면 비용이 폭발한다.

---

## Sentry — 에러 추적

- **메우는 항목**: `ops.tracing` (부분), 릴리스별 회귀 추적
- **선행 조건**: Sentry 프로젝트 DSN
- **설치**: `npm i @sentry/node` (또는 `@sentry/browser`, `sentry-sdk`)
- **설정**:
  ```javascript
  import * as Sentry from '@sentry/node';
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    release: process.env.GIT_SHA,        // 릴리스별 회귀 추적에 필수
    tracesSampleRate: 0.1,
    beforeSend(event) {                   // PII 를 그대로 올리지 않는다
      delete event.request?.cookies;
      return event;
    },
  });
  ```
  CI 에서 소스맵 업로드:
  ```yaml
  - run: npx @sentry/cli sourcemaps upload --release "$GITHUB_SHA" ./dist
    env: { SENTRY_AUTH_TOKEN: "${{ secrets.SENTRY_AUTH_TOKEN }}" }
  ```
- **검증**: `Sentry.captureException(new Error('setup check'))` 를 한 번 호출하고
  대시보드에 뜨는지 확인. 소스맵이 붙었으면 스택트레이스가 원본 파일·줄로 보인다.
- **롤백**: `Sentry.init` 제거, 의존성 삭제
- **비고**: `release` 를 안 넣으면 "이 배포에서 새로 생긴 에러"를 구분할 수 없어
  에러 추적의 절반이 무의미해진다.

---

## SLO + 에러버짓 (Prometheus / Sloth)

- **메우는 항목**: `ops.slo` 핵심 여정 SLO 와 에러버짓
- **선행 조건**: 요청 수·에러 수·지연 메트릭이 이미 수집되고 있을 것 (OpenTelemetry → Prometheus)
- **설치**: `brew install sloth` 또는 `docker run ghcr.io/slok/sloth`
- **설정** — `slo/checkout.yml`. **핵심 유저 여정 1개부터** 시작한다:
  ```yaml
  version: prometheus/v1
  service: checkout
  slos:
    - name: availability
      objective: 99.9                       # 30일 에러버짓 = 43분
      description: 결제 API 가 5xx 없이 응답한다
      sli:
        events:
          error_query: sum(rate(http_requests_total{service="checkout",code=~"5.."}[{{.window}}]))
          total_query: sum(rate(http_requests_total{service="checkout"}[{{.window}}]))
      alerting:
        name: CheckoutAvailability
        page_alert:   { labels: { severity: page } }      # 빠른 소진 → 즉시 호출
        ticket_alert: { labels: { severity: ticket } }    # 느린 소진 → 티켓
    - name: latency
      objective: 99.0
      description: 결제 API 요청의 99% 가 800ms 안에 응답한다
      sli:
        events:
          # error_query 는 "나쁜 이벤트" 수다. 히스토그램 버킷은 임계 이하(=좋은) 수를 세므로
          # 전체에서 빼야 한다. le 버킷을 그대로 넣으면 SLI 가 뒤집혀 항상 통과한다.
          error_query: |
            sum(rate(http_request_duration_seconds_count{service="checkout"}[{{.window}}]))
            - sum(rate(http_request_duration_seconds_bucket{service="checkout",le="0.8"}[{{.window}}]))
          total_query: sum(rate(http_request_duration_seconds_count{service="checkout"}[{{.window}}]))
      alerting:
        # 모든 SLO 에 alerting.name 이 필요하다. 빠뜨리면 sloth 가
        # "alert name is required" 로 실패하며 룰을 0개 생성한다.
        name: CheckoutLatency
        page_alert:   { labels: { severity: page } }
        ticket_alert: { labels: { severity: ticket } }
  ```
- **검증**:
  ```bash
  sloth generate -i slo/checkout.yml -o slo/rules.yml
  promtool check rules slo/rules.yml          # "SUCCESS: N rules found" — N 이 0 이면 실패다
  # Prometheus 에 로드한 뒤 다음 쿼리가 값을 반환해야 한다
  #   slo:sli_error:ratio_rate5m{sloth_service="checkout"}
  ```
- **롤백**: 생성된 룰 파일 제거
- **게이트**: 🟢 알림만. **SLO 위반으로 배포를 막지 마라** — 에러버짓 정책은 사람이 결정한다.
- **비고**: 목표치를 **현재 실측값에서 시작**한다. 현재 가용성이 99.2%인데 99.99%를 걸면
  첫날부터 버짓이 소진되어 알림이 무의미해진다. 커버리지 임계값과 같은 원칙이다.
  관리형을 원하면 Grafana Cloud SLO(무료 티어 포함) 또는 Nobl9(유료).

---

## 에러버짓 정책 문서

- **메우는 항목**: `ops.slo` (정책 부분)
- **선행 조건**: SLO 정의 완료
- **설정** — `docs/error-budget-policy.md`. **숫자보다 이 합의가 중요하다:**
  ```markdown
  # 에러버짓 정책

  | 버짓 잔여 | 조치 |
  |---|---|
  | > 50% | 정상. 기능 개발 진행 |
  | 25~50% | 위험 배포는 카나리 필수. 릴리스 리뷰 강화 |
  | 10~25% | 신규 기능 배포 중단. 신뢰성 작업만 |
  | < 10% | 전면 동결. 인시던트 리뷰 후 재개 승인 필요 |

  - 판단 주체: <팀/역할>
  - 재계산 주기: 30일 롤링
  - 예외 승인: <역할> 의 명시적 승인 + 사유 기록
  ```
- **검증**: 팀이 이 표에 동의했는가. 동의 없는 정책은 첫 위반 때 무시된다.
- **롤백**: 문서 삭제

---

## 온콜 · 에스컬레이션

- **메우는 항목**: `ops.oncall-runbook` 온콜·에스컬레이션·런북
- **선행 조건**: SLO 기반 알림이 존재할 것. **알림 없이 온콜을 만들지 마라**
- **설치**: PagerDuty / incident.io(유료) 또는 Grafana OnCall(무료)
- **설정** — Alertmanager 라우팅 예시:
  ```yaml
  route:
    receiver: ticket
    group_by: [alertname, service]
    routes:
      - matchers: [severity="page"]
        receiver: oncall
        group_wait: 30s
        repeat_interval: 4h
  receivers:
    - name: oncall
      webhook_configs: [{ url: "<온콜 도구 웹훅>" }]
    - name: ticket
      webhook_configs: [{ url: "<이슈트래커 웹훅>" }]
  ```
- **검증**: **실제로 테스트 알림을 발사해** 담당자 기기까지 도달하는지 확인한다.
  ```bash
  curl -X POST localhost:9093/api/v2/alerts -H 'Content-Type: application/json' \
    -d '[{"labels":{"alertname":"OnCallSetupTest","severity":"page","service":"checkout"}}]'
  ```
  도달하지 않으면 온콜이 있는 게 아니라 **있다고 믿는 상태**다.
- **롤백**: 라우팅 규칙 제거
- **비고**: 에스컬레이션(1차 무응답 → N분 후 2차)까지 정의해야 완성이다.

---

## 런북

- **메우는 항목**: `ops.oncall-runbook` (런북 부분)
- **선행 조건**: 알림이 정의되어 있을 것. **알림 1개당 런북 1개**가 원칙
- **설정** — `docs/runbooks/<alertname>.md`:
  ```markdown
  # CheckoutAvailability

  ## 무엇이 잘못됐나
  결제 API 5xx 비율이 SLO 임계를 넘었다.

  ## 영향
  사용자가 결제를 완료하지 못한다. 매출 직접 영향.

  ## 30초 안에 확인할 것
  1. 대시보드: <링크>
  2. 최근 배포: `gh run list --limit 5` — 직전 배포와 시각이 겹치는가
  3. 의존 서비스 상태: <링크>

  ## 즉시 완화
  - 직전 배포가 원인으로 의심되면 롤백: `<명령>`
  - 특정 기능이 원인이면 플래그 off: `<명령>`

  ## 에스컬레이션
  15분 내 완화 실패 시 <역할> 호출.
  ```
  알림에 런북 링크를 붙인다: `annotations: { runbook_url: "<런북 저장 위치>/CheckoutAvailability.md" }`
- **검증**: 온콜 경험이 없는 팀원에게 런북만 주고 따라 하게 한다. 막히는 지점이 곧 결함이다.
- **롤백**: 문서 삭제

---

## 상태 페이지

- **메우는 항목**: `ops.status-page` 상태 페이지와 장애 커뮤니케이션
- **선행 조건**: 공개할 컴포넌트 정의
- **설치**: Statuspage / Better Stack / OneUptime(오픈소스)
- **설정**: 컴포넌트를 **사용자 언어로** 정의한다 — "결제", "로그인" 이지 "checkout-svc", "auth-db" 가 아니다.
  장애 공지 템플릿:
  ```markdown
  [조사 중] <사용자가 겪는 증상>
  영향: <무엇을 못 하는가>
  다음 업데이트: <시각>       ← 이 줄이 문의량을 가장 크게 줄인다
  ```
- **검증**: 유지보수 공지를 한 번 게시해보고 구독 알림이 실제로 발송되는지 확인
- **롤백**: 페이지 비공개 전환

---

## 합성 모니터링 (Checkly)

- **메우는 항목**: `ops.synthetic-monitoring` 핵심 플로우 상시 검증
- **선행 조건**: 공개 접근 가능한 엔드포인트 또는 로그인 플로우
- **설치**: `npm i -D checkly` → `npx checkly login`
- **설정 ①** — `checkly.config.ts` (**프로젝트 루트에 반드시 있어야 한다**).
  없으면 CLI 가 `Unable to detect a Checkly configuration file` 로 실패한다.
  `npx checkly init` 이 생성해주지만, 직접 쓸 때 최소 형태는 다음과 같다:
  ```typescript
  import { defineConfig } from 'checkly';
  import { Frequency, RetryStrategyBuilder } from 'checkly/constructs';

  export default defineConfig({
    projectName: 'My Service',
    logicalId: 'my-service',          // 계정 내 고유. 바꾸면 기존 체크와 연결이 끊긴다
    checks: {
      frequency: Frequency.EVERY_10M,
      locations: ['ap-northeast-2', 'us-east-1'],
      runtimeId: '2024.09',
      checkMatch: '**/__checks__/**/*.check.ts',   // 이 패턴에 맞는 파일만 수집된다
      retryStrategy: RetryStrategyBuilder.fixedStrategy({ maxRetries: 2, baseBackoffSeconds: 30 }),
    },
    cli: { runLocation: 'ap-northeast-2' },
  });
  ```
- **설정 ②** — `__checks__/health.check.ts`:
  ```typescript
  import { ApiCheck, AssertionBuilder } from 'checkly/constructs';

  new ApiCheck('health-check', {
    name: 'Health',
    frequency: 5,                       // 분
    locations: ['ap-northeast-2', 'us-east-1'],
    degradedResponseTime: 500,
    maxResponseTime: 2000,
    request: {
      url: process.env.HEALTH_URL,     // 공개 health 엔드포인트
      method: 'GET',
      assertions: [AssertionBuilder.statusCode().equals(200)],
    },
  });
  ```
  핵심 유저 플로우는 Playwright 스크립트를 `BrowserCheck` 로 올린다 — E2E 자산을 재사용할 수 있다.
- **검증**: `npx checkly test` → 통과하면 `npx checkly deploy`
  ⚠️ `checkly test` 는 **서버 인증을 먼저 확인**하므로 계정 없이는 설정 검증 단계에 도달하지 못한다.
  계정 발급 전에 설정이 맞는지 보려면 타입 체크로 확인한다:
  ```bash
  npx tsc --noEmit          # 구문 API(frequency·locations·AssertionBuilder) 정확성 검증
  ```
  체크가 실제로 수집되는지는 `checkMatch` 패턴과 파일 경로가 일치하는지로 결정된다.
  `__checks__/` 밖에 두거나 `.check.ts` 확장자를 안 지키면 **조용히 0개가 수집된다.**
- **롤백**: `npx checkly destroy`
- **비고**: 무료 대안은 GitHub Actions `schedule` + curl 이다. 다만 러너 지역이 한정되고
  실패 알림을 직접 붙여야 한다.

---

## 롤백 수단 (피처 플래그)

- **메우는 항목**: `ops.rollback` 즉시 되돌릴 수 있는가
- **선행 조건**: 없음. **배포 롤백보다 플래그 off 가 빠르다**
- **설치**: `npm i @growthbook/growthbook` (셀프호스팅 무료, MIT) 또는 Unleash
- **설정**:
  ```javascript
  import { GrowthBook } from '@growthbook/growthbook';
  const gb = new GrowthBook({ apiHost: process.env.GB_HOST, clientKey: process.env.GB_KEY });
  await gb.init({ timeout: 1000 });      // 타임아웃 필수 — 플래그 서버 장애가 앱 장애가 되면 안 된다

  if (gb.isOn('new-checkout')) { /* 신규 */ } else { /* 기존 */ }
  ```
- **검증**: 플래그를 off 로 바꾸고 **1분 내 동작이 되돌아가는지** 실제로 확인한다.
  되돌아가지 않으면 롤백 수단이 아니다.
- **롤백**: SDK 제거 후 분기 정리
- **비고**: 플래그는 부채다. **제거 기한을 티켓으로 함께 만든다.** 안 그러면 죽은 분기가 쌓인다.

---

## 포스트모템

- **메우는 항목**: `ops.postmortem` 비난 없는 포스트모템
- **선행 조건**: 인시던트 1건
- **설정** — `docs/postmortems/YYYY-MM-DD-<제목>.md`:
  ```markdown
  # <제목>

  | 항목 | 값 |
  |---|---|
  | 영향 | <사용자 N명 / M분 / 어떤 기능> |
  | 탐지 | <알림 / 사용자 신고>  — 탐지까지 걸린 시간 |
  | 완화 | <무엇을 해서 멈췄나> — 완화까지 걸린 시간 |

  ## 타임라인
  - HH:MM 배포
  - HH:MM 에러율 상승 시작
  - HH:MM 알림 발화        ← 탐지 지연이 여기서 드러난다
  - HH:MM 롤백 시작
  - HH:MM 복구

  ## 왜 이렇게 됐나
  <사람이 아니라 시스템으로 서술한다. "누가 실수했다" 가 아니라
   "이 실수를 막지 못하는 구조였다" 로 쓴다.>

  ## 액션 아이템
  | 액션 | 담당 | 기한 | 티켓 |
  |---|---|---|---|
  ```
- **검증**: 액션 아이템이 **티켓으로 등록**되었는가. 문서에만 있는 액션은 실행되지 않는다.
- **롤백**: 해당 없음
- **비고**: 탐지 시간이 완화 시간보다 길면, 고칠 것은 코드가 아니라 **알림**이다.

---

## DORA 4 keys 계측 (Four Keys)

- **메우는 항목**: `product.dora-collect` DORA 자동 수집
- **선행 조건**: GitHub Actions 로 배포할 것
- **설정** — 배포 워크플로 끝에 이벤트를 남긴다:
  ```yaml
  - name: 배포 이벤트 기록
    if: always()
    run: |
      echo "{\"sha\":\"${{ github.sha }}\",\"status\":\"${{ job.status }}\",\"ts\":\"$(date -u +%FT%TZ)\"}" \
        >> deployments.jsonl
  ```
  또는 관리형: Sleuth(무료 티어) / LinearB / Swarmia.
  Google `dora-team/fourkeys` 는 GCP 배포가 필요해 도입 비용이 크다.
- **검증**: 최근 30일 배포 빈도·리드타임·실패율·복구시간 4개 숫자가 나오는가
- **롤백**: 이벤트 기록 제거
- **비고**: **DORA 만 추적하지 마라.** 속도만 최적화하면 번아웃(Velocity Trap)이 온다.
  SPACE 설문이나 DevEx 지표를 함께 본다.

---

## 서비스 완성도 스코어카드 (Backstage Tech Insights)

- **메우는 항목**: 서비스 단위 완성도 계량 — 위 항목들이 실제로 지켜지는지 자동 확인
- **선행 조건**: 서비스가 2개 이상. 단일 서비스면 과잉이다
- **설치**: Backstage(OSS) 또는 Cortex/OpsLevel/Port(관리형 유료)
- **설정** — 각 서비스에 `catalog-info.yaml`:
  ```yaml
  apiVersion: backstage.io/v1alpha1
  kind: Component
  metadata:
    name: checkout
    annotations:
      github.com/project-slug: org/checkout
      pagerduty.com/service-id: PXXXXXX
  spec:
    type: service
    lifecycle: production
    owner: team-payments        # 소유자 없는 서비스가 장애 때 가장 오래 방치된다
  ```
  티어 정의:
  ```
  Bronze : 소유자 + README + 온콜 지정
  Silver : + SLO + 대시보드 + 런북
  Gold   : + 카오스 테스트 통과 + 포스트모템 액션 완료율 80%
  ```
- **검증**: 스코어카드에서 모든 프로덕션 서비스가 **최소 Bronze** 인가
- **롤백**: `catalog-info.yaml` 제거
- **비고**: 이 레시피가 "서비스 완성도"를 조직 차원에서 계량하는 유일한 항목이다.
  다만 서비스가 적으면 스프레드시트 한 장으로 충분하다.

---

## 카오스 실험

- **메우는 항목**: `ops` 전반의 실증 — 위 장치들이 **실제로 동작하는지** 확인
- **선행 조건**: SLO · 알림 · 온콜 · 롤백 수단이 모두 갖춰졌을 것. **마지막에 한다**
- **설치**: LitmusChaos(OSS) / Gremlin(유료). 소규모면 수동으로도 충분하다
- **설정** — 첫 실험은 도구 없이:
  ```
  가설: 결제 서비스 파드 1개를 죽여도 사용자 영향이 없고, 알림은 발화하지 않는다.
  방법: kubectl delete pod <checkout-pod> (스테이징에서 먼저)
  관측: 에러율 / p99 / 알림 발화 여부 / 복구 시간
  중단 조건: 에러율 1% 초과 시 즉시 중단
  ```
- **검증**: 가설이 틀렸다면 그것이 성과다. 예상과 다른 지점을 액션 아이템으로 만든다.
- **롤백**: 실험 중단, 리소스 복구
- **비고**: **프로덕션에서 먼저 하지 마라.** 스테이징 → 저트래픽 시간대 프로덕션 순으로 간다.
