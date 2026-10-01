---
name: stress-result-review
description: 부하·스트레스 테스트 결과를 정량 판정할 때 사용한다. 단계 결과로 지속 가능 용량·knee·USL·Little 정합성을 내고, 두 버전 비교는 Mann-Whitney U·Cliff's delta 로 회귀를 판정한다. 트리거 — "결과 분석", "몇 rps 까지", "병목", "p99", "느려졌나", "성능 회귀", "summary.json", "stats.csv".
---

# 스트레스 테스트 결과 판정

규칙 원본: [`references/stress-test-rules.md`](../../references/stress-test-rules.md)
근거: [`references/stress-test-methods.md`](../../references/stress-test-methods.md)

숫자는 스크립트가 낸다. 이 스킬은 **어떤 숫자를 믿을지와 무엇이 원인인지**를 판단한다.

## 1. 결과를 단계 CSV 로 모은다

```bash
P="${CLAUDE_PLUGIN_ROOT}/scripts"
"$P/stress-step-generate.sh" --header > steps.csv
"$P/stress-step-generate.sh" --load 100 out/step-100.json >> steps.csv     # k6 · Locust stats.csv · JMeter statistics.json · Gatling 콘솔
```

- `--load` 는 open 모델이면 목표 rps, closed 모델이면 동시 사용자 수다
- 서버 in-flight 평균을 알면 `--inflight` 를 넣는다 (Little 검사). 프레임워크 플러그인의 계측이 이 값을 준다

## 2. 판정한다

```bash
"$P/stress-report-generate.sh" --model open --slo-p99 300 [--target 200] steps.csv
```

| 항목 | 읽는 법 |
|---|---|
| 단계 판정 (ST-10) | p99 · 에러율 · 처리량 미달(open) · dropped 중 무엇이 깨졌나 |
| 지속 가능 용량 | 그 단계와 아래가 모두 합격한 최대 부하 — **보고할 용량은 이것** |
| knee (Kneedle) | 효율이 꺾이는 점. 용량보다 낮으면 여유가 줄어드는 지점으로 보고한다 |
| USL (closed) | α 가 크면 직렬화(락 · 단일 스레드 · 풀), β > 0 이면 일관성 비용. N_max 를 넘는 동시성은 처리량을 줄인다. R² < 0.9 면 USL 모양이 아니다 — 고정 상한(풀 크기)을 의심한다 |
| Little (ST-13) | 비율이 1 에서 벗어나면 **측정이 틀렸다** — 결론을 내기 전에 원인부터 찾는다 |

## 3. 믿기 전에 확인한다 (판단)

1. **부하기가 목표를 냈나** — dropped(ST-12) 나 처리량 미달이 있으면 그 단계 지연은 과소 측정이다. 부하기 CPU · 네트워크가 포화였는지 본다 (ST-34)
2. **open 모델인가** — closed 결과(Locust · JMeter · VU 고정)는 꼬리 지연이 낮게 나온다 (ST-02). 보고서에 모델을 쓴다
3. **정상 구간인가** — 워밍업 · 램프가 섞였으면 그 구간을 빼고 다시 요약한다 (ST-30)
4. **분위수를 합치지 않았나** — 여러 부하기 · 인스턴스의 p99 를 평균 내지 않았는지 본다 (ST-31)
5. **실패 지연이 섞이지 않았나** — 에러가 많은 단계의 p99 가 오히려 낮으면 빠른 실패 때문이다 (ST-32)

## 4. 원인을 찾는다 (판단)

부하기 쪽 RED 로 **어느 단계에서** 깨졌는지 찾는다. 같은 시각 서버 쪽 USE 로 **무엇이** 포화됐는지 찾는다.

| 보인 것 | 의심할 것 |
|---|---|
| 처리량이 평평한데 CPU 여유 | 풀(스레드 · DB 커넥션 · 워커) 상한 — in-flight 가 풀 크기에 붙어 있다 |
| CPU 포화와 함께 꺾임 | 계산 비용 — 프로파일러로 상위 함수 |
| 지연만 오르고 처리량 유지 | 대기열 — 이용률이 knee 를 넘었다 (M/M/m knee 표) |
| 처리량이 오히려 감소 | 경합 · 일관성 (USL β), GC, 재시도 폭증 |
| 에러가 갑자기 | 타임아웃 · 커넥션 거부 · 메모리 |

## 5. 두 버전 비교 — 회귀 판정

한 번씩 돌려 비교하지 않는다.

1. 기준과 후보를 **같은 환경에서 번갈아, 무작위 순서로** 각각 5회 이상(가능하면 10회 이상) 돌린다 (Laaber 2019)
2. 실행마다 비교할 값 하나를 뽑는다 — 고정 부하에서의 p99, 또는 지속 가능 용량
3. 판정한다

```bash
"$P/stress-regression-validate.sh" baseline-p99.txt candidate-p99.txt                     # 지연 — 작을수록 좋음
"$P/stress-regression-validate.sh" --higher-is-better baseline-rps.txt candidate-rps.txt  # 처리량
```

- exit 2 = 회귀다 (ST-20). p 와 Cliff's delta 를 같이 보고한다 (Arcuri & Briand)
- "유의한 회귀 없음" 은 "같다" 가 아니다 — 표본이 적으면 차이를 못 본다
- 기준끼리 비교(A/A)해서 회귀가 나오면 환경 노이즈가 크다. 판정을 믿기 전에 환경부터 고친다

## 6. 보고

남길 것: 질문 · 유형 · 모델(open/closed) · 단계 표 · 지속 가능 용량 · knee · 원인 자원 · 환경(ST-33) · 반복 수 · 판정 근거 조항.
평균 · 표준편차만으로 지연을 요약하지 않는다. p50 · p95 · p99 · max 를 쓴다.
