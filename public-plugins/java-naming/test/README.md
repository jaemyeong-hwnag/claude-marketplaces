# Java 네이밍 테스트

`scripts/validate-java-naming.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/validate-java-naming.test.sh          # 전체
test/validate-java-naming.test.sh TC-J3    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다.

## 자동 TC (38건)

픽스처는 **규칙을 지키는 파일**(`OrderService.java`)이고, TC 마다 한 곳만 깨뜨린다. 과잉 차단(막으면 안 되는 것)을 막는 TC 를 조항마다 둔다.

### A. CLI 조항 (JN-01 ~ JN-06)

| ID | 케이스 |
|---|---|
| TC-J01 | 이 저장소 전체가 통과한다 |
| TC-J02 | 규칙을 지킨 파일은 조용히 통과한다 |
| TC-J03 | 패키지에 대문자가 있으면 막고 소문자를 제안한다 (JN-01) |
| TC-J04 | 패키지의 밑줄은 경고만 한다 (JN-01) |
| TC-J05 | snake_case 클래스를 막고 UpperCamelCase 를 제안한다 (JN-02) |
| TC-J06 | 인터페이스 · enum · record · 어노테이션도 본다 (JN-02) |
| TC-J07 | public 최상위 타입이 파일 이름과 다르면 막는다 (JN-03) |
| TC-J08 | public 이 아닌 최상위 타입은 파일 이름과 달라도 된다 |
| TC-J09 | 중첩 public 타입은 파일 이름과 비교하지 않는다 |
| TC-J10 | static final int 가 lowerCamelCase 면 막고 UPPER_SNAKE_CASE 를 제안한다 (JN-04) |
| TC-J11 | static final String 도 상수로 본다 (JN-04) |
| TC-J12 | static final Logger · 컬렉션은 판정하지 않는다 |
| TC-J13 | serialVersionUID 는 예외다 |
| TC-J14 | snake_case 필드를 막는다 (JN-05) |
| TC-J15 | 대문자로 시작하는 메서드를 막는다 (JN-05) |
| TC-J16 | 테스트 메서드의 밑줄은 허용한다 |
| TC-J17 | 생성자는 메서드로 보지 않는다 |
| TC-J18 | 같은 줄의 어노테이션 · 제네릭 반환 타입 뒤의 이름을 본다 (JN-05) |
| TC-J19 | 주석 · 문자열 안의 단어는 코드로 읽지 않는다 |
| TC-J20 | 약어가 대문자로 이어지면 경고만 한다 (JN-06) |
| TC-J21 | 디렉터리를 주면 하위 *.java 를 보고 build/ 는 건너뛴다 |
| TC-J22 | package-info.java 는 보지 않는다 |
| TC-J23 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-J24 | --all 은 루트의 .claude/worktrees 를 건너뛴다 |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-J30 | Write 로 위반 파일을 새로 만들면 막는다 |
| TC-J31 | Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다 |
| TC-J32 | 레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다 |
| TC-J33 | Edit 가 새 위반을 만들면 그것만 보고한다 |
| TC-J34 | 이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교) |
| TC-J35 | Edit 로 위반을 고치면 통과한다 |
| TC-J36 | replace_all 을 적용한 결과를 본다 |
| TC-J37 | 한글이 섞인 파일도 치환 위치가 맞다 |
| TC-J38 | 경고만 있으면 additionalContext 로 알리고 통과한다 |
| TC-J39 | *.java 가 아니면 보지 않는다 |
| TC-J40 | build/ 아래 생성 코드는 보지 않는다 |
| TC-J41 | PostToolUse 는 보지 않는다 |
| TC-J42 | 빈 입력 · 경로 없는 입력은 통과한다 |
| TC-J43 | 프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로) |
