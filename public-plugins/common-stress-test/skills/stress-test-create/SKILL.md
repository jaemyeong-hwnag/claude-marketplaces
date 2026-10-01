---
name: stress-test-create
description: 부하·스트레스 테스트를 설계하고 스크립트를 쓸 때 사용한다. 유형(load·stress·spike·soak·breakpoint) 선택, open 모델, 단계 계획, SLO thresholds 를 정한다. 트리거 — "부하 테스트", "스트레스 테스트", "성능 테스트 짜줘", "k6", "locust", "gatling", "jmeter", "몇 rps 버티나", "breakpoint".
---

# 스트레스 테스트 설계 · 작성

규칙 원본: [`references/stress-test-rules.md`](../../references/stress-test-rules.md)
근거: [`references/stress-test-methods.md`](../../references/stress-test-methods.md)
템플릿: [`references/stress-test-templates.md`](../../references/stress-test-templates.md)

결과 해석은 `stress-result-review`, 실행 환경은 `stress-environment-create` 가 맡는다.
서버 쪽 계측(히스토그램 · in-flight)은 언어 · 프레임워크 플러그인(`{언어}-{프레임워크}-stress-test`)이 있으면 그 스킬을 같이 쓴다.

## 1. 질문에 답을 먼저 정한다

| 질문 | 정하지 않으면 |
|---|---|
| 무엇을 알고 싶은가 — SLO 를 지키나 / 한계가 어디인가 / 무너진 뒤 돌아오나 / 오래 버티나 | 유형을 못 고른다 |
| SLO — 어떤 엔드포인트의 p99 · 에러율 기준 | 합격 판정을 못 한다. 서비스가 정한다. 모르면 사용자에게 묻는다 |
| 운영 부하 — 평균 · 피크 rps, 엔드포인트 비율 | RATE 와 요청 섞기를 못 정한다. 운영 로그 · APM 에서 뽑는다 |
| 대상 — 어느 환경 · 호스트 | ST-01 이 막는다. 운영 호스트는 안 된다 |

## 2. 유형을 고른다

| 알고 싶은 것 | 유형 | 템플릿 TYPE |
|---|---|---|
| 평소 · 피크 부하에서 SLO 를 지키나 | load | `load` |
| 평균보다 높은 부하에서 얼마나 나빠지고 돌아오나 | stress | `stress` |
| 갑작스런 폭증 뒤 회복 시간 | spike | `spike` |
| 오래 돌릴 때 누수 · 저하 | soak | `soak` |
| 지속 가능 용량 · knee | breakpoint 또는 단계 루프 | `breakpoint` · `step` |

용량을 수치로 내야 하면 **단계 루프**(템플릿 2절)를 고른다. 단계마다 정상 상태 요약이 남아 knee · USL · Little 을 계산할 수 있다. 연속 램프(`breakpoint`)는 한계 근처를 빠르게 찾는 데 쓴다.

## 3. 측정 설계 — 기계가 보는 것

- **open 모델** (ST-02): k6 `constant-arrival-rate` · `ramping-arrival-rate`, Gatling `constantUsersPerSec` · `rampUsersPerSec`
  - Locust · JMeter 는 closed 루프라 꼬리 지연을 과소 측정한다. 그 도구를 써야 하면 결과에 closed 모델이라고 적는다
- **thresholds** (ST-03) — 예: `http_req_failed: ['rate<0.01']`, `'http_req_duration{expected_response:true}': ['p(99)<300']`
- **p99** (ST-04) — k6 는 `summaryTrendStats` 에 `p(99)` 를 넣는다
- **maxVUs** (ST-05) — `preAllocatedVUs` ≈ RATE × 예상 지연(초), `maxVUs` 는 그 몇 배
- arrival-rate 에 **sleep 금지** (ST-06)

## 4. 측정 설계 — 판단할 것

- **단계** — 6개 이상(ST-11)이다
  - 예상 용량의 30 ~ 150% 를 덮는다
  - 한계 근처는 촘촘하게 잡는다
  - 단계마다 정상 구간을 1분 이상 둔다
  - 단계 사이에 쉰다
- **정상 구간** (ST-30) — 램프 · JIT 워밍업 · 캐시 예열 구간을 판정에서 뺀다. 고정 시간 대신 p50 · 처리량이 안정됐는지 본다
- **요청 섞기** — 운영 엔드포인트 비율대로 섞는다. 같은 키만 반복하면 캐시 적중률이 운영보다 높아진다
- **데이터** — 테스트 데이터 크기를 운영과 비슷하게 둔다. 빈 DB 는 용량을 부풀린다
- **실패 지연** (ST-32) — thresholds 지연은 성공 요청(`expected_response:true`)만 본다

## 5. 작성 절차

1. 템플릿 1절 k6 스크립트를 가져와 요청 부분과 thresholds 를 바꾼다
2. 짧게 돌려 스크립트가 맞는지 본다 — `k6 run -e TYPE=step -e RATE=5 -e UNIT=5s ...`
3. 저장하면 훅이 ST-02 ~ ST-06 을 알린다. 경고마다 고치거나, closed 모델이 맞으면 `stress-test: closed-model` 주석을 남긴다
4. 실행 명령을 정한다. 대상이 허용 목록 밖이면 훅이 막는다 (ST-01)
   - 전용 테스트 환경이 맞으면 사용자에게 확인받고 `.claude/settings.json` 의 `env.STRESS_TEST_ALLOWED_HOSTS` 에 넣는다
5. 환경을 정한다 → `stress-environment-create`

## 하지 않을 것

- 운영 · 공용 호스트에 부하를 걸지 않는다. 훅을 우회하지 않는다
- 사용자가 SLO 를 주지 않았는데 숫자를 지어 기준으로 쓰지 않는다. 예시 값이라고 밝힌다
- 한 번 돌린 결과로 "빨라졌다 · 느려졌다" 를 말하지 않는다 → `stress-result-review` 의 비교 절차
