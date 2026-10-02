# python-fastapi-stress-test

FastAPI 서버 부하 측정을 준비한다 — 지연 히스토그램 · in-flight 게이지 계측(멀티 워커면 prometheus 멀티프로세스 모드), 개발 서버 · 리로드 · debug 같은 무효 설정 탐지, 워커 · 스레드 토큰 · DB 풀 손잡이, pyperf 마이크로벤치마크.

부하 모델 · 지표 · 통계 판정은 `common-stress-test` 가 맡고, 이 플러그인은 FastAPI · Uvicorn · Gunicorn · prometheus_client 에만 해당하는 것을 담는다. 근거는 FastAPI · Starlette · Uvicorn · AnyIO · prometheus client_python · SQLAlchemy · pyperf 공식 문서와 소스, Docker 실측이다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-fastapi-stress-test@jaemyeong-hwnag-plugins
```

## 의존성

- `common-stress-test` — 부하 스크립트 작성 · 결과 판정 · 대상 호스트 안전

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| fastapi-stress-test-apply | FastAPI 부하 테스트 · uvicorn 성능 · `/metrics` · 워커 수 · pyperf | 무효 설정 제거, 계측 적용, 손잡이로 포화점 예측, 마이크로벤치마크 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| fastapi-stress-config-validate.sh | PreToolUse (Bash) | 부하 도구(`k6 run` · `locust` · `jmeter` · `gatling` · `wrk` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon` · `docker run … grafana/k6`)를 실행할 때 프로젝트를 검사해 **알린다**. 막지 않는다 |

## 주의

- 훅은 FastAPI 프로젝트(`fastapi` 가 의존성 파일이나 `*.py` 에 있다)에서만 알린다
- 스크립트는 줄 단위 리터럴만 본다. `debug=settings.debug` · `--workers "$N"` 처럼 변수로 정한 값은 보지 않는다 — 스킬이 판단한다
- `#` 주석 줄, 테스트 파일(`test_*.py` · `*_test.py` · `conftest.py`), `.venv/` · `venv/` · `site-packages/` · `node_modules/` · `build/` · `dist/` 는 보지 않는다
- 개발용 구성(`docker-compose.override.yml` 등)도 함께 보고된다. 어느 구성으로 측정하는지는 사람이 정한다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `FAS-01` | `fastapi dev` · `--reload` 로 측정하지 않는다 | 차단 |
| `FAS-02` | 워커 ≥ 2 + prometheus 면 `PROMETHEUS_MULTIPROC_DIR` | 차단 |
| `FAS-03` | Gunicorn + 멀티프로세스면 `child_exit` 에서 `mark_process_dead` | 경고 |
| `FAS-04` | `debug=True` 로 측정하지 않는다 | 경고 |
| `FAS-05` | 로그 레벨 `debug` · `trace` 로 측정하지 않는다 | 경고 |
| `FAS-06` | `uvicorn.workers.UvicornWorker` → `uvicorn_worker.UvicornWorker` | 경고 |
| `FAS-07` | `async def` 안에서 블로킹 호출을 하지 않는다 | 경고 |
| `FAS-08` | 서버 측 계측과 in-flight 게이지가 있다 | 경고 |
| `FAS-09` | 지연은 `Histogram` 으로 잰다 (`Summary` X) | 경고 |
| `FAS-10` ~ `FAS-13` | 버킷 · 스레드 토큰 40 · DB 풀 · 워커 수 | AI 판단 |
| `FAS-20` | 마이크로벤치마크는 pyperf `compare_to` · 반복 분포로 판정 | AI 판단 |

"차단" 은 CLI 종료 코드 `2` 다. 훅은 부하 명령을 막지 않는다.

원본: [`references/fastapi-stress-rules.md`](references/fastapi-stress-rules.md)

## 사용

```bash
scripts/fastapi-stress-config-validate.sh .         # 프로젝트 검사
test/fastapi-stress-config-validate.test.sh         # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
