# FastAPI 스트레스 설정 테스트

`scripts/fastapi-stress-config-validate.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/fastapi-stress-config-validate.test.sh          # 전체
test/fastapi-stress-config-validate.test.sh TC-F0    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. `jq` 가 필요하다.

## 자동 TC (33건)

픽스처는 **규칙을 지키는 FastAPI 프로젝트**(`fastapi run --workers 1` · instrumentator in-flight 켬 · `def` 엔드포인트의 `time.sleep`)이고, TC 마다 한 곳만 깨뜨린다. 조항마다 과잉 탐지를 막는 TC 를 둔다.

### A. CLI 조항 (FAS-01 ~ FAS-09)

| ID | 케이스 |
|---|---|
| TC-F01 | 규칙을 지킨 프로젝트는 조용히 통과한다 |
| TC-F02 | FastAPI 프로젝트가 아니면 보지 않는다 |
| TC-F03 | Dockerfile exec 형식의 fastapi dev 를 막는다 (FAS-01) |
| TC-F04 | uvicorn --reload · uvicorn.run(reload=True) · gunicorn --reload · 셸의 fastapi dev 를 막는다 (FAS-01) |
| TC-F05 | 주석 · reload=False · fastapi run · 문서 속 명령은 막지 않는다 (FAS-01 과잉 차단 방지) |
| TC-F06 | 워커가 여럿이고 prometheus 를 쓰는데 PROMETHEUS_MULTIPROC_DIR 가 없으면 막는다 (FAS-02) |
| TC-F07 | 멀티프로세스 디렉터리가 있거나 · 워커 1 · prometheus 없음이면 막지 않는다 (FAS-02 과잉 차단 방지) |
| TC-F08 | Gunicorn + 멀티프로세스인데 mark_process_dead 가 없으면 경고한다 (FAS-03) |
| TC-F09 | child_exit 에서 mark_process_dead 를 부르면 경고하지 않는다 (FAS-03 과잉 경고 방지) |
| TC-F10 | FastAPI(debug=True) 한 줄 · 여러 줄 · app.debug = True 를 경고한다 (FAS-04) |
| TC-F11 | debug=False · 변수 · 다른 호출의 debug=True 는 경고하지 않는다 (FAS-04 과잉 경고 방지) |
| TC-F12 | 로그 레벨 debug · trace 를 경고한다 (FAS-05) |
| TC-F13 | 로그 레벨 info · warning 과 debug 라는 단어는 경고하지 않는다 (FAS-05 과잉 경고 방지) |
| TC-F14 | uvicorn.workers.UvicornWorker 를 경고한다 (FAS-06) |
| TC-F15 | uvicorn_worker.UvicornWorker 는 경고하지 않는다 (FAS-06 과잉 경고 방지) |
| TC-F16 | async def 안의 time.sleep · requests · urlopen 을 경고한다 (FAS-07) |
| TC-F17 | def 엔드포인트 · async 안의 중첩 def · 블록 밖 · 테스트 파일 · 주석은 경고하지 않는다 (FAS-07 과잉 경고 방지) |
| TC-F18 | 계측이 없거나 instrumentator 에 in-flight 가 꺼져 있으면 경고한다 (FAS-08) |
| TC-F19 | prometheus_client · OpenTelemetry 를 직접 쓰면 계측 없음으로 보지 않는다 (FAS-08 과잉 경고 방지) |
| TC-F20 | 지연을 Summary 로 재면 경고한다 (FAS-09) |
| TC-F21 | Histogram · 크기를 재는 Summary 는 경고하지 않는다 (FAS-09 과잉 경고 방지) |
| TC-F22 | .venv · node_modules · site-packages · build 아래는 보지 않는다 |
| TC-F23 | 루트가 .claude/worktrees 안이어도 검사한다 (제외는 루트 기준) |
| TC-F24 | 없는 디렉터리는 오류 1 |
| TC-F25 | 이 저장소 전체가 통과한다 |

### B. 훅

| ID | 케이스 |
|---|---|
| TC-F30 | 부하 명령이면 위반을 additionalContext 로 알리고 막지 않는다 |
| TC-F31 | 부하 도구를 모두 알아본다 (docker grafana/k6 · 경로 · 환경 변수 · 파이프 뒤 포함) |
| TC-F32 | 부하 도구가 아닌 명령은 조용히 통과한다 |
| TC-F33 | 규칙을 지킨 프로젝트에서는 부하 명령도 조용히 통과한다 |
| TC-F34 | FastAPI 프로젝트가 아니면 부하 명령도 조용히 통과한다 |
| TC-F35 | Bash 가 아닌 도구 · PostToolUse 는 보지 않는다 |
| TC-F36 | 빈 입력 · 명령 없는 입력은 통과한다 |
| TC-F37 | CLAUDE_PROJECT_DIR 가 없으면 입력의 cwd 를 검사한다 |
