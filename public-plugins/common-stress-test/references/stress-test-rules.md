# 스트레스 테스트 측정 규칙 (단일 원본)

부하 · 스트레스 테스트를 **어떻게 걸고 어떻게 판정하는가**를 정한다. 언어 · 프레임워크와 무관하다.
서버 쪽 계측과 프레임워크 설정은 `{언어}-{프레임워크}-stress-test` 플러그인이 맡는다.

이론과 근거는 [`stress-test-methods.md`](stress-test-methods.md), 스크립트 · 환경 예시는 [`stress-test-templates.md`](stress-test-templates.md) 에 있다.

## 1. 용어

| 유형 | 정의 | 무엇을 판정하나 |
|---|---|---|
| load | 예상 범위(낮음 · 보통 · 피크)의 부하에서 동작을 본다 | SLO 를 지키는가 |
| stress | 예상 · 명세 부하의 한계 **또는 그 너머**, 또는 자원을 줄인 상태에서 본다 | 어디서 어떻게 무너지는가, 무너진 뒤 돌아오는가 |
| spike | 갑작스런 피크 뒤 **정상 상태로 돌아오는** 능력 | 회복 시간 |
| soak (endurance) | 상당한 부하를 오래 유지한다 | 지연 증가 · 메모리 누수 · 저장소 고갈 |
| breakpoint (capacity) | 실패할 때까지 도착률을 올린다 | 지속 가능 용량 · knee |

근거는 ISTQB 용어집 v3.2 (stress · load · spike · endurance · capacity testing), ISO/IEC 25010:2023 §3.2 (time behaviour · resource utilization · capacity) 다.

## 2. 조항

| 조항 | 내용 | 판정 | 담당 |
|---|---|---|---|
| `ST-01` | 부하 도구가 겨누는 호스트가 허용 목록 안이다 | **차단** | `stress-target-validate.sh` (PreToolUse Bash) |
| `ST-02` | 지연을 판정하는 테스트는 **open 모델**(도착률 고정)로 건다. closed 모델이면 그렇게 표시한다 | 경고 | `stress-script-validate.sh` |
| `ST-03` | 스크립트에 합격 기준(thresholds · assertions)이 있다 | 경고 | 〃 |
| `ST-04` | p99 를 보고한다 (p50 · p95 · max · 에러율 · 처리량과 함께) | 경고 | 〃 · `stress-report-generate.sh` |
| `ST-05` | k6 arrival-rate executor 에 `maxVUs` 를 둔다 | 경고 | `stress-script-validate.sh` |
| `ST-06` | k6 arrival-rate executor 에 `sleep()` 을 넣지 않는다 | 경고 | 〃 |
| `ST-10` | 단계 합격 = p99 < SLO · 에러율 < 기준 · (open 이면) 처리량 ≥ 목표 × 0.95 · dropped 0 | 판정 | `stress-report-generate.sh` |
| `ST-11` | knee · USL 은 **6단계 이상**에서만 계산한다 | 경고 | 〃 |
| `ST-12` | 부하기가 목표 도착률을 못 낸 단계(dropped)는 지연이 과소 측정이다 | 경고 | 〃 |
| `ST-13` | 단계마다 Little's Law(L = λW)가 맞는다 | 경고 | 〃 |
| `ST-20` | 회귀는 반복 측정 분포로 판정한다 — Mann-Whitney U 와 Cliff's delta | **차단**(exit 2) | `stress-regression-validate.sh` |
| `ST-30` | 정상 상태 구간만 잰다 — 램프 · 워밍업을 뺀다 | AI 판단 | `stress-test-create` · `stress-result-review` |
| `ST-31` | 분위수를 평균 내지 않는다 — 히스토그램 · 원자료를 합친 뒤 계산한다 | AI 판단 | 〃 |
| `ST-32` | 실패 요청의 지연을 성공 요청과 섞지 않는다 | AI 판단 | 〃 |
| `ST-33` | 환경을 기록한다 — 버전 · 인스턴스 · CPU/메모리 제한 · 부하기 위치 · 반복 수 | AI 판단 | `stress-environment-create` |
| `ST-34` | 부하기와 대상이 자원을 나눠 쓰지 않는다. 부하기 자신이 병목이 아닌지 본다 | AI 판단 | 〃 |
| `ST-35` | breakpoint · stress 에서는 오토스케일을 끈다 | AI 판단 | 〃 |

### ST-01 — 허용 목록

| 허용 | 예 |
|---|---|
| 루프백 · 미지정 | `localhost` · `*.localhost` · `127.*` · `::1` · `0.0.0.0` |
| 사설 IPv4 | `10.*` · `172.16.*` ~ `172.31.*` · `192.168.*` |
| 점 없는 이름 | 컨테이너 · compose · k8s 서비스 이름 (`app`, `api`) |
| 예약 도메인 | `*.local` · `*.test` · `*.internal` · `host.docker.internal` |
| 사용자 지정 | `STRESS_TEST_ALLOWED_HOSTS` — 쉼표 · 공백 구분, `*.perf.example.com` 처럼 앞 와일드카드 |

**보는 곳**
- 명령 안의 URL, 이름에 `URL` · `HOST` 가 든 변수 대입(`-e BASE_URL=api.example.com`)
- `--host` · `-H`
- 명령이 가리키는 스크립트 파일(`*.js` · `*.py` · `*.jmx` · …) 안의 URL과 JMX `HTTPSampler.domain`
- `-f` 없는 `locust` 는 `locustfile.py`

`import` · `require` 줄의 URL(예: k6 jslib)은 보지 않는다.

**부하 명령으로 보는 것** — 명령 구간의 첫 단어
- `k6 run|cloud` · `locust` · `jmeter` · `gatling` · `wrk` · `wrk2` · `vegeta attack` · `hey` · `oha` · `ab` · `artillery run|quick` · `autocannon`
- 그 이미지를 쓰는 `docker run`
- `mvn` · `gradle` 의 gatling 태스크

**설정 방법** — `STRESS_TEST_ALLOWED_HOSTS` 는 프로젝트 `.claude/settings.json` 의 `env` 에 둔다.

**막는 이유** — 스트레스 테스트는 정의상 한계 너머까지 부하를 건다. 운영이나 남의 호스트에 걸면 그 자체가 장애다.

### ST-02 — open 모델

**두 모델의 차이**
- closed 모델: 사용자 N명이 응답을 받아야 다음 요청을 보낸다.
  - k6 `constant-vus` · `ramping-vus` · `*-iterations`
  - Gatling `constantConcurrentUsers` · `rampConcurrentUsers`
  - Locust · JMeter 스레드 그룹
- closed 모델은 서버가 느려지면 **부하도 같이 줄어든다**. 그래서 꼬리 지연이 과소 측정된다 (coordinated omission).

**근거**
- Schroeder · Wierman · Harchol-Balter, NSDI 2006: 같은 부하에서 open 모델의 평균 응답시간이 closed 보다 한 자릿수 이상 클 수 있다.
- Tene 2013: closed 부하기의 99%ile 이 1,000배 틀린 사례.
- **실측**: 10초마다 2초 멈추는 서버에서 closed 1 VU 는 p99 4 ms, open 100 rps 는 p99 1,913 ms 였다.

**open 모델 executor**
- k6 `constant-arrival-rate` · `ramping-arrival-rate`
- Gatling `constantUsersPerSec` · `rampUsersPerSec`

**closed 모델이 맞는 경우** — 실제 시스템이 closed 일 때다. 예: 세션당 요청이 10개 이상인 partly-open, 배치 워커 수 고정. 이때는 파일에 `stress-test: closed-model` 주석을 두고, 결과에 모델을 적는다.

### ST-04 · ST-05 · ST-06 — k6 기본값의 함정 (k6 공식 문서)

- **ST-04**: 기본 `summaryTrendStats` 는 `avg,min,med,max,p(90),p(95)` 다. p99 가 없다.
- **ST-05**: `maxVUs` 를 두지 않으면 `preAllocatedVUs` 와 같다. 서버가 느려지면 빈 VU 가 없어 iteration 을 버리고 `dropped_iterations` 로 센다. 버린 요청의 지연은 측정되지 않는다.
- **ST-06**: arrival-rate executor 는 도착률을 직접 정한다. 문서는 iteration 끝에 `sleep` 을 두지 말라고 한다.

### ST-10 — 단계 판정과 지속 가능 용량

- **지속 가능 용량**: 그 단계와 **그 아래 모든 단계**가 합격한 최대 부하다.
- **sustain 비율 0.95**: open 모델에서 목표를 실제로 냈는지 보는 이 플러그인의 기본값이다. `--sustain` 으로 바꾼다.
- **SLO 값**: 서비스가 정한다. 예시로 쓰는 `p99 < 300 ms` · `에러율 < 1%` 는 기준이 아니다.
  - 국내 감리 가이드의 "응답 3초" 도 양식에 실린 예시일 뿐이다.

### ST-11 — 단계 수

Gunther 는 USL 피팅에 정상 상태 측정점 **최소 6개**를 권한다. knee 도 같은 하한을 쓴다.

### ST-13 — Little's Law

**검사식**
- open 모델: 서버 in-flight 평균 L ≈ 처리량 × 평균 응답시간
- closed 모델: N ≈ 처리량 × (평균 응답시간 + think time)

**근거** — Little 2011 LL.1 은 구간의 시작과 끝이 비어 있으면 정확히 성립한다. 비정상 상태나 큐 규율과도 무관하다. 그래서 어긋나면 **측정이 틀린 것**이다. 원인 후보:
- LB · 커넥션 풀 대기가 응답시간에서 빠졌다.
- 에러 요청이 빠졌다.
- 램프 구간이 섞였다.

**허용 폭** — 기본 ±10% 는 이 플러그인의 값이다. `--little-tolerance` 로 바꾼다.

**실측** — closed 10단계(N = 1 ~ 32)에서 비율이 0.99 ~ 1.00 이었다.

### ST-20 — 회귀 판정

**판정식** — 다음 셋을 모두 만족하면 회귀다.
- p < 0.05
- |Cliff's delta| ≥ 0.147
- 나빠진 방향

**근거**
- Arcuri & Briand, ICSE 2011: Mann-Whitney U 와 효과 크기를 쓰고, p 는 모두 보고한다.
- Cliff's delta 크기 구분(Romano et al. 2006): 0.147 미만 무시할 만함, 0.33 미만 작음, 0.474 미만 중간, 그 이상 큼.
- Laaber et al., EMSE 2019: Wilcoxon(= Mann-Whitney) 순위합이 bootstrap 보다 작은 감속을 잡았다.
- Daly et al., ICPE 2020: 고정 % 임계는 거짓 양성이 최대 99% 였다.

**표본**
- 최소 5개다. 이보다 적으면 정확 검정으로도 p < 0.05 가 안 나올 수 있다.
- 기준과 후보는 **같은 머신에서 번갈아 무작위 순서로** 돌린다. Laaber 2019 는 이렇게 할 때 감속 탐지가 가장 좋았다.

### ST-30 ~ ST-35 — 판단할 것

| 조항 | 근거 |
|---|---|
| ST-30 | Jiang & Hassan TSE 2015 (워밍업 · 쿨다운 제외). Barrett OOPSLA 2017 · Traini EMSE 2023 — steady state 에 늘 도달하지는 않고 개발자가 정한 워밍업은 19% 만 맞았다. 고정 시간 대신 지표가 안정됐는지 본다 |
| ST-31 | Prometheus 문서 — 미리 계산한 분위수를 평균 내는 것은 "rarely makes sense". 버킷을 합친 뒤 `histogram_quantile` |
| ST-32 | Google SRE 6장 — 실패 요청의 지연을 구분한다. 빠른 실패는 분위수를 낮춘다 |
| ST-33 | Papadopoulos et al. TSE 2019 원칙 P1 ~ P8 — 클라우드 성능 논문의 90% 이상이 통계 평가를 하지 않았고, 63% 이상이 분산 없이 평균만 냈다 |
| ST-34 | Laaber 2019 · Leitner & Cito 2016 — 같은 인스턴스 유형도 성능이 다르다. 부하기가 CPU 포화면 결과는 부하기의 한계다 |
| ST-35 | k6 breakpoint 문서 — 오토스케일을 켜 두면 한계 대신 청구 한도를 재게 된다 |

## 3. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | 스크립트 | `ST-01` ~ `ST-06` · `ST-10` ~ `ST-13` · `ST-20` |
| 판단 | 스킬 | 테스트 유형 · 단계 설계 · SLO 값 · 정상 구간 · 원인 자원(USE) · knee 와 SLO 중 운영 상한 · 환경 기록 |

## 4. 훅

| 이벤트 | 대상 | 동작 |
|---|---|---|
| `PreToolUse(Bash)` | 부하 도구 실행 명령 | `ST-01` 위반이면 **차단** |
| `PostToolUse(Write\|Edit)` | k6 · Gatling · Locust · JMeter 스크립트 | `ST-02` ~ `ST-06` 을 **알린다** |

스크립트 경고는 막지 않는다. closed 모델이 맞는 시스템도 있고, 스크립트를 여러 번 고쳐 완성하기 때문이다.

## 5. 명령

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/stress-target-validate.sh" 'k6 run -e BASE_URL=api.example.com t.js'   # ST-01
"${CLAUDE_PLUGIN_ROOT}/scripts/stress-script-validate.sh" [--strict] [경로 ...]                                # ST-02 ~ ST-06
"${CLAUDE_PLUGIN_ROOT}/scripts/stress-step-generate.sh" --header                                               # 단계 CSV 머리
"${CLAUDE_PLUGIN_ROOT}/scripts/stress-step-generate.sh" --load 200 summary.json                                # 결과 → 한 줄
"${CLAUDE_PLUGIN_ROOT}/scripts/stress-report-generate.sh" --model open --slo-p99 300 --target 200 steps.csv     # ST-10 ~ ST-13
"${CLAUDE_PLUGIN_ROOT}/scripts/stress-regression-validate.sh" baseline.txt candidate.txt                       # ST-20
```

모든 스크립트는 bash · awk · jq 만 쓴다.
