# common-stress-test 테스트

`scripts/` 다섯 개의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/common-stress-test.test.sh          # 전체
test/common-stress-test.test.sh TC-S5    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. 부하 도구 · Docker 없이 돈다 (bash · awk · jq).

## 자동 TC (42건)

차단(위반을 잡는다) TC 와 허용(잡으면 안 되는 것) TC 를 조항마다 둔다. 단계 판정 · 회귀 판정 픽스처는 실측 데이터와 scipy 로 검산한 값이다.

### A. ST-01 대상 호스트 (`stress-target-validate.sh`)

| ID | 케이스 |
|---|---|
| TC-S01 | 명령 안의 공용 호스트 URL 을 막는다 |
| TC-S02 | 루프백 · 사설 IP · 점 없는 이름 · 예약 도메인은 허용한다 |
| TC-S03 | 172.32 · 공인 IP 는 사설이 아니다 |
| TC-S04 | 스킴 없는 URL · HOST 변수 대입도 본다 |
| TC-S05 | vegeta 는 파이프 앞의 URL 을 본다 |
| TC-S06 | locust --host 와 -f 없는 locustfile.py 를 본다 |
| TC-S07 | 명령이 가리키는 스크립트 안의 URL 을 보고, import 줄은 보지 않는다 |
| TC-S08 | JMX 의 HTTPSampler.domain 을 본다 |
| TC-S09 | STRESS_TEST_ALLOWED_HOSTS — 정확한 이름 · 앞 와일드카드 (접미사 위장은 막는다) |
| TC-S10 | 부하 도구가 아닌 명령은 보지 않는다 |
| TC-S11 | docker 이미지 · compose 서비스 · gatling 빌드 태스크도 부하 명령이다 |
| TC-S12 | 훅 — 위반은 exit 2, 통과는 조용, 빈 입력 · 다른 도구는 통과 |

### B. ST-02 ~ ST-06 부하 스크립트 (`stress-script-validate.sh`)

| ID | 케이스 |
|---|---|
| TC-S20 | 규칙을 지킨 k6 스크립트는 경고가 없다 |
| TC-S21 | k6 closed 모델 · thresholds · p99 없음 · closed 표시 주석 |
| TC-S22 | k6 arrival-rate 의 maxVUs 없음(ST-05) · sleep(ST-06) |
| TC-S23 | Gatling — closed 주입 · assertions 없음, open + assertions 는 통과 |
| TC-S24 | Locust · JMeter 는 closed 루프라고 알린다 |
| TC-S25 | 부하 스크립트가 아닌 .js · .py · .java 는 보지 않는다 |
| TC-S26 | 디렉터리 검사는 node_modules 를 건너뛴다 |
| TC-S27 | --strict 는 경고가 있으면 exit 2 |
| TC-S28 | 훅 — PostToolUse 에서 additionalContext 로 알린다. PreToolUse · 비대상 파일은 조용 |

### C. 결과 → 단계 CSV (`stress-step-generate.sh`)

| ID | 케이스 |
|---|---|
| TC-S40 | k6 --summary-export |
| TC-S41 | k6 handleSummary 형식(.values) · p(50) 없으면 med |
| TC-S42 | Locust stats.csv 의 Aggregated 줄 |
| TC-S43 | JMeter statistics.json 의 Total (errorPct 는 % 단위) |
| TC-S44 | Gatling 3.2 콘솔 형식 |
| TC-S45 | Gatling 3.16 콘솔 형식 (표 · 단위 표기) |
| TC-S46 | --load 없음 · 모르는 형식은 오류(1) |

### D. 단계 판정 (`stress-report-generate.sh`)

| ID | 케이스 |
|---|---|
| TC-S50 | 실측 open 7단계 — 용량 · 처리량 knee · p99 knee 가 180 |
| TC-S51 | --target — 합격 단계는 0, 불합격 2, 없는 단계 1 |
| TC-S52 | dropped 단계를 경고한다 (ST-12) |
| TC-S53 | 6단계 미만이면 knee · USL 을 계산하지 않는다 (ST-11) |
| TC-S54 | USL — 알려진 계수(α 0.05 · β 0.001)를 되찾는다 |
| TC-S55 | USL — 고정 상한처럼 모양이 다르면 R² 경고 |
| TC-S56 | Little — closed 실측은 맞고(경고 없음), in-flight 가 어긋나면 ST-13 |
| TC-S57 | 열 순서가 달라도 이름으로 읽고, load · throughput 이 없으면 오류 |

### E. ST-20 회귀 판정 (`stress-regression-validate.sh`)

| ID | 케이스 |
|---|---|
| TC-S60 | 명확한 회귀 — 정확 검정 p 가 scipy 와 같다 (0.0001554) |
| TC-S61 | 차이 없음은 0 |
| TC-S62 | 동률이 있으면 정규 근사 — scipy 와 같다 (U=3 · p=0.0181) |
| TC-S63 | --higher-is-better — 처리량 감소는 회귀, 증가는 개선 |
| TC-S64 | 유의해도 효과 크기가 작으면 회귀가 아니다 |
| TC-S65 | 표본 5개 미만 · 숫자가 아닌 값은 오류(1) |

## eval (`evals/`)

| 케이스 | 확인 |
|---|---|
| capacity-test-design | 스킬 이름 없는 용량 질문에 `stress-test-create` 발동 + 답에 `arrival-rate` |
| public-target-blocked | 공용 호스트 k6 실행을 훅이 `ST-01` 로 막는다 (Bash 샌드박스 필요) |
