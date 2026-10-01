# Django 스트레스 테스트 규칙 (단일 원본)

Django 서버를 부하 측정할 때 **측정을 무효로 만드는 설정**과 **포화점을 정하는 손잡이**를 정한다.
기계 검증은 [`scripts/django-stress-config-validate.sh`](../scripts/django-stress-config-validate.sh).

부하 모델 · 지표 · 통계 판정 · 대상 호스트 안전은 `common-stress-test` 의 `stress-test-rules.md` (`ST-*`) 가 맡는다. 여기는 Django · Gunicorn · Uvicorn · django-prometheus · prometheus_client 에만 해당하는 것을 둔다.

확인한 버전: Python 3.13 · Django 6.0.8 · gunicorn 26.2 · uvicorn 0.54 · django-prometheus 2.5 · prometheus_client 0.26 · psycopg_pool 3.3 · pyperf 2.10 · pytest-benchmark 5.3 · pytest-django 4.14.

## 1. 조항

판정 — **차단**: CLI 종료 코드 `2`. 훅은 부하 명령을 막지 않고 `additionalContext` 로 알린다. **경고**: CLI `0` + 알림. **AI 판단**: 스크립트가 보지 않고 `django-stress-test-apply` 스킬이 본다.

| 조항 | 내용 | 판정 | 근거 |
|---|---|---|---|
| `DJ-01` | 측정 대상을 `manage.py runserver` · `django-admin runserver` 로 띄우지 않는다 | 차단 | Django 문서 django-admin "runserver" 경고 — "DO NOT USE THIS SERVER IN A PRODUCTION SETTING … has not gone through security audits or performance tests". 같은 문서 — 기본 멀티스레드, 자동 리로드. Django 문서 Databases "Persistent connections" — 개발 서버는 요청마다 스레드를 만든다. 실측: 같은 단계를 두 번 돌리면 p99 가 100 rps 1,767 ↔ 506 ms, 600 rps 3,360 ↔ 55 ms 로 갈렸다 |
| `DJ-02` | 측정 대상 설정에 `DEBUG = True` 를 두지 않는다 | 차단 | Django 문서 Settings `DEBUG` — "Never deploy a site into production with DEBUG turned on", DEBUG 면 실행한 SQL 을 모두 기억한다. 소스 `db/backends/base/base.py` — `queries_log` 는 `deque(maxlen=9000)` (연결당), `db/__init__.py` — `request_started` 마다 `reset_queries` |
| `DJ-03` | `gunicorn --reload` · `reload = True` · `uvicorn --reload` 로 띄우지 않는다 | 차단 | Gunicorn 설정 `reload` 설명 — "intended for development". Django 문서 "How to use Django with Uvicorn" — `--reload` 는 개발용 |
| `DJ-04` | django-debug-toolbar 를 측정 대상 설정의 `INSTALLED_APPS` · `MIDDLEWARE` 에 두지 않는다 | 경고 | django-debug-toolbar 문서 Configuration — "isn't hardened for use in production", 기본 `SHOW_TOOLBAR_CALLBACK` 은 `DEBUG` 와 `INTERNAL_IPS` 를 본다 |
| `DJ-05` | 로그 레벨을 `DEBUG` 로 두고 측정하지 않는다 (`LOGGING` 의 `"level": "DEBUG"` · `logging.DEBUG` · Gunicorn `--log-level debug` · `loglevel = "debug"`) | 경고 | Django 문서 Logging `django.db.backends` — 요청의 SQL 을 DEBUG 레벨로 남기며, DEBUG=True 일 때만 켜진다. Gunicorn 설정 `loglevel` 기본 `info` |
| `DJ-06` | 워커가 둘 이상이고 prometheus 로 계측하면 `PROMETHEUS_MULTIPROC_DIR` (또는 django-prometheus `PROMETHEUS_METRICS_EXPORT_PORT_RANGE`) 를 둔다 | 차단 | prometheus client_python 문서 "Multiprocess Mode". django-prometheus 문서 exports — 포트 범위 방식은 Gunicorn `preload_app = False` 가 필요하다. 소스 `exports.py` — 환경 변수가 있으면 `/metrics` 뷰가 `MultiProcessCollector` 로 모은다 |
| `DJ-07` | Gunicorn + 멀티프로세스 모드면 설정 파일의 `child_exit` 에서 `mark_process_dead(worker.pid)` 를 부른다 | 경고 | client_python 문서 "Multiprocess Mode" — Gunicorn 설정 절 |
| `DJ-08` | 서버 측 계측(지연 히스토그램)이 있고 in-flight 게이지가 나온다 | 경고 | django-prometheus 2.5 소스 `middleware.py` — Counter · Histogram 뿐, in-flight 게이지가 없다 → 직접 만든다 (레시피). `ST-13` (Little) 검증에 필요 |
| `DJ-09` | `PrometheusBeforeMiddleware` 가 `MIDDLEWARE` 의 처음, `PrometheusAfterMiddleware` 가 마지막이다 | 경고 | django-prometheus README — Before 는 처음, After 는 마지막 |
| `DJ-10` | 지연 히스토그램의 버킷이 SLO 근처를 촘촘히 덮는다 (`PROMETHEUS_LATENCY_BUCKETS`) | AI 판단 | django-prometheus 소스 `conf/__init__.py` — 기본 버킷 `0.01 … 75, +Inf` 17개. 10 ms 아래는 한 칸이다 |
| `DJ-11` | Gunicorn 워커 수를 정하고 잰다. 워커 1개 결과를 머신 용량으로 쓰지 않는다 | 경고 | Gunicorn 설정 `workers` — 기본 `WEB_CONCURRENCY` 또는 1, 권장 `2-4 x $(NUM_CORES)`. `threads` 기본 1, 2 이상이면 `sync` 대신 `gthread` |
| `DJ-12` | ASGI 로 띄우면 `CONN_MAX_AGE` 를 0 으로 둔다 | 경고 | Django 문서 Databases "Persistent connections" — ASGI 에서는 영속 연결을 끄고 백엔드 풀을 쓴다 |
| `DJ-13` | `CONN_MAX_AGE` 는 운영 값과 같게 잰다. 기본 0 은 요청마다 연결을 맺고 끊는다. `CONN_HEALTH_CHECKS` (기본 False) 도 같게 | AI 판단 | Django 문서 Settings `CONN_MAX_AGE` · `CONN_HEALTH_CHECKS`. 소스 `db/utils.py` — 기본 `0` · `False` |
| `DJ-14` | DB 연결 수 상한을 계산한다 — 영속 연결이면 `워커 × 스레드` ≤ DB `max_connections`. PostgreSQL 풀(`OPTIONS["pool"]`)이면 프로세스마다 풀 하나, `max_size` 가 프로세스의 DB 동시 사용 상한(Little 의 L 상한) | AI 판단 | Django 문서 Databases — 스레드마다 연결을 갖는다. 소스 `postgresql/base.py` — 풀 + `CONN_MAX_AGE ≠ 0` 이면 `ImproperlyConfigured`, `CONN_HEALTH_CHECKS` 면 풀의 `check` 를 켠다. psycopg_pool 시그니처 — `min_size=4` · `max_size=None`(= min_size) · `timeout=30` |
| `DJ-15` | 워커 모델의 동시성 상한을 먼저 계산한다 — `sync` 는 워커 수, `gthread` 는 `워커 × 스레드`. 포화점 ≈ 상한 ÷ 평균 처리 시간. 상한을 넘은 요청은 미들웨어 밖(소켓 · 워커 큐)에서 기다린다 | AI 판단 | Gunicorn 설정 `workers` · `threads` · `timeout`(기본 30 — 넘으면 워커를 죽인다). 실측: 2 × 4 스레드, 20 ms 뷰 → 이론 400 rps, 실측 지속 가능 300 rps, in-flight 게이지는 8 에서 멈췄다 |
| `DJ-20` | 코드 수준 비교는 pyperf(`compare_to`) 나 pytest-benchmark 로 하고, 판정은 반복 분포로 한다 | AI 판단 | pyperf 문서 Runner · Commands. pytest-benchmark `--help`. `ST-20`. 절차: [`django-microbenchmark.md`](django-microbenchmark.md) |

### 예외 — 보지 않는 것

| 경우 | 이유 |
|---|---|
| `#` 주석 줄 | 실행되지 않는다 |
| 파일 이름에 `dev` · `develop` · `development` · `local` · `test` · `tests` · `testing` 이 단어로 들어간 파일 (`settings/dev.py` · `local_settings.py` · `docker-compose.dev.yml` · `Dockerfile.local`) — `DJ-01` ~ `DJ-05` · `DJ-11` · `DJ-12` | 측정 대상이 아니라 개발 설정이다 |
| `test_*.py` · `*_test.py` · `conftest.py` · `tests/` | 테스트 코드다 |
| `Makefile` · `*.md` | 개발 편의 명령 · 문서다 |
| `DEBUG = env(...)` · `DEBUG = os.environ.get(...)` | 리터럴 `True` 만 본다. 기본값이 `True` 인지는 AI 가 본다 |
| `--workers 1` · 워커 지정 없음 (`DJ-06`) | 프로세스가 하나면 레지스트리가 하나다 |
| `.venv/` · `venv/` · `site-packages/` · `node_modules/` · `.git/` · `.tox/` · `build/` · `dist/` · 루트의 `.claude/` | 의존성 · 산출물이다 |
| Django 를 쓰지 않는 프로젝트 (`django` 가 `requirements*.txt` · `pyproject.toml` · `Pipfile` · `setup.cfg` · `*.py` import 어디에도 없다) | 대상이 아니다 |

## 2. 문서와 실측이 다른 곳

- **DEBUG 의 쿼리 기록은 요청 처리에서 메모리를 계속 늘리지 않는다.** 문서는 "rapidly consume memory" 라고 쓰지만 소스는 요청 시작마다 비우고(`reset_queries`) 연결당 9000건으로 자른다. 실측: DEBUG=True, 1 워커 × 4 스레드, 120 rps × 110 초 — RSS 46.2 → 47.4 MB 에서 멈췄고 DEBUG=False 와 같았다. 요청 밖(관리 명령 · 백그라운드 스레드 · 작업 큐 워커)에서는 9000건까지 쌓인다 — 500 바이트 쿼리 3만 건에 RSS 가 9000건째부터 DEBUG=False 대비 +4.7 MB 에서 멈췄다
- DEBUG=True 의 지연 차이는 이번 환경(Docker Desktop, 단계당 1회)의 반복 간 잡음보다 작아 수치로 갈라내지 못했다. 쿼리 하나 마이크로벤치마크도 pyperf `compare_to` 가 "not significant" 였다. `DJ-02` 를 차단으로 두는 근거는 성능 수치가 아니라 "운영과 다른 대상" 이다

## 3. 손잡이 요약

| 손잡이 | 기본 | 포화점에 주는 영향 |
|---|---|---|
| Gunicorn `workers` | `WEB_CONCURRENCY` 또는 1 | 프로세스 수 = CPU 병렬도. `sync` 면 그대로 동시성 상한 |
| Gunicorn `threads` | 1 (2 이상이면 `gthread`) | 프로세스당 동시 요청. GIL 때문에 I/O 대기 비율만큼만 이득 |
| Gunicorn `worker_class` | `sync` | `gthread` · `gevent` · `uvicorn_worker.UvicornWorker`(ASGI) |
| Gunicorn `timeout` | 30 초 | 포화 시 응답이 30 초를 넘으면 워커가 죽어 에러율이 튄다 |
| Gunicorn `backlog` | 2048 | 상한을 넘은 요청이 기다리는 소켓 큐 — 서버 계측에 안 잡힌다 |
| Gunicorn `max_requests` | 0 (끔) | 켜면 워커 재시작이 soak 지연에 스파이크를 만든다 |
| `CONN_MAX_AGE` | 0 | 0 이면 요청마다 연결 수립 비용이 지연에 들어간다 |
| `CONN_HEALTH_CHECKS` | False | True 면 재사용 전 확인 쿼리 비용 |
| PostgreSQL `OPTIONS["pool"]` (Django 5.1+) | 없음 | `max_size` 가 프로세스당 DB 동시성 상한, 대기는 `timeout` 30 초 |
| `PROMETHEUS_LATENCY_BUCKETS` | `0.01 … 75` 17개 | 분위수 추정 해상도 (`ST-31`) |
