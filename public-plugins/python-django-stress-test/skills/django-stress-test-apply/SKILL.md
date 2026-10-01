---
name: django-stress-test-apply
description: Django 서버에 부하·스트레스 테스트를 걸기 전에 서버 쪽에서 설정·확인할 것을 정할 때 사용한다 — runserver·DEBUG=True·자동 리로드 같은 무효 설정, django-prometheus 히스토그램·in-flight 계측, Gunicorn 워커·CONN_MAX_AGE·DB 풀, pyperf. 트리거 — "부하 테스트 준비", "Django 성능 측정", "gunicorn 워커", "django-prometheus", "pyperf".
---

# Django 스트레스 테스트 준비

규칙 원본: [`references/django-stress-rules.md`](../../references/django-stress-rules.md) (`DJ-*`)
계측: [`references/django-instrumentation-recipe.md`](../../references/django-instrumentation-recipe.md)
마이크로벤치마크: [`references/django-microbenchmark.md`](../../references/django-microbenchmark.md)
기계 검증: [`scripts/django-stress-config-validate.sh`](../../scripts/django-stress-config-validate.sh)

이 스킬은 **측정 대상(Django 서버)** 만 준비한다. 부하 스크립트 작성은 `common-stress-test` 의 `stress-test-create`, 단계 결과 판정은 `stress-result-review` 에 넘긴다.

## 1. 무효 설정부터 없앤다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/django-stress-config-validate.sh" .
```

종료 코드 2 면 측정하지 않는다. 고치는 방향:

| 조항 | 찾은 것 | 바꾸는 것 |
|---|---|---|
| `DJ-01` | `manage.py runserver` | `gunicorn myproject.wsgi:application` (ASGI 면 `-k uvicorn_worker.UvicornWorker` 와 `asgi:application`) |
| `DJ-02` | `DEBUG = True` | 운영과 같은 `False` — `ALLOWED_HOSTS` 도 같이 채운다 |
| `DJ-03` | `--reload` · `reload = True` | 뺀다 |
| `DJ-04` | `debug_toolbar` | 측정 대상 설정에서 뺀다 (dev 설정으로 옮긴다) |
| `DJ-05` | 로그 `DEBUG` | `INFO` 이상 |
| `DJ-06` · `DJ-07` | 멀티 워커인데 멀티프로세스 모드가 없다 | 레시피 3절 |
| `DJ-11` | 워커 수 미지정 | `--workers` · `--threads` 를 정한다 |
| `DJ-12` | ASGI + `CONN_MAX_AGE ≠ 0` | `0` 으로 두고 PostgreSQL 풀을 쓴다 |

스크립트가 보지 못하는 것도 확인한다.

- `DEBUG = env(...)` · `os.environ.get("DEBUG", "True")` — **기본값**이 True 면 측정 환경에서 값이 정말 주어지는지 본다
- 측정 대상이 실제로 어떤 설정 모듈로 뜨는지 (`DJANGO_SETTINGS_MODULE`). dev 설정으로 뜨면 `DJ-01` ~ `DJ-05` 를 손으로 본다
- 운영과 다른 미들웨어 · 캐시 백엔드 · 세션 저장소가 없는지

## 2. 계측을 붙인다 (`DJ-08` ~ `DJ-10`)

레시피 2 · 3절을 그대로 적용한다. 요점:

1. `django_prometheus` 를 `INSTALLED_APPS` 에, `PrometheusBeforeMiddleware` 를 **처음**, `PrometheusAfterMiddleware` 를 **마지막**에 둔다
2. in-flight 게이지 미들웨어를 Before 바로 뒤에 넣는다 — django-prometheus 에는 없다. `multiprocess_mode="livesum"`, `/metrics` 경로는 세지 않는다
3. `PROMETHEUS_LATENCY_BUCKETS` 를 SLO 근처로 촘촘히 바꾼다 — 기본은 10 ms 부터다
4. 워커가 둘 이상이면 `PROMETHEUS_MULTIPROC_DIR` 를 실행마다 비우고 `child_exit` 에서 `mark_process_dead`
5. 포화 단계까지 볼 거면 스크레이프를 별도 프로세스(사이드카)로 내보낸다 — 워커가 포화되면 `/metrics` 도 줄을 선다
6. DB 지연을 보려면 `ENGINE` 을 `django_prometheus.db.backends.<vendor>` 로 바꾼다

확인: `/metrics` 에 `django_http_requests_in_flight` 와 `django_http_requests_latency_seconds_by_view_method_bucket` 이 나와야 한다.

## 3. 손잡이로 포화점을 먼저 예측한다 (`DJ-11` ~ `DJ-15`)

부하를 걸기 전에 숫자로 적어 둔다. 결과가 예측과 크게 다르면 측정 경계부터 의심한다.

1. **동시성 상한 N** — `sync` 면 워커 수, `gthread` 면 `워커 × 스레드`, ASGI 면 이벤트 루프 + 동기 뷰의 스레드
2. **처리 시간 S** — 무부하 단계의 서버 측 평균 지연
3. **포화점 예측 ≈ N ÷ S** (Little). 예: 2 × 4 스레드, 20 ms → 400 rps. CPU 바운드면 GIL 때문에 프로세스 수 × (1 ÷ CPU 시간) 이 먼저 막는다
4. **DB 상한** — 영속 연결이면 `워커 × 스레드` 개 연결, 풀이면 프로세스마다 `max_size`. DB `max_connections` 를 넘지 않는지, 풀 `max_size` 가 N 보다 작아 L 상한이 되지 않는지
5. `CONN_MAX_AGE` · `CONN_HEALTH_CHECKS` · Gunicorn `timeout` · `max_requests` 를 **운영 값과 같게** 둔다. 0 이면 요청마다 연결 비용이 지연에 들어간다
6. 오토스케일 · 레플리카 수를 고정한다 (`ST-35`)

포화 뒤 in-flight 게이지는 N 에서 멈추고 λW 는 계속 커진다 — 대기는 소켓 백로그에 있다. `stress-result-review` 의 Little 검사(`ST-13`)가 어긋나면 이 경계 때문인지 먼저 본다 (레시피 4절).

## 4. 코드 수준 비교 (`DJ-20`)

부하 테스트로 원인 후보가 좁혀졌으면 그 함수 · 쿼리 경로만 마이크로벤치마크로 비교한다.

- 판정은 pyperf `compare_to` 로 한다. 설정을 환경 변수로 바꾸면 `--inherit-environ` 을 준다 — 워커 프로세스는 물려받지 않는다
- pytest-benchmark 는 회귀 감시용. `--benchmark-warmup=on` (CPython 기본은 꺼짐), 고정 임계 `compare-fail` 은 잡음에 걸린다
- 효과크기와 분포로 보고한다 (`ST-20`)

## 5. 보고에 남길 것

- 버전: Python · Django · Gunicorn(워커 클래스 · workers · threads) · DB 와 풀 설정 · `CONN_MAX_AGE`
- 측정 대상 설정 모듈과 `DEBUG` 값, 검증 스크립트 결과 (경고 포함)
- 예측한 포화점과 실측 포화점, in-flight 가 상한에 닿은 단계
