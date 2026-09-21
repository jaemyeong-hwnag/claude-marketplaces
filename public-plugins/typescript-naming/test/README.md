# TypeScript 네이밍 테스트

`scripts/validate-typescript-naming.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/validate-typescript-naming.test.sh          # 전체
test/validate-typescript-naming.test.sh TC-T3    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다.

## 자동 TC (37건)

픽스처는 **규칙을 지키는 파일**(`order-service.ts`)이고, TC 마다 한 곳만 깨뜨린다. 과잉 차단(막으면 안 되는 것)을 막는 TC 를 조항마다 둔다.

### A. CLI 조항 (TS-01 ~ TS-06)

| ID | 케이스 |
|---|---|
| TC-T01 | 이 저장소 전체가 통과한다 |
| TC-T02 | 규칙을 지킨 파일은 조용히 통과한다 |
| TC-T03 | snake_case 클래스를 막고 PascalCase 를 제안한다 (TS-01) |
| TC-T04 | abstract class · interface · type · enum · namespace · declare · export default 도 본다 (TS-01) |
| TC-T05 | type · class 를 이름으로 쓰거나 선언이 아닌 곳은 보지 않는다 (TS-01 과잉 차단 방지) |
| TC-T06 | interface 의 I 접두사는 경고만 한다 (TS-02) |
| TC-T07 | I 로 시작하는 일반 이름은 경고하지 않는다 (TS-02 과잉 경고 방지) |
| TC-T08 | 소문자 snake_case 변수를 막고 camelCase 를 제안한다 (TS-03) |
| TC-T09 | function · async function · export default function · generator 도 본다 (TS-03) |
| TC-T10 | UPPER_SNAKE · PascalCase · 앞뒤 밑줄 · 구조 분해 · declare 는 통과한다 (TS-03 과잉 차단 방지) |
| TC-T11 | 대문자로 시작하는 snake 이름은 PascalCase 를 제안한다 (TS-03) |
| TC-T12 | camelCase · snake_case enum 멤버는 경고만 한다 (TS-04) |
| TC-T13 | PascalCase · UPPER_SNAKE · 따옴표 멤버 · 초기값은 경고하지 않는다 (TS-04 과잉 경고 방지) |
| TC-T14 | 소문자로 시작하는 타입 매개변수는 경고만 한다 (TS-05) |
| TC-T15 | T · TKey · PascalCase · 기본값 · 제약 · const 는 경고하지 않는다 (TS-05 과잉 경고 방지) |
| TC-T16 | snake_case class 멤버는 경고만 한다 — 필드 · readonly · 메서드 · 생성자 매개변수 프로퍼티 (TS-06) |
| TC-T17 | interface · type 프로퍼티 · 제어자 없는 멤버 · 상수 · 메서드 본문은 보지 않는다 (TS-06 과잉 경고 방지) |
| TC-T18 | 주석 · 문자열 · 여러 줄 템플릿 리터럴 안의 단어는 코드로 읽지 않는다 |
| TC-T19 | tsx 의 컴포넌트 · JSX 본문 글은 과잉 차단하지 않는다 |
| TC-T20 | 디렉터리를 주면 하위 파일을 보고 dist/ · build/ · *.d.ts 는 건너뛴다 |
| TC-T21 | *.mts · *.cts 도 본다 |
| TC-T22 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-T23 | --all 은 루트의 .claude/worktrees 를 건너뛴다 |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-T30 | Write 로 위반 파일을 새로 만들면 막는다 |
| TC-T31 | Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다 |
| TC-T32 | 레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다 |
| TC-T33 | Edit 가 새 위반을 만들면 그것만 보고한다 |
| TC-T34 | 이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교) |
| TC-T35 | Edit 로 위반을 고치면 통과한다 |
| TC-T36 | replace_all 을 적용한 결과를 본다 |
| TC-T37 | 한글이 섞인 파일도 치환 위치가 맞다 |
| TC-T38 | 경고만 있으면 additionalContext 로 알리고 통과한다 |
| TC-T39 | TS 파일이 아니거나 *.d.ts 면 보지 않는다 |
| TC-T40 | dist/ · node_modules/ · generated/ 아래는 보지 않는다 |
| TC-T41 | PostToolUse 는 보지 않는다 |
| TC-T42 | 빈 입력 · 경로 없는 입력은 통과한다 |
| TC-T43 | 프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로) |
