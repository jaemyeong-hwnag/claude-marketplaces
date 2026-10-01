---
name: fastapi-stress-test-apply
description: FastAPI 서버에 부하·스트레스 테스트를 걸기 전에 서버 쪽에서 설정·확인할 것을 정할 때 사용한다 — 지연 히스토그램·in-flight 계측(멀티 워커면 prometheus 멀티프로세스), fastapi dev·--reload·debug 같은 무효 설정, 워커·스레드 토큰·DB 풀, pyperf. 트리거 — "부하 테스트 준비", "FastAPI 성능 측정", "uvicorn 워커", "/metrics", "pyperf".
---

# FastAPI 부하 측정 준비

규칙 원본: [`references/fastapi-stress-rules.md`](../../references/fastapi-stress-rules.md)
기계 검증: [`scripts/fastapi-stress-config-validate.sh`](../../scripts/fastapi-stress-config-validate.sh)

이 스킬은 **FastAPI 쪽**만 맡는다. 부하 스크립트 작성(open 모델 · 단계)은 `common-stress-test` 의 `stress-test-create`, 결과 판정(SLO · knee · Little · 회귀)은 `stress-result-review` 에 넘긴다.

## 1. 무효 설정부터 없앤다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/fastapi-stress-config-validate.sh" .
```

`❌` 가 있으면 측정하지 않는다. 훅은 부하 도구(`k6 run` · `locust` · `wrk` …)를 실행할 때 같은 검사를 알림으로 보여 준다.

| 조항 | 고칠 것 |
|---|---|
| `FAS-01` | `fastapi dev` · `--reload` → `fastapi run app/main.py --workers N` 또는 `uvicorn app.main:app --workers N` |
| `FAS-02` | 워커 ≥ 2 + prometheus → 시작 스크립트에서 `PROMETHEUS_MULTIPROC_DIR` 를 비우고 만든다 |
| `FAS-03` | Gunicorn 이면 `gunicorn.conf.py` 에 `child_exit` → `mark_process_dead(worker.pid)` |
| `FAS-04` · `FAS-05` | `debug=True` 제거, 로그 레벨 `info` 이상. 액세스 로그를 끄면(`--no-access-log`) 그 사실을 결과에 적는다 |
| `FAS-06` | `-k uvicorn_worker.UvicornWorker` (`pip install uvicorn-worker`) |
| `FAS-07` | `async def` 안 `time.sleep` · `requests` → `await asyncio.sleep` · `httpx.AsyncClient`, 아니면 `def` 로 바꿔 스레드풀에 보낸다 |

스크립트는 리터럴만 본다. `debug=settings.debug` · `--workers "$N"` 처럼 변수면 **값의 출처를 직접 확인**한다. 측정에 실제로 쓰는 구성(Dockerfile · compose · k8s 매니페스트 중 무엇인지)도 확인한다.

## 2. 계측을 붙인다

규칙 원본 2절의 레시피를 쓴다. 이미 계측이 있으면 아래만 확인한다.

1. 지연은 **Histogram** 이다 (`FAS-09`). 분위수는 버킷을 합친 뒤 `histogram_quantile` 로 한 번만 계산한다 (`ST-31`)
2. 버킷이 SLO 근처를 덮는다 (`FAS-10`). instrumentator 의 핸들러별 기본 버킷은 `0.1 · 0.5 · 1` 뿐이라 `latency_lowr_buckets` 를 준다
3. in-flight 게이지가 있다 (`FAS-08`) — `should_instrument_requests_inprogress=True` → `http_requests_inprogress`. 직접 계측이면 `Gauge(…, multiprocess_mode="livesum")`
4. `/metrics` 를 계측에서 뺀다 (`excluded_handlers=["/metrics"]`)
5. 확인 — 부하 없이 요청 몇 개를 보내고 `curl -s localhost:8000/metrics | grep -E '_bucket|inprogress'`. 워커가 여럿이면 여러 번 긁어 **값이 번갈아 바뀌지 않는지** 본다 (`FAS-02` 실측 증상)

in-flight 게이지는 미들웨어에 들어온 요청만 센다. 포화 뒤 L < λW 는 백로그 · 루프 대기가 빠진 것이다 — 측정 오류로 단정하지 않는다.

## 3. 손잡이를 확인하고 포화점을 예측한다

측정 전에 예상 상한을 적어 두고, 결과의 knee 와 비교한다.

| 엔드포인트 종류 | 워커당 상한 (대략) | 확인 |
|---|---|---|
| `def` (블로킹 I/O) | 스레드 토큰 40 ÷ 평균 처리 시간 | `anyio.to_thread.current_default_thread_limiter().total_tokens` |
| `async def` (await 만) | CPU · 다운스트림이 먼저 막힌다 | 이벤트 루프 지연 |
| `async def` 안 블로킹 T 초 | 1 ÷ T | `FAS-07` — 고친다 |
| DB 사용 | `pool_size + max_overflow` (기본 5 + 10) ÷ 쿼리 보유 시간 | 풀 대기 시간 |
| CPU 바운드 | 코어당 처리량 × 워커 수 | 워커 수 = 코어 수부터 |

- 전체 상한 = 워커 수 × 워커당 상한. 다운스트림(DB 풀 · 외부 API)이 더 작으면 그쪽이 상한이다
- 토큰을 바꾸려면 lifespan 안에서 `total_tokens` 를 바꾼다 (규칙 원본 3절)
- `--limit-concurrency` 가 있으면 넘는 요청은 503 이다 — 에러율로 판정된다
- 워커 1개 결과를 머신 용량으로 일반화하지 않는다 (`FAS-13`). Kubernetes 에서 컨테이너당 프로세스 하나면 레플리카 수가 손잡이다

## 4. 마이크로벤치마크

엔드포인트 안의 특정 코드(직렬화 · 검증 · 쿼리 빌드)를 비교할 때 쓴다. 부하 테스트로 대신하지 않는다.

```python
# bench_x.py
import pyperf

def target():
    ...

if __name__ == "__main__":          # 모듈 수준에 두면 import 할 때 인자 파싱으로 죽는다
    pyperf.Runner().bench_func("target", target)
```

```bash
python bench_x.py -o base.json        # 바꾸기 전
python bench_x.py -o new.json         # 바꾼 뒤 — 같은 머신에서 이어서
python -m pyperf compare_to base.json new.json --table
```

- 기본은 프로세스 20 × 값 3 + 워밍업 1. 잡음이 크면 `--rigorous`, `pyperf system tune`
- `compare_to` 가 "Not significant" 면 차이가 없다고 보고한다
- async 함수는 `bench_async_func`
- pytest-benchmark 를 이미 쓰면 `--benchmark-warmup=on` 을 주고, `--benchmark-compare-fail` 은 고정 임계일 뿐이라 회귀 판정은 반복 분포로 한다 (`ST-20`)

## 5. 넘길 것

- 부하 스크립트 · 단계 설계 → `stress-test-create`
- 단계 CSV 판정 → `stress-result-review` (`stress-report-generate.sh --model open steps.csv`). in-flight 열은 `http_requests_inprogress` 의 단계 평균(램프 구간 제외)
- 결과에 적을 환경: Python · fastapi · uvicorn 버전, 실행 명령(워커 수), CPU 제한, 스레드 토큰 · 풀 크기
