# Node.js 네이밍 테스트

`scripts/validate-node-naming.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/validate-node-naming.test.sh          # 전체
test/validate-node-naming.test.sh TC-N3    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다.

## 자동 TC (40건)

픽스처는 **규칙을 지키는 파일**(`order-service.js` · `package.json`)이고, TC 마다 한 곳만 깨뜨린다. 과잉 차단(막으면 안 되는 것)을 막는 TC 를 조항마다 둔다.

### A. CLI 조항 (ND-01 ~ ND-06)

| ID | 케이스 |
|---|---|
| TC-N01 | 이 저장소 전체가 통과한다 |
| TC-N02 | 규칙을 지킨 JS · package.json 은 조용히 통과한다 |
| TC-N03 | package.json name 에 대문자가 있으면 막고 소문자 이름을 제안한다 (ND-01) |
| TC-N04 | name 이 . 이나 _ 로 시작하면 막는다 (ND-01) |
| TC-N05 | name 에 URL 에 그대로 쓸 수 없는 문자가 있으면 막는다 (ND-01) |
| TC-N06 | name 이 214자를 넘으면 막는다 (ND-01) |
| TC-N07 | 스코프 이름 · 최상위가 아닌 name · 깨진 JSON 은 막지 않는다 (ND-01 과잉 차단 방지) |
| TC-N08 | scripts 키의 camelCase · 밑줄은 경고만 한다 (ND-02) |
| TC-N09 | scripts 키의 : · - 구분과 prepublishOnly 는 통과한다 (ND-02 과잉 차단 방지) |
| TC-N10 | process.env 의 camelCase 이름을 막고 UPPER_SNAKE_CASE 를 제안한다 (ND-03) |
| TC-N11 | `process.env["…"]` · `process.env['…']` 도 본다 (ND-03) |
| TC-N12 | npm_* · 프록시 변수 · 대문자 이름 · 메서드 호출은 통과한다 (ND-03 과잉 차단 방지) |
| TC-N13 | TS 파일은 환경 변수만 본다 — 식별자 · 파일 이름은 보지 않는다 (ND-03) |
| TC-N14 | snake_case · camelCase 클래스를 막고 PascalCase 를 제안한다 (ND-04) |
| TC-N15 | PascalCase · 이름 없는 클래스 · className 은 막지 않는다 (ND-04 과잉 차단 방지) |
| TC-N16 | let · const · var · function 의 snake_case 를 막고 camelCase 를 제안한다 (ND-05) |
| TC-N17 | 상수 · PascalCase · 앞 밑줄 · __dirname · 구조 분해는 막지 않는다 (ND-05 과잉 차단 방지) |
| TC-N18 | 주석 · 문자열 · 템플릿 문자열의 글자는 코드로 읽지 않고, `${…}` 안은 읽는다 |
| TC-N19 | 정규식 리터럴 안의 따옴표가 뒤 코드를 가리지 않는다 |
| TC-N20 | 밑줄이 섞인 JS 파일 이름은 경고만 한다 (ND-06) |
| TC-N21 | kebab-case · export 이름을 딴 camelCase · PascalCase · 점 접미사 · dotfile · _app · [id] 는 통과한다 (ND-06 과잉 차단 방지) |
| TC-N22 | 디렉터리를 주면 하위 파일을 보고 node_modules · dist · *.min.js 는 건너뛴다 |
| TC-N23 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-N24 | --all 은 루트의 .claude/worktrees 를 건너뛴다 |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-N30 | Write 로 name 이 틀린 package.json 을 새로 만들면 막는다 |
| TC-N31 | Write 로 camelCase 환경 변수를 쓰는 JS 를 새로 만들면 막는다 |
| TC-N32 | Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다 |
| TC-N33 | 레거시 파일의 다른 줄을 Edit 하면 기존 위반으로 막지 않는다 |
| TC-N34 | Edit 가 새 위반을 만들면 그것만 보고한다 |
| TC-N35 | 이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교) |
| TC-N36 | Edit 로 위반을 고치면 통과한다 |
| TC-N37 | replace_all 을 적용한 결과를 본다 |
| TC-N38 | 한글이 섞인 파일도 치환 위치가 맞다 |
| TC-N39 | 경고만 있으면 additionalContext 로 알리고 통과한다 |
| TC-N40 | 대상 확장자가 아니면 보지 않는다 |
| TC-N41 | node_modules · dist 아래는 보지 않는다 |
| TC-N42 | 편집 뒤 package.json 이 깨져 있으면 판정하지 않는다 |
| TC-N43 | PostToolUse 는 보지 않는다 |
| TC-N44 | 빈 입력 · 경로 없는 입력은 통과한다 |
| TC-N45 | 프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로) |
