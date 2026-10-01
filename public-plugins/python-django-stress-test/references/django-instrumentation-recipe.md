# Django 서버 측 계측 레시피

규칙: [`django-stress-rules.md`](django-stress-rules.md) `DJ-06` ~ `DJ-10`. 아래 코드는 Django 6.0 · gunicorn 26.2 · django-prometheus 2.5 · prometheus_client 0.26 에서 실제로 돌렸다.

## 1. 무엇을 내는가

| 신호 | 지표 | 출처 |
|---|---|---|
| 지연 (RED Duration) | `django_http_requests_latency_seconds_by_view_method` (Histogram, `view` · `method`) | django-prometheus |
| 미들웨어 포함 지연 | `django_http_requests_latency_including_middlewares_seconds` (Histogram) | django-prometheus |
| 요청 수 · 에러 (RED Rate · Errors) | `django_http_responses_total_by_status_view_method_total` (Counter) · `django_http_exceptions_total_by_type_total` | django-prometheus |
| in-flight (Little 의 L) | 직접 만든 `django_http_requests_in_flight` (Gauge, `livesum`) | 2절 |
| DB 지연 · 연결 수 | `django_db_query_duration_seconds` (Histogram) · `django_db_new_connections_total` | django-prometheus DB 백엔드 (`ENGINE` 을 `django_prometheus.db.backends.postgresql` 등으로) |
| 자원 (USE) | 노드 · 컨테이너 수준 CPU · 메모리 · 소켓 백로그 | node_exporter · cAdvisor — 멀티프로세스 모드에서는 프로세스 콜렉터가 꺼진다 |

- Counter 이름 끝의 `_total` 은 prometheus_client 가 붙인다. 이름에 `total` 이 이미 있어도 붙어 `…_total_by_method_total` 처럼 나온다 (실측)
- 분위수는 서버에서 계산하지 않는다. 버킷을 합친 뒤 `histogram_quantile` 을 한 번만 쓴다 (`ST-31`)

## 2. 설정

```python
# settings.py (측정 대상)
DEBUG = False
INSTALLED_APPS = [..., "django_prometheus"]
MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",   # DJ-09 처음
    "myproject.inflight.InFlightMiddleware",
    # ... 나머지
    "django_prometheus.middleware.PrometheusAfterMiddleware",    # DJ-09 마지막
]
# DJ-10 — SLO 근처를 촘촘히. 기본은 0.01 부터라 10 ms 아래가 한 칸이다
PROMETHEUS_LATENCY_BUCKETS = (0.005, 0.01, 0.02, 0.03, 0.05, 0.075, 0.1, 0.2, 0.3, 0.5, 1.0, 2.5, 5.0, 10.0, float("inf"))
```

```python
# urls.py
urlpatterns = [..., path("", include("django_prometheus.urls"))]   # /metrics
```

```python
# myproject/inflight.py — django-prometheus 에는 in-flight 게이지가 없다 (DJ-08)
from prometheus_client import Gauge

IN_FLIGHT = Gauge("django_http_requests_in_flight", "In-flight requests", multiprocess_mode="livesum")


class InFlightMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # 스크레이프 자신을 세면 L 이 1 부풀려진다
        if request.path == "/metrics":
            return self.get_response(request)
        with IN_FLIGHT.track_inprogress():
            return self.get_response(request)
```

ASGI 로 띄우면 미들웨어도 `async_capable` 로 만든다 — 동기 전용 미들웨어는 Django 가 요청을 변환해 맞추고 성능 비용이 든다 (Django 문서 Middleware "Asynchronous support").

## 3. 멀티 워커 — prometheus_client 멀티프로세스 모드 (DJ-06 · DJ-07)

워커마다 레지스트리가 따로라 환경 변수가 없으면 스크레이프한 워커 하나의 값만 나온다.

```python
# gunicorn.conf.py
from prometheus_client import multiprocess

workers = 4
threads = 4

def child_exit(server, worker):
    multiprocess.mark_process_dead(worker.pid)
```

```sh
# 시작 스크립트 — 디렉터리는 실행마다 비운다 (client_python 문서)
export PROMETHEUS_MULTIPROC_DIR=/tmp/prom
rm -rf "$PROMETHEUS_MULTIPROC_DIR" && mkdir -p "$PROMETHEUS_MULTIPROC_DIR"
exec gunicorn -c gunicorn.conf.py myproject.wsgi:application
```

- django-prometheus 의 `/metrics` 뷰는 이 환경 변수가 있으면 `MultiProcessCollector` 로 모은다 (소스 `exports.py`)
- 게이지는 `multiprocess_mode` 를 정한다 — `all`(기본, 프로세스별) · `min` · `max` · `sum` · `mostrecent` 와 `live*`. in-flight 는 `livesum`
- 멀티프로세스 모드에서 안 되는 것: 커스텀 콜렉터(프로세스 CPU · 메모리) · `Info` · `Enum` · `Gauge.set_function` · pushgateway · exemplar
- 대안: `PROMETHEUS_METRICS_EXPORT_PORT_RANGE = range(8001, 8050)` — 워커마다 포트 하나. Gunicorn `preload_app = False` 가 필요하고 스크레이프 대상이 워커 수만큼 늘어난다 (django-prometheus 문서 exports)

### 스크레이프를 워커 밖에서

포화되면 `/metrics` 요청도 워커 큐에서 기다려 게이지 표본이 빠지거나 늦는다 (실측: 포화 단계에서 스크레이프 2 초 타임아웃). 같은 디렉터리를 읽는 별도 프로세스로 내보낸다.

```python
# metrics_sidecar.py — 같은 PROMETHEUS_MULTIPROC_DIR 로 띄운다
import time
from prometheus_client import CollectorRegistry, start_http_server, multiprocess

registry = CollectorRegistry()
multiprocess.MultiProcessCollector(registry)
start_http_server(9100, registry=registry)
while True:
    time.sleep(3600)
```

## 4. in-flight 게이지의 경계 — Little 검증에서 읽는 법

게이지는 **미들웨어에 들어온 뒤부터** 센다. Gunicorn 소켓 백로그 · gthread 워커의 대기 큐에 있는 요청은 빠진다.

| 구간 | 기대 | 실측 (2 워커 × 4 스레드, 20 ms 뷰) |
|---|---|---|
| 포화 전 | in-flight ≈ X × W. 차이는 미들웨어 밖 시간 (네트워크 · 파싱) | X·W / in-flight = 1.04 ~ 1.10 |
| 포화 근처 | 큐가 미들웨어 밖에 생기기 시작 | 300 rps 에서 1.6 |
| 포화 뒤 | in-flight 가 `워커 × 스레드` 에서 멈춘다 | in-flight 7.4 ~ 7.8 (상한 8), X·W 280 ~ 830 |

- 포화 뒤 L < λW 는 측정 오류가 아니라 경계 차이다. 결과에는 "in-flight 가 동시성 상한(N)에 닿았다" 로 적는다
- runserver 는 요청마다 스레드를 만들어 in-flight 가 1,100 까지 올라갔다 — 상한이 없어 대기가 앱 안에서 일어난다 (`DJ-01`)
- k6 `http_reqs.rate` 는 graceful stop 의 대기 시간까지 분모에 넣는다. 포화 단계의 X·W 는 그만큼 부풀려진다

## 5. 확인 명령

```bash
curl -s localhost:8000/metrics | grep -E '^django_http_requests_in_flight |by_view_method_bucket' | head
```

`django_http_requests_in_flight 0.0` 과 `…_bucket{le="…",method="GET",view="…"}` 가 나오면 된다.
