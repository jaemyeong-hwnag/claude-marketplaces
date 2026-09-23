# project-completeness 테스트

`scripts/project-completeness.sh` 의 회귀 테스트.

## 실행

```bash
test/project-completeness.test.sh          # 전체 (~10초)
test/project-completeness.test.sh TC-D     # ID 접두사로 필터
```

임시 디렉터리에 최소 픽스처(매니페스트 · CI 파일 · 소스 몇 줄)를 만들어 판정한다. 네트워크 · 언어 툴체인이 필요 없다 — `bash` · `jq` 만.

구성요소를 하나씩 빼거나 더하는 쌍으로 둔다 (CI 만 ↔ pre-commit + CI, strict 상속 ↔ 상속 뒤 끔, IaC 없음 ↔ Dockerfile).

## detect: 프로젝트 타입

| ID | 케이스 |
|---|---|
| TC-D01 | react 런타임 의존성 → web-frontend |
| TC-D02 | express → backend-api |
| TC-D03 | react + express → fullstack |
| TC-D04 | devDependencies 의 서버 · UI 는 성격을 바꾸지 않는다 |
| TC-D05 | bin 엔트리 → cli |
| TC-D06 | go.mod 에 서버 없음 → library |
| TC-D07 | JS workspaces → monorepo |
| TC-D08 | java-library + 진입점 없음 → library (example 모듈의 main 은 무시) |
| TC-D09 | spring-boot-starter-web + @SpringBootApplication → backend-api |
| TC-D10 | reactor 의존성을 react UI 로 읽지 않는다 |

## detect: 구조 판정

| ID | 케이스 |
|---|---|
| TC-D11 | CI 에 eslint → code.lint-ci 통과 |
| TC-D12 | PR 트리거 · 실패 허용 없음 → code.quality-gate 통과 |
| TC-D13 | 린터가 어디에도 없으면 code.lint-ci 미통과 |
| TC-D14 | continue-on-error: true 면 code.quality-gate 미통과 |
| TC-D15 | 시크릿 스캔이 CI 에만 있으면 미통과 |
| TC-D16 | pre-commit + CI 양쪽이면 통과 |
| TC-D17 | tsconfig 가 strict 설정을 extends 로 상속 → code.type-strict 통과 |
| TC-D18 | 상속해도 strict: false 로 끄면 미통과 |
| TC-D19 | IaC 가 없으면 security.iac-scan 은 판정 보류 |
| TC-D20 | Dockerfile 이 있는데 스캔이 없으면 미통과 |

## detect: 흔적

| ID | 케이스 |
|---|---|
| TC-D21 | 소스에 refund → service.payment-failure 흔적 있음 |
| TC-D22 | fixtures 안의 패턴은 흔적으로 세지 않는다 |
| TC-D23 | 테스트 파일 안의 패턴은 소스 흔적이 아니다 |
| TC-D24 | 소스가 적으면 흔적 대신 판정 보류 |

## detect: 경계

| ID | 케이스 |
|---|---|
| TC-D25 | 빈 디렉터리 → 종료 2 |
| TC-D26 | 디렉터리가 아니면 → 종료 2 |
| TC-D27 | .claude/ 아래 워크트리 사본은 보지 않는다 |
| TC-D28 | 경로에 공백 · 한글이 있어도 동작한다 |
| TC-D29 | 체크리스트의 ⚡ 자동 항목 = detect 가 내는 항목 |

## scope

| ID | 케이스 |
|---|---|
| TC-S01 | --type library 는 N/A 를 뺀 항목만 보인다 |
| TC-S02 | 모르는 타입 → 종료 2 |
| TC-S03 | 레시피가 있는 항목에 표시 |
| TC-S04 | --na 로 선언한 항목은 빠진다 |

## score

| ID | 케이스 |
|---|---|
| TC-C01 | 전부 통과 → 🟢 안전 · 🏆 포괄 |
| TC-C02 | 아무것도 없으면 → 🔴 위험 · ⬜ 최소 |
| TC-C03 | 핵심만 통과 → 🟢 안전 이지만 실천 범위는 좁다 |
| TC-C04 | 모르는 id → 종료 2 |
| TC-C05 | 사용자 선언 N/A 는 따로 표시한다 |
| TC-C06 | 타입 N/A 와 겹치는 선언은 사용자 선언으로 세지 않는다 |
| TC-C07 | N/A 인 핵심 항목은 위험도에 넣지 않는다 (library) |
| TC-C08 | 공백 쉼표 · 앞뒤 공백을 견딘다 |

## health

| ID | 케이스 |
|---|---|
| TC-H01 | 인자 없으면 18지표 목록 |
| TC-H02 | 낮을수록 좋은 지표 — cfr 5 → 최상 |
| TC-H03 | 낮을수록 좋은 지표 — cfr 16 → 위험 |
| TC-H04 | 높을수록 좋은 지표 — slo_attain 94 → 위험 |
| TC-H05 | 높을수록 좋은 지표 — slo_attain 99.5 → 양호 |
| TC-H06 | 모르는 지표 → 종료 2 |
| TC-H07 | 숫자가 아니면 → 종료 2 |
| TC-H08 | 재지 않은 지표를 알린다 |

## recipe

| ID | 케이스 |
|---|---|
| TC-R01 | 항목 id 로 찾는다 — 파일 머리말과 함께 |
| TC-R02 | 이름은 대소문자를 가리지 않는다 |
| TC-R03 | 없으면 종료 1 |
| TC-R05 | 머리말에 구분선(---)을 끌고 오지 않는다 |
| TC-R04 | --list 는 레시피마다 한 줄 |

## 데이터 정합성

| ID | 케이스 |
|---|---|
| TC-X01 | 항목 id 가 겹치지 않고 N/A 가 모두 있는 id 다 |
| TC-X02 | 레시피가 메운다고 한 id 가 모두 체크리스트에 있다 |
| TC-X03 | 모든 레시피에 메우는 항목 · 검증 · 롤백이 있다 |
| TC-X04 | 규칙 원본의 핵심 항목 = 체크리스트의 critical |

## 수동 확인

자동 TC 가 아니다. 탐지 규칙을 바꾸면 실제 저장소 몇 개에 돌려 `projectType` 과 `passed` 가 그럴듯한지 본다 — Node 앱 · Python 패키지 · Go 모듈 · Spring 멀티 모듈 · JVM 라이브러리.

```bash
scripts/project-completeness.sh detect <저장소> | jq '{projectType, projectTypeWhy, passed, unknown}'
```
