# python-django-stress-test

Django 서버 부하 측정을 Django 에 맞게 준비한다 — runserver · DEBUG=True · 자동 리로드 · debug-toolbar · DEBUG 로그 같은 무효 설정 탐지, django-prometheus 지연 히스토그램과 in-flight 게이지 · 멀티프로세스 계측, Gunicorn 워커 · 스레드 · `CONN_MAX_AGE` · DB 풀 손잡이, pyperf 마이크로벤치마크.

부하 모델 · 지표 · 통계 판정 · 대상 호스트 안전은 `common-stress-test` 가 맡는다. 이 플러그인은 Django 에만 해당하는 것만 담는다. 근거는 Django 문서(django-admin runserver · Settings · Databases · Logging) · Gunicorn 설정 설명 · prometheus client_python "Multiprocess Mode" · django-prometheus 소스와 문서 · pyperf 문서이고, 각 조항을 Docker 에서 실제로 돌려 확인했다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-django-stress-test@plugin-marketplace
```

## 의존성

- `common-stress-test` — 부하 스크립트 작성 · 결과 판정 · 대상 호스트 안전

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| django-stress-test-apply | Django 부하 테스트 · gunicorn 성능 · `/metrics` · 워커 수 · `CONN_MAX_AGE` · pyperf | 무효 설정 제거, 계측 적용, 손잡이로 포화점 예측, 마이크로벤치마크 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| django-stress-config-validate.sh | PreToolUse (Bash) | 부하 도구(`k6 run` · `locust` · `jmeter` · `gatling` · `wrk` · `vegeta attack` · `hey` · `ab` · `oha` · `artillery` · `autocannon` · `docker run … grafana/k6`)를 실행할 때 프로젝트를 검사해 **알린다**. 막지 않는다 |

## 주의

- 문법 분석 없이 줄 단위로 본다. `DEBUG = env("DEBUG", default=True)` 처럼 값이 변수면 보지 않는다 — 스킬이 기본값을 본다
- 파일 이름에 `dev` · `local` · `test` 가 단어로 들어간 설정(`settings/dev.py` · `docker-compose.dev.yml`)과 `Makefile` 은 개발용으로 보고 건너뛴다. 측정 대상이 그 파일로 뜬다면 CLI 결과만으로 안심하지 않는다
- in-flight 게이지는 django-prometheus 에 없다. 레시피의 미들웨어를 직접 넣는다
- `jq` 가 필요하다 (훅 모드)

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `DJ-01` | `manage.py runserver` 로 측정하지 않는다 | 차단 |
| `DJ-02` | `DEBUG = True` 로 측정하지 않는다 | 차단 |
| `DJ-03` | Gunicorn · Uvicorn 자동 리로드로 측정하지 않는다 | 차단 |
| `DJ-04` | django-debug-toolbar 를 측정 대상 설정에 두지 않는다 | 경고 |
| `DJ-05` | 로그 레벨 DEBUG 로 측정하지 않는다 | 경고 |
| `DJ-06` | 멀티 워커 + prometheus 면 `PROMETHEUS_MULTIPROC_DIR` | 차단 |
| `DJ-07` | Gunicorn `child_exit` 에서 `mark_process_dead` | 경고 |
| `DJ-08` | 지연 히스토그램과 in-flight 게이지가 있다 | 경고 |
| `DJ-09` | django-prometheus Before 미들웨어가 처음, After 가 마지막 | 경고 |
| `DJ-10` | 히스토그램 버킷이 SLO 근처를 덮는다 | AI 판단 |
| `DJ-11` | Gunicorn 워커 수를 정하고 잰다 (기본 1) | 경고 |
| `DJ-12` | ASGI 면 `CONN_MAX_AGE = 0` | 경고 |
| `DJ-13` ~ `DJ-15` | `CONN_MAX_AGE` · DB 연결 수 · 워커 모델의 동시성 상한 | AI 판단 |
| `DJ-20` | 마이크로벤치마크는 pyperf · pytest-benchmark 반복 분포로 | AI 판단 |

원본: [`references/django-stress-rules.md`](references/django-stress-rules.md) · 계측: [`references/django-instrumentation-recipe.md`](references/django-instrumentation-recipe.md) · 마이크로벤치마크: [`references/django-microbenchmark.md`](references/django-microbenchmark.md)

## 사용

```bash
scripts/django-stress-config-validate.sh .               # 프로젝트 검사 (0 통과 · 2 위반)
test/django-stress-config-validate.test.sh               # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
