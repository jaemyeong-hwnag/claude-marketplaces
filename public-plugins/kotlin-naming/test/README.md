# Kotlin 네이밍 테스트

`scripts/validate-kotlin-naming.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/validate-kotlin-naming.test.sh          # 전체
test/validate-kotlin-naming.test.sh TC-K3    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다.

## 자동 TC (40건)

픽스처는 **규칙을 지키는 파일**(`OrderService.kt`)이고, TC 마다 한 곳만 깨뜨린다. 과잉 차단(막으면 안 되는 것)을 막는 TC 를 조항마다 둔다.

### A. CLI 조항 (KN-01 ~ KN-07)

| ID | 케이스 |
|---|---|
| TC-K01 | 이 저장소 전체가 통과한다 |
| TC-K02 | 규칙을 지킨 파일은 조용히 통과한다 |
| TC-K03 | 패키지 조각이 대문자로 시작하면 막고 소문자를 제안한다 (KN-01) |
| TC-K04 | 패키지의 밑줄은 경고만 한다 (KN-01) |
| TC-K05 | snake_case data class 를 막고 UpperCamelCase 를 제안한다 (KN-02) |
| TC-K06 | interface · object · enum · annotation · sealed · value class · fun interface · typealias 도 본다 (KN-02) |
| TC-K07 | 이름 없는 companion object · object 식 · ::class 는 타입 선언으로 보지 않는다 (KN-02 과잉 차단 방지) |
| TC-K08 | 최상위 선언이 클래스 하나뿐인데 파일 이름이 다르면 막는다 (KN-03) |
| TC-K09 | 최상위 선언이 여럿이면 파일 이름과 비교하지 않고, 소문자 파일 이름은 경고만 한다 (KN-03) |
| TC-K10 | 멀티플랫폼 접미사(Platform.jvm.kt)는 떼고 비교한다 (KN-03 과잉 차단 방지) |
| TC-K11 | const val 이 lowerCamelCase 면 막고 SCREAMING_SNAKE_CASE 를 제안한다 (KN-04) |
| TC-K12 | SCREAMING_SNAKE_CASE const val · serialVersionUID 는 통과한다 (KN-04 과잉 차단 방지) |
| TC-K13 | 대문자 · snake_case 함수와 확장 함수를 막는다 (KN-05) |
| TC-K14 | 백틱 이름 · 테스트 경로의 밑줄은 허용한다 (KN-05 과잉 차단 방지) |
| TC-K15 | 테스트 경로가 아니면 함수 이름의 밑줄을 막는다 (KN-05) |
| TC-K16 | @Composable 함수는 대문자로 시작해도 된다 — 같은 줄 · 위 어노테이션 줄 (KN-05 과잉 차단 방지) |
| TC-K17 | 반환 타입이 이름과 같은 팩터리 함수는 허용하고, 다르면 막는다 (KN-05) |
| TC-K18 | snake_case val · var 를 막는다 — 생성자 프로퍼티 · 지역 변수 · 확장 프로퍼티 (KN-06) |
| TC-K19 | 백킹 프로퍼티 · SCREAMING_SNAKE_CASE · UpperCamelCase val · 구조 분해는 통과한다 (KN-06 과잉 차단 방지) |
| TC-K20 | 주석 · 중첩 블록 주석 · 문자열 · raw string 안의 단어는 코드로 읽지 않는다 |
| TC-K21 | 약어가 대문자 4개 이상 이어지면 경고만 하고, IOStream 은 허용한다 (KN-07) |
| TC-K22 | 디렉터리를 주면 하위 *.kt 를 보고 build/ · *.kts 는 건너뛴다 |
| TC-K23 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-K24 | --all 은 루트의 .claude/worktrees 를 건너뛴다 |
| TC-K25 | 패키지 조각의 camelCase 는 허용한다 — 공식 컨벤션 (KN-01 과잉 차단 방지) |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-K30 | Write 로 위반 파일을 새로 만들면 막는다 |
| TC-K31 | Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다 |
| TC-K32 | 레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다 |
| TC-K33 | Edit 가 새 위반을 만들면 그것만 보고한다 |
| TC-K34 | 이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교) |
| TC-K35 | Edit 로 위반을 고치면 통과한다 |
| TC-K36 | replace_all 을 적용한 결과를 본다 |
| TC-K37 | 한글이 섞인 파일도 치환 위치가 맞다 |
| TC-K38 | 경고만 있으면 additionalContext 로 알리고 통과한다 |
| TC-K39 | *.kt 가 아니면 보지 않는다 (*.kts 포함) |
| TC-K40 | build/ 아래 생성 코드는 보지 않는다 |
| TC-K41 | PostToolUse 는 보지 않는다 |
| TC-K42 | 빈 입력 · 경로 없는 입력은 통과한다 |
| TC-K43 | 프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로) |
| TC-K44 | 프로젝트가 test/ 폴더 아래 있어도 main 소스에 테스트 밑줄 허용을 주지 않는다 |
