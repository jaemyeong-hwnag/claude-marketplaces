# project-completeness

프로젝트가 서비스로서 갖출 것을 갖췄는지 재고 메운다 — 저장소 자동 탐지와 69항목 체크리스트로 위험도 · 실천 범위 진단, 레시피대로 설정 · CI 적용 후 검증 · 롤백, DORA · SLO · 온콜 18지표 실측 판정. 추측 통과 없음.

린트 A 등급을 받으면서도 모든 고객 문의를 개발자가 DB 를 열어 처리하는 서비스가 있다. 코드 품질 도구는 빈 상태 · 환불 경로 · 백업 복원 · 온콜 · 롤백을 보지 않는다. 이 플러그인은 그 질문까지 포함해 **있는가**(체크리스트)와 **잘 되는가**(실측 지표)를 따로 잰다.

```
completeness-review      진단 (읽기 전용)   → 위험도 + 실천 범위 + 가장 비어 있는 축
completeness-apply       레시피로 설정 · CI  → 검증 → 실패하면 롤백
service-health-review    실측 수치          → 지표별 판정 + 미측정 목록
```

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install project-completeness@jaemyeong-hwnag-plugins --scope project
```

필요한 것: `bash`, `jq`, `find`, `grep`. 레시피를 적용할 때는 그 레시피의 도구(Node · Python · Go 툴체인, Docker 등).

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| completeness-review | 완성도 점검 · 품질 진단 · 뭐부터 도입 | `detect` → 측정 범위 선택 → ⚡ 자동 · ▶️ 실행 · 💬 질문으로 판정 → `score` |
| completeness-apply | 적용해줘 · CI 에 붙여줘 · 린트 도입 | 한 축씩 레시피 → 계획 동의 → 적용 → 검증 → 실패 시 롤백. 커밋하지 않는다 |
| service-health-review | 서비스 건강도 · DORA · 온콜 · 알림 피로 | 아는 값만 모아 `health` 로 판정. 재지 않은 지표를 따로 보고 |

## 주의

- **추측 통과가 없다.** 확인하지 못한 항목은 미통과로 센다 — 점수가 낮게 나오는 것이 정상이다
- `detect` 의 `hints` 는 판정이 아니다. 소스에 `refund` 가 있어도 그것이 동작하는 환불 경로인지는 코드를 읽거나 물어서 정한다
- **위험도와 실천 범위는 다른 질문이다.** 핵심 12항목을 갖춘 라이브러리는 범위가 20% 여도 위험하지 않다
- 언어 레시피는 Node · Python · Go 만 있다. Java · Kotlin 은 탐지는 되지만 레시피는 공통 · 운영 · 서비스 것만 적용된다
- 레시피의 버전 · 설정 형식은 낡는다. 설치한 버전과 형식이 다르면 스킬이 멈추고 알린다
- `completeness-apply` 는 파일을 고치지만 커밋하지 않는다. 처음 넣는 검사는 CI 를 실패시키지 않는다 (시크릿 · Critical 취약점 제외)

## 무엇을 재나

| 축 | 항목 | 핵심 | 예 |
|---|---:|---:|---|
| `code` 코드 | 10 | 2 | 린터 CI 강제 · 신규 코드 게이트 · CODEOWNERS · 아키텍처 경계 |
| `test` 테스트 | 7 | 1 | 커버리지 · 뮤테이션 · 핵심 플로우 E2E · 실제 DB 통합 |
| `security` 보안 | 8 | 3 | 시크릿 스캔 · SAST · SCA + SBOM · 의존성 자동 갱신 |
| `perf` 성능 | 7 | 0 | Core Web Vitals · 성능 · 번들 예산 · 부하 테스트 |
| `ux` 접근성 · UX | 6 | 0 | axe 위반 0 · 수동 스크린리더 · WCAG 2.2 |
| `ops` 운영 | 7 | 3 | 트레이스 · SLO · 온콜 · 런북 · 롤백 · 포스트모템 |
| `service` 서비스 완성도 | 19 | 3 | 빈 · 에러 · 로딩 상태 · 환불 경로 · 운영 도구 · 백업 복원 · 렌더 스모크 · 명세 ↔ 구현 |
| `product` 제품 · 조직 | 5 | 0 | 퍼널 · 실험 · DORA 수집 · DevEx |

프로젝트 타입(`backend-api` · `library` · `cli` …)마다 구조적으로 해당 없는 항목은 N/A 로 빠진다.

## 파일

| 경로 | 역할 |
|---|---|
| `references/completeness-rules.md` | 규칙 원본 — 판정 원칙 `Q-01` ~ `Q-07`, 적용 원칙 `Q-11` ~ `Q-19`, 게이트 단계, 축 순서, 레시피 형식 |
| `references/completeness-checklist.json` | 항목 · 핵심 · 측정 방식 · 프로젝트 타입별 N/A · 등급 경계 |
| `references/service-health-metrics.json` | 건강도 지표 · 기준 |
| `references/recipe-*.md` | 도입 레시피 — 공통 · Node · Python · Go · 운영 · 서비스 |
| `scripts/project-completeness.sh` | `detect` · `scope` · `score` · `health` · `recipe` |
| `test/` | 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 진단 스킬 발동(`completeness-request`) |

## 사용

```bash
S=scripts/project-completeness.sh
$S detect .                                          # 저장소 흔적 → JSON
$S scope --type backend-api                          # 측정할 수 있는 항목
$S score --type backend-api --pass code.lint-ci,security.secret-scan --na code.ai-provenance
$S health cfr=8 recovery=45 pages_week=12            # 인자 없으면 지표 목록
$S recipe security.secret-scan                       # 항목을 메우는 레시피
test/project-completeness.test.sh                    # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
