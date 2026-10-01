# python-django-stress-test 테스트

`scripts/django-stress-config-validate.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/django-stress-config-validate.test.sh          # 전체
test/django-stress-config-validate.test.sh TC-D3    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. `jq` 가 필요하다.

## 자동 TC (33건)

픽스처는 **규칙을 모두 지킨 Django 프로젝트**(`mkproj` — Gunicorn conf · 멀티프로세스 모드 · django-prometheus · in-flight 게이지)이고, TC 마다 한 곳만 깨뜨린다. 조항마다 과잉 탐지를 막는 TC 를 둔다.

### A. CLI 조항 (DJ-01 ~ DJ-12)

| ID | 케이스 |
|---|---|
| TC-D01 | 규칙을 지킨 프로젝트는 조용히 통과한다 |
| TC-D02 | Django 프로젝트가 아니면 보지 않는다 |
| TC-D03 | Dockerfile · compose · 스크립트의 runserver 를 막는다 (DJ-01) |
| TC-D04 | dev 파일 · Makefile · 주석의 runserver 는 보지 않는다 (DJ-01 과잉 차단 방지) |
| TC-D05 | 운영 설정의 DEBUG = True 를 막는다 (DJ-02) |
| TC-D06 | dev 설정 · 환경 변수 · 주석 · 다른 이름의 DEBUG 는 보지 않는다 (DJ-02 과잉 차단 방지) |
| TC-D07 | Gunicorn · Uvicorn 자동 리로드를 막는다 (DJ-03) |
| TC-D08 | reload = False · --reload-extra-file · dev 파일의 --reload 는 보지 않는다 (DJ-03 과잉 차단 방지) |
| TC-D09 | 운영 설정의 debug_toolbar 를 경고한다 (DJ-04) |
| TC-D10 | local 설정의 debug_toolbar · 다른 이름은 경고하지 않는다 (DJ-04 과잉 경고 방지) |
| TC-D11 | 로그 레벨 DEBUG 를 경고한다 (DJ-05) |
| TC-D12 | INFO 레벨 · DEBUG 키 · dev 파일은 경고하지 않는다 (DJ-05 과잉 경고 방지) |
| TC-D13 | 멀티 워커 + prometheus 인데 멀티프로세스 모드가 없으면 막는다 (DJ-06) |
| TC-D14 | 포트 범위 방식 · 워커 1개는 막지 않는다 (DJ-06 과잉 차단 방지) |
| TC-D15 | 멀티프로세스 모드인데 mark_process_dead 가 없으면 경고한다 (DJ-07) |
| TC-D16 | 서버 측 계측이 없으면 경고한다 (DJ-08) |
| TC-D17 | django-prometheus 만 있고 in-flight 게이지가 없으면 경고한다 (DJ-08) |
| TC-D18 | Before 가 처음이 아니거나 After 가 마지막이 아니면 경고한다 (DJ-09) |
| TC-D19 | 한 줄 목록 · 튜플 · 주석 처리한 항목에서 순서가 맞으면 경고하지 않는다 (DJ-09 과잉 경고 방지) |
| TC-D20 | Gunicorn 워커 수를 정하지 않으면 경고한다 (DJ-11) |
| TC-D21 | WEB_CONCURRENCY · conf 의 workers · 설치 명령만 있으면 경고하지 않는다 (DJ-11 과잉 경고 방지) |
| TC-D22 | ASGI 인데 CONN_MAX_AGE 가 0 이 아니면 경고한다 (DJ-12) |
| TC-D23 | WSGI 의 CONN_MAX_AGE · ASGI 의 CONN_MAX_AGE 0 은 경고하지 않는다 (DJ-12 과잉 경고 방지) |
| TC-D24 | .venv · site-packages · tests · 테스트 파일은 보지 않는다 |
| TC-D25 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-D26 | 디렉터리가 아니면 오류 1 |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-D30 | k6 run 이면 additionalContext 로 알리고 막지 않는다 |
| TC-D31 | docker run … grafana/k6 · 환경 변수 접두 · 경로 · 다른 부하 도구도 알린다 |
| TC-D32 | 부하 도구가 아닌 명령은 조용히 통과한다 |
| TC-D33 | 규칙을 지킨 프로젝트면 부하 명령이어도 조용하다 |
| TC-D34 | 빈 입력은 통과한다 |
| TC-D35 | PostToolUse · Bash 가 아닌 도구는 보지 않는다 |
| TC-D36 | CLAUDE_PROJECT_DIR 가 없으면 입력의 cwd 를 본다 |
