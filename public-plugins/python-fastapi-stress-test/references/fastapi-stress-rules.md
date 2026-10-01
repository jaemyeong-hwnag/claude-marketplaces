# FastAPI 스트레스 테스트 규칙 (단일 원본)

FastAPI 서버를 부하 측정할 때 **측정을 무효로 만드는 설정**과 **포화점을 정하는 손잡이**를 정한다.
기계 검증은 [`scripts/fastapi-stress-config-validate.sh`](../scripts/fastapi-stress-config-validate.sh).

부하 모델 · 지표 · 통계 판정 · 대상 호스트 안전은 `common-stress-test` 의 `stress-test-rules.md` (`ST-*`) 가 맡는다. 여기는 FastAPI · Uvicorn · Gunicorn · prometheus_client 에만 해당하는 것을 둔다.

확인한 버전: Python 3.13 · fastapi 0.142 · fastapi-cli 0.0.32 · starlette 1.7 · anyio 4.15 · uvicorn 0.54 · uvicorn-worker 0.4 · gunicorn 26.2 · prometheus_client 0.26 · prometheus-fastapi-instrumentator 8.1 · pyperf 2.10 · pytest-benchmark 5.3.

## 1. 조항

판정 — **차단**: CLI 종료 코드 `2`. 훅은 부하 명령을 막지 않고 `additionalContext` 로 알린다. **경고**: CLI `0` + 알림. **AI 판단**: 스크립트가 보지 않고 `fastapi-stress-test-apply` 스킬이 본다.

| 조항 | 내용 | 판정 | 근거 |
|---|---|---|---|
| `FAS-01` | 측정 대상을 `fastapi dev` · `uvicorn --reload` · `uvicorn.run(reload=True)` · `gunicorn --reload` 로 띄우지 않는다 | 차단 | FastAPI 문서 "FastAPI CLI" — `fastapi dev` 는 개발 전용, 자동 리로드는 자원을 많이 쓴다. Uvicorn 문서 Settings · Deployment — `--reload` 와 `--workers` 는 함께 쓸 수 없다 (소스: reload 면 workers 무시). Gunicorn 설정 `reload` — 개발용 |
| `FAS-02` | 워커가 둘 이상이고 prometheus_client 로 계측하면 `PROMETHEUS_MULTIPROC_DIR` 를 둔다 | 차단 | prometheus client_python 문서 "Multiprocess Mode". 없으면 스크레이프마다 다른 워커의 값이 나온다 (실측: 100건 요청 → 70 · 30 번갈아) |
| `FAS-03` | Gunicorn + 멀티프로세스 모드면 설정 파일의 `child_exit` 에서 `mark_process_dead(worker.pid)` 를 부른다 | 경고 | client_python 문서 "Multiprocess Mode" — Gunicorn 설정 절 |
| `FAS-04` | `FastAPI(debug=True)` · `app.debug = True` 로 측정하지 않는다 | 경고 | Starlette 문서 Applications — `debug` 는 에러에 트레이스백을 돌려준다. 에러 경로의 비용과 응답이 운영과 달라진다 |
| `FAS-05` | 로그 레벨을 `debug` · `trace` 로 두고 측정하지 않는다 (`--log-level` · `log_level=` · `UVICORN_LOG_LEVEL`) | 경고 | Uvicorn 문서 Settings — `--log-level` 기본 `info`, 선택지 `trace` 까지 |
| `FAS-06` | Gunicorn 워커 클래스로 `uvicorn.workers.UvicornWorker` 대신 `uvicorn_worker.UvicornWorker` 를 쓴다 | 경고 | Uvicorn 문서 Deployment — `uvicorn.workers` 는 deprecated, `uvicorn-worker` 패키지로 옮겨졌다. 경고는 `DeprecationWarning` 이라 기본 설정에선 보이지 않는다 |
| `FAS-07` | `async def` 안에서 블로킹 호출(`time.sleep` · `requests.*` · `urllib.request.urlopen`)을 하지 않는다 | 경고 | FastAPI 문서 "Concurrency and async / await" — 블로킹 I/O 가 있으면 `def` 로 둔다. 실측: 20 ms 블로킹이면 워커당 처리량 상한 ≈ 50 rps |
| `FAS-08` | 서버 측 계측이 있고 in-flight 게이지가 나온다 (instrumentator 면 `should_instrument_requests_inprogress=True`) | 경고 | prometheus-fastapi-instrumentator README · 소스 — 기본값 `False`, 게이지 이름 `http_requests_inprogress`. `ST-13` (Little) 검증에 필요 |
| `FAS-09` | 지연은 `Histogram` 으로 잰다. `Summary` 로 지연을 재지 않는다 | 경고 | client_python 소스 — Python `Summary` 는 `_count` · `_sum` 만 내고 분위수를 내지 않는다. Prometheus 문서 "Histograms and summaries" — 인스턴스 합산은 히스토그램만 된다 |
| `FAS-10` | 지연 히스토그램의 버킷이 SLO 근처를 촘촘히 덮는다 | AI 판단 | instrumentator 소스 — 핸들러별 `http_request_duration_seconds` 기본 버킷은 `0.1, 0.5, 1` 뿐이다. 핸들러 라벨이 없는 `_highr_` 는 `0.01 … 60` 21개 |
| `FAS-11` | `def` 엔드포인트의 동시 실행 상한은 스레드 토큰 수(기본 40)다. 포화점을 `40 ÷ 평균 처리 시간` 으로 예측해 본다 | AI 판단 | FastAPI 문서 "Concurrency" — `def` 는 외부 스레드풀에서 돈다. Starlette 문서 Thread Pool · AnyIO 문서 Threads — 기본 리미터 40 |
| `FAS-12` | DB 커넥션 풀 크기가 워커당 동시 요청 상한이 될 수 있다. 풀 대기 시간을 계측한다 | AI 판단 | SQLAlchemy 2.0 문서 Connection Pooling — `QueuePool` 기본 `pool_size=5` · `max_overflow=10` · `timeout=30` (async 엔진도 같다) |
| `FAS-13` | CPU 바운드 용량은 워커 수를 정하고 잰다. 워커 1개 결과를 머신 용량으로 쓰지 않는다 | AI 판단 | FastAPI 문서 "Server Workers" — 여러 코어를 쓰려면 `--workers`. Kubernetes 에선 컨테이너당 프로세스 하나를 권한다 → 그때는 레플리카 수가 같은 손잡이다 |
| `FAS-20` | 코드 수준 비교는 pyperf(`compare_to`) 나 pytest-benchmark 를 쓰고, 판정은 반복 분포로 한다 | AI 판단 | pyperf 문서 Runner · Commands. pytest-benchmark 문서 Usage. `ST-20` |

### 예외 — 보지 않는 것

| 경우 | 이유 |
|---|---|
| `#` 주석 줄 | 실행되지 않는다 |
| `*.md` 등 문서 | 실행 구성이 아니다 |
| `reload=False` · `debug=False` · `debug=settings.debug` | 리터럴 `True` 만 본다. 변수는 AI 가 값의 출처를 본다 |
| `--workers 1` · 워커 지정 없음 (`FAS-02`) | 프로세스가 하나면 레지스트리가 하나다 |
| `.venv/` · `venv/` · `site-packages/` · `node_modules/` · `.git/` · `.tox/` · `build/` · `dist/` · 루트의 `.claude/` | 의존성 · 산출물이다 |
| FastAPI 를 쓰지 않는 프로젝트 (`fastapi` 가 `requirements*.txt` · `pyproject.toml` · `*.py` 어디에도 없다) | 대상이 아니다 |

## 2. 계측 레시피

### prometheus-fastapi-instrumentator

```python
from prometheus_fastapi_instrumentator import Instrumentator

Instrumentator(
    should_instrument_requests_inprogress=True,        # FAS-08 — http_requests_inprogress
    excluded_handlers=["/metrics"],                    # 스크레이프가 in-flight 를 1 올리지 않게
    latency_lowr_buckets=(0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 0.75, 1, 2.5),  # FAS-10 — SLO 근처를 촘촘히
).instrument(app).expose(app)
```

| 지표 | 타입 | 라벨 | 쓰임 |
|---|---|---|---|
| `http_request_duration_highr_seconds` | Histogram, 버킷 21개 (10 ms ~ 60 s) | 없음 | 서비스 전체 p95 · p99 |
| `http_request_duration_seconds` | Histogram, 기본 버킷 `0.1 · 0.5 · 1` | `handler` · `method` | 핸들러별 지연 — 버킷을 바꾼다 |
| `http_requests_total` | Counter | `handler` · `status`(2xx 묶음) · `method` | RED 의 Rate · Errors |
| `http_requests_inprogress` | Gauge, `multiprocess_mode="livesum"` | 기본 없음 (`inprogress_labels=True` 면 handler · method) | Little 의 L |
| `http_request_size_bytes` · `http_response_size_bytes` | Summary | `handler` | 크기 (지연 아님) |

- 멀티프로세스: `PROMETHEUS_MULTIPROC_DIR` 가 있으면 `expose()` 가 `MultiProcessCollector` 로 모은다 (소스 확인). 디렉터리가 없으면 시작할 때 `ValueError`
- in-flight 게이지는 **미들웨어에 들어온 뒤부터** 센다. 소켓 백로그 · 이벤트 루프 대기는 빠진다 → 포화 뒤에는 L < λW 로 나온다 (실측 4절)

### prometheus_client 직접

```python
from prometheus_client import Gauge, Histogram

LATENCY = Histogram("http_server_duration_seconds", "요청 지연", ["route"],
                    buckets=(0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2.5, 5))
INFLIGHT = Gauge("http_server_inflight", "처리 중 요청", multiprocess_mode="livesum")
```

- 기본 버킷은 `.005 … 10` 14개다 (`Histogram.DEFAULT_BUCKETS`)
- 게이지는 멀티프로세스 모드에서 `multiprocess_mode` 를 정해야 합산된다 — `all` · `min` · `max` · `sum` · `mostrecent` 와 `live*` 변형. in-flight 는 `livesum`
- 멀티프로세스에서 안 되는 것: 커스텀 콜렉터 · `Info` · `Enum` · `Gauge.set_function` · pushgateway · exemplar

### 멀티프로세스 (FAS-02 · FAS-03)

```bash
export PROMETHEUS_MULTIPROC_DIR=/tmp/prom-mp
rm -rf "$PROMETHEUS_MULTIPROC_DIR" && mkdir -p "$PROMETHEUS_MULTIPROC_DIR"   # 실행마다 비운다 — 이전 pid 파일이 합산된다
fastapi run app/main.py --workers 4
```

```python
# gunicorn.conf.py — Gunicorn 일 때만
from prometheus_client import multiprocess

def child_exit(server, worker):
    multiprocess.mark_process_dead(worker.pid)
```

- 환경 변수는 파이썬 코드가 아니라 **시작 스크립트**에서 둔다 — 자식 프로세스에 전해져야 한다 (client_python 문서)
- 직접 계측이면 `/metrics` 핸들러에서 요청마다 새 `CollectorRegistry` 에 `MultiProcessCollector(registry)` 를 붙인다

### 자원 (USE)

| 자원 | Utilization | Saturation | 어디서 |
|---|---|---|---|
| CPU | 프로세스 CPU (`process_cpu_seconds_total` — 단일 프로세스 모드만) · cgroup `cpu.stat` | cgroup `nr_throttled` · 런큐 | 멀티프로세스 모드에서는 `process_*` 가 나오지 않는다 → node/cAdvisor 로 본다 |
| 스레드풀 | 실행 중 토큰 `limiter.borrowed_tokens` | 대기 `limiter.statistics().tasks_waiting` | AnyIO `CapacityLimiter` — 게이지로 내보낸다 |
| DB 풀 | `engine.pool.checkedout()` | 풀 대기 시간 · `TimeoutError` | SQLAlchemy |
| 이벤트 루프 | — | 루프 지연 (주기 태스크의 예정 대비 지연) | 직접 잰다 |

## 3. 손잡이

| 손잡이 | 기본값 | 포화점에 미치는 영향 | 근거 |
|---|---|---|---|
| 프로세스 수 `--workers` | `$WEB_CONCURRENCY` 또는 1 (uvicorn · fastapi run · gunicorn 모두) | CPU 바운드 처리량 상한 ≈ 워커 수 × 코어 처리량. `--reload` 면 무시된다 | Uvicorn Settings · Gunicorn `workers` |
| 스레드 토큰 (`def` 엔드포인트 · 동기 의존성) | 40 / 프로세스 | 워커당 상한 ≈ 40 ÷ 처리 시간. 100 ms 면 400 rps (실측 390) | AnyIO `current_default_thread_limiter()` |
| 이벤트 루프 | 프로세스당 1 | `async def` 안 블로킹 T 초면 상한 ≈ 1 ÷ T (20 ms → 50, 실측 47) | FastAPI Concurrency |
| DB 풀 | `pool_size=5` + `max_overflow=10`, 대기 30 s | 워커당 DB 동시 사용 ≤ 15. Little 의 L 상한 | SQLAlchemy Pooling |
| `--limit-concurrency` | 없음 | 넘으면 503 — 에러율로 나온다 | Uvicorn Settings |
| `--backlog` | 2048 | 포화 뒤 대기열. 이 안의 요청은 in-flight 게이지에 안 잡힌다 | Uvicorn Settings |
| `--timeout-keep-alive` | 5 s | 부하기 커넥션 재사용 | Uvicorn Settings |
| `--loop` · `--http` | `auto` (uvloop · httptools 가 있으면 쓴다 — `uvicorn[standard]`) | 프로토콜 처리 비용 | Uvicorn Settings |

스레드 토큰을 바꾸려면 이벤트 루프 안(lifespan)에서 한다.

```python
from contextlib import asynccontextmanager
import anyio.to_thread

@asynccontextmanager
async def lifespan(app):
    anyio.to_thread.current_default_thread_limiter().total_tokens = 100
    yield
```

## 4. 실측 요약 (Docker, 2 vCPU 제한, 호스트 공유)

대상: `def` 엔드포인트 `time.sleep(0.1)`, `fastapi run --workers 2`, instrumentator + `PROMETHEUS_MULTIPROC_DIR`. k6 `constant-arrival-rate` 15 s 단계.

| load | 처리량 | p50 | p99 | in-flight | λW | 비고 |
|---|---|---|---|---|---|---|
| 100 | 99 | 104 | 157 | 10.7 | 10.7 | |
| 400 | 397 | 107 | 384 | 45.9 | 51.7 | |
| 800 | 697 | 568 | 983 | 394 | 403 | 이론 상한 2 × 40 ÷ 0.1 = 800 |
| 1200 | 523 | 1839 | 8552 | 939 | 1328 | 포화 — 백로그 대기가 게이지 밖 |

- `fastapi dev` (리로드, 워커 1) 로 같은 단계: 처리량 상한 ≈ 350 rps. `fastapi run --workers 1` 도 ≈ 390 → **차이의 대부분은 워커 수**다. 리로드 감시 자체의 처리량 영향은 이 실험에서 구분되지 않았다
- `async def` + `time.sleep(0.02)`: 60 rps 목표에 처리량 45, p99 16 s. in-flight 게이지는 1 로 읽혀 Little 이 100배 어긋난다 — 루프가 막히면 미들웨어도 스크레이프도 멈춘다
- 워커 2 + 멀티프로세스 모드 없음: `http_requests_total` 이 스크레이프마다 70 · 30 으로 번갈아 나왔다 (실제 100)

## 5. 마이크로벤치마크

| | pyperf | pytest-benchmark |
|---|---|---|
| 반복 구조 | 프로세스 20개 × 값 3개 + 워밍업 1 (CPython 기본). 값 하나 ≥ 100 ms 가 되도록 루프 수 보정 | 라운드 최소 5, 테스트당 최대 1 s. 워밍업 기본 `auto` (PyPy 에서만 켬) |
| 프로세스 분리 | 있다 (워커 프로세스를 띄운다) | 없다 (pytest 프로세스 하나) |
| 비교 | `pyperf compare_to a.json b.json` — 2표본 t 검정, 유의하지 않으면 "Not significant" | `--benchmark-compare` — 표만. `--benchmark-compare-fail=median:10%` 는 고정 임계 |
| 엄격 모드 | `--rigorous` (프로세스 40) · `--fast` (10 × 2) | `--benchmark-warmup=on` · `--benchmark-disable-gc` |
| 잡음 | `pyperf system tune` · `--affinity` | — |

```bash
python bench.py -o base.json          # 변경 전
python bench.py -o new.json           # 변경 뒤 (같은 머신 · 연이어)
python -m pyperf compare_to base.json new.json --table
python -m pyperf stats new.json       # 분위수 · 이상치 · MAD
```

- pyperf 스크립트는 `Runner` 를 `if __name__ == "__main__":` 안에 둔다. 모듈 수준에 두면 pytest 등이 import 할 때 인자 파싱으로 죽는다 (실측)
- `bench_func` 에 넘길 함수에 인자를 다르게 주려면 `Runner(add_cmdline_args=…)` 로 워커 프로세스에 인자를 전한다
- pytest-benchmark 의 `compare-fail` 은 통계 검정이 아니다. 실측에서 같은 코드의 median 이 실행 사이 189 → 119 µs 로 바뀌었다 (공유 호스트). 회귀 판정은 pyperf `compare_to` 나 반복 분포 비교(`ST-20`)로 한다
- async 코드는 `asyncio.run` 을 벤치마크 함수 안에서 부르면 루프 생성 비용이 섞인다 — pyperf `bench_async_func` 를 쓴다

## 6. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `fastapi-stress-config-validate.sh` | `FAS-01` ~ `FAS-09` — 실행 구성 · 코드의 리터럴 패턴 |
| 판단 | AI (`fastapi-stress-test-apply`) | `FAS-10` ~ `FAS-20`, 변수로 정한 설정의 실제 값, 여러 줄에 걸친 호출, 어느 구성이 측정용인지 |
