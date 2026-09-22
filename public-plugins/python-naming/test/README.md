# Python 네이밍 테스트

`scripts/validate-python-naming.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/validate-python-naming.test.sh          # 전체
test/validate-python-naming.test.sh TC-P3    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다.

## 자동 TC (36건)

픽스처는 **규칙을 지키는 파일**(`order_service.py`)이고, TC 마다 한 곳만 깨뜨린다. 과잉 차단(막으면 안 되는 것)을 막는 TC 를 조항마다 둔다.

### A. CLI 조항 (PY-01 ~ PY-06)

| ID | 케이스 |
|---|---|
| TC-P01 | 이 저장소 전체가 통과한다 |
| TC-P02 | 규칙을 지킨 파일은 조용히 통과한다 |
| TC-P03 | 하이픈이 있는 모듈 파일 이름을 막고 snake_case 를 제안한다 (PY-01) |
| TC-P04 | 대문자가 있는 모듈 파일 이름을 막는다 (PY-01) |
| TC-P05 | `__init__.py` · `__main__.py` · 앞 밑줄 모듈은 통과한다 (PY-01 과잉 차단 방지) |
| TC-P06 | snake_case 클래스를 막고 CapWords 를 제안한다 (PY-02) |
| TC-P07 | 앞 밑줄 · 약어 대문자 클래스는 통과한다 (PY-02 과잉 차단 방지) |
| TC-P08 | CapWords · mixedCase 함수를 막고 snake_case 를 제안한다 (PY-03) |
| TC-P09 | 앞 밑줄 · dunder 함수는 통과한다 (PY-03 과잉 차단 방지) |
| TC-P10 | unittest · NodeVisitor · http.server 의 정해진 이름은 통과한다 (PY-03 과잉 차단 방지) |
| TC-P11 | @override 가 붙은 메서드는 부모의 이름을 따르므로 통과한다 (PY-03 과잉 차단 방지) |
| TC-P12 | mixedCase 매개변수는 경고한다 — 여러 줄 시그니처도 본다 (PY-04) |
| TC-P13 | self · cls · 대문자만 · 기본값 · 타입 안의 쉼표는 경고하지 않는다 (PY-04 과잉 차단 방지) |
| TC-P14 | mixedCase 대입 대상은 경고한다 (PY-05) |
| TC-P15 | 상수 · CapWords 별칭 · 호출 인자 · 다른 객체 속성은 경고하지 않는다 (PY-05 과잉 차단 방지) |
| TC-P16 | Error 로 끝나지 않는 예외 클래스는 경고한다 (PY-06) |
| TC-P17 | Error 로 끝나는 예외 · 예외가 아닌 클래스는 경고하지 않는다 (PY-06 과잉 차단 방지) |
| TC-P18 | 주석 · 문자열 · docstring 안의 단어는 코드로 읽지 않는다 |
| TC-P19 | `# noqa` · `# noqa: N8xx` 는 그 줄을 건너뛰고, N8 코드가 없는 noqa 는 건너뛰지 않는다 |
| TC-P20 | 디렉터리를 주면 하위 `*.py` 를 보고 venv · migrations · alembic/versions 는 건너뛴다 |
| TC-P21 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-P22 | `--all` 은 루트의 .claude/worktrees 를 건너뛴다 |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-P30 | Write 로 위반 파일을 새로 만들면 막는다 — 모듈 파일 이름 · 클래스 · 함수 |
| TC-P31 | Write 로 규칙을 지킨 파일을 만들면 조용히 통과한다 |
| TC-P32 | 레거시 파일의 다른 줄을 Edit 하면 기존 위반(파일 이름 포함)으로 막지 않는다 |
| TC-P33 | Edit 가 새 위반을 만들면 그것만 보고한다 |
| TC-P34 | 이미 있는 것과 같은 위반을 하나 더 만들어도 막는다 (개수로 비교) |
| TC-P35 | Edit 로 위반을 고치면 통과한다 |
| TC-P36 | replace_all 을 적용한 결과를 본다 |
| TC-P37 | 한글이 섞인 파일도 치환 위치가 맞다 |
| TC-P38 | 경고만 있으면 additionalContext 로 알리고 통과한다 |
| TC-P39 | `*.py` 가 아니면 보지 않는다 |
| TC-P40 | 가상환경 · 마이그레이션 아래 파일은 보지 않는다 |
| TC-P41 | PostToolUse 는 보지 않는다 |
| TC-P42 | 빈 입력 · 경로 없는 입력은 통과한다 |
| TC-P43 | 프로젝트가 build/ 폴더 아래 있어도 훅이 검사한다 (제외는 프로젝트 기준 상대 경로) |
