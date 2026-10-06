# common-stress-test

부하·스트레스 테스트를 정량으로 설계하고 판정한다 — 언어 무관. 운영 호스트 부하 차단, open 모델·thresholds·p99 점검, 단계 결과로 지속 가능 용량·knee·USL·Little 정합성 산출, Mann-Whitney U·Cliff's delta 회귀 판정, local·Docker·k8s 환경 템플릿.

이 플러그인은 언어와 프레임워크에 묶이지 않는 측정 방법을 맡는다. 서버 쪽 계측(지연 히스토그램 · in-flight)과 측정을 무효로 만드는 설정은 `{언어}-{프레임워크}-stress-test` 플러그인이 맡는다. 그 플러그인들이 이 플러그인에 의존한다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-stress-test@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| stress-test-create | 부하 · 스트레스 테스트 짜기, k6 · locust · gatling · jmeter, "몇 rps 버티나" | 유형 선택 · open 모델 · 단계 계획 · thresholds |
| stress-result-review | 결과 분석 · 병목 · p99 · 성능 회귀 | 지속 가능 용량 · knee · USL · Little, 원인 자원, 두 버전 회귀 판정 |
| stress-environment-create | 부하 테스트 환경 · docker compose · k8s | 부하기와 대상 분리 · 자원 고정 · 오토스케일 끄기 · 환경 기록 |
| /stress-script-validate | 직접 호출 | 프로젝트의 부하 스크립트를 `ST-02` ~ `ST-06` 으로 검사한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| stress-target-validate.sh | PreToolUse (Bash) | 부하 도구가 허용 목록 밖 호스트를 겨누면 **차단** (`ST-01`) |
| stress-script-validate.sh | PostToolUse (Write\|Edit) | 저장한 k6 · Gatling · Locust · JMeter 스크립트의 측정 설계를 **알린다** (`ST-02` ~ `ST-06`) |

## 주의

- 허용 목록은 다음과 같다.
  - 루프백, 사설 IPv4
  - 점 없는 이름 (컨테이너 · 서비스 이름)
  - `*.local` · `*.test` · `*.internal`
- 전용 테스트 도메인은 `.claude/settings.json` 의 `env.STRESS_TEST_ALLOWED_HOSTS` 에 넣는다 (쉼표 구분, `*.perf.example.com` 형태 허용)
- 대상 호스트는 다음 위치에서 찾는다.
  - 명령 안의 URL
  - `--host` · `-H`
  - 이름에 `URL` · `HOST` 가 든 변수 대입
  - 명령이 가리키는 스크립트 파일 안의 URL
- 스크립트가 실행 중에 다른 곳에서 대상을 읽으면(설정 서버 등) 보지 못한다
- closed 모델이 맞는 시스템이면 스크립트에 `stress-test: closed-model` 주석을 둔다. `ST-02` 경고가 꺼진다
- 분석 스크립트는 bash · awk · jq 만 쓴다. 부하 도구(k6 등)는 프로젝트가 설치하거나 Docker 이미지로 돌린다
- SLO 값(p99 기준 · 에러율)은 서비스가 정한다. 문서의 `300 ms` · `1%` 는 예시다

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `ST-01` | 부하 대상이 허용 목록 안 | 차단 |
| `ST-02` | 지연 판정은 open 모델 (closed 면 표시) | 경고 |
| `ST-03` | thresholds · assertions 가 있다 | 경고 |
| `ST-04` | p99 를 보고한다 | 경고 |
| `ST-05` · `ST-06` | k6 arrival-rate 에 `maxVUs`, `sleep` 없음 | 경고 |
| `ST-10` | 단계 합격 = p99 · 에러율 · 처리량 · dropped | 판정 |
| `ST-11` | knee · USL 은 6단계 이상 | 경고 |
| `ST-12` | dropped 단계는 지연 과소 측정 | 경고 |
| `ST-13` | Little's Law 정합성 | 경고 |
| `ST-20` | 회귀 = Mann-Whitney U p < 0.05 · \|Cliff's delta\| ≥ 0.147 · 나빠진 방향 | 차단 (exit 2) |
| `ST-30` ~ `ST-35` | 정상 구간 · 분위수 합치기 · 실패 지연 분리 · 환경 기록 · 부하기 분리 · 오토스케일 끄기 | AI 판단 |

원본: [`references/stress-test-rules.md`](references/stress-test-rules.md) · 근거: [`references/stress-test-methods.md`](references/stress-test-methods.md) · 템플릿: [`references/stress-test-templates.md`](references/stress-test-templates.md)

## 사용

```bash
scripts/stress-step-generate.sh --header > steps.csv
scripts/stress-step-generate.sh --load 200 summary.json >> steps.csv         # k6 · Locust · JMeter · Gatling
scripts/stress-report-generate.sh --model open --slo-p99 300 steps.csv       # 용량 · knee · USL · Little
scripts/stress-regression-validate.sh baseline.txt candidate.txt              # 회귀 (exit 2)
test/common-stress-test.test.sh                                               # 회귀 테스트
```

## 근거

ISTQB 용어집 v3.2 · ISO/IEC 25010:2023 · Little (1961 · 2011) · Gunther USL · Satopää et al. 2011 (Kneedle) · Schroeder et al. NSDI 2006 · Tene 2013 (coordinated omission) · Dean & Barroso CACM 2013 · Georges et al. OOPSLA 2007 · Kalibera & Jones ISMM 2013 · Arcuri & Briand ICSE 2011 · Laaber et al. EMSE 2019 · Daly et al. ICPE 2020 · Papadopoulos et al. TSE 2019 · k6 · Prometheus 공식 문서. 각 수치의 출처와 확인 수준은 `references/stress-test-methods.md` 에 있다.

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
