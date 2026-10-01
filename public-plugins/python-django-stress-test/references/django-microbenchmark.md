# Django 코드 수준 마이크로벤치마크

규칙: [`django-stress-rules.md`](django-stress-rules.md) `DJ-20`. 통계 판정(Mann-Whitney U · Cliff's delta · 효과크기 CI)은 `common-stress-test` 의 `ST-20` 을 따른다.
아래는 pyperf 2.10 · pytest-benchmark 5.3 · pytest-django 4.14 에서 실제로 돌렸다.

## 1. 도구 고르기

| 도구 | 쓰는 곳 | 실행 방식 | 비교 |
|---|---|---|---|
| pyperf | 함수 · 쿼리 경로 하나를 두 버전으로 비교 | **프로세스를 나눠** 반복 (기본 워커 20개 × 워밍업 1 + 값 3, 루프는 값 하나가 100 ms 가 되게 보정) | `pyperf compare_to` — 두 표본 t 검정, 유의하지 않으면 "Not significant" |
| pytest-benchmark | 기존 pytest(-django) 테스트에 붙여 회귀 감시 | 한 프로세스 안에서 라운드 반복 (`--benchmark-min-rounds` 기본 5) | `--benchmark-compare-fail=median:10%` — 통계 검정이 아니라 고정 임계 |

판정에는 pyperf 를 쓴다. pytest-benchmark 는 같은 코드를 두 번 돌려도 median 이 22.5 → 17.9 µs (26%) 로 달랐다 — 고정 10% 임계는 이 잡음에 걸린다 (실측, Docker Desktop).

## 2. pyperf

```python
# bench_query.py
import os
import pyperf

def setup():
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "myproject.settings")
    import django
    django.setup()
    from django.db import connection
    return connection

def one_query(connection):
    with connection.cursor() as c:
        c.execute("SELECT COUNT(*) FROM sqlite_master WHERE name = %s", ["x"])
        c.fetchone()

runner = pyperf.Runner()
runner.bench_func("sqlite_one_query", one_query, setup())
```

```bash
python bench_query.py -o base.json                         # 기준 버전
python bench_query.py -o change.json                       # 바꾼 버전
python -m pyperf compare_to base.json change.json --table
python -m pyperf stats change.json                         # 분포 · 이상치
```

- **워커 프로세스는 환경 변수를 물려받지 않는다.** 설정을 환경 변수로 바꾸면 `--inherit-environ NAME[,NAME…]` 을 준다. 실측: `APP_DEBUG=1` 이 없으면 워커에서 `None` 이었다. `DJANGO_SETTINGS_MODULE` 도 같으므로 스크립트에서 `setdefault` 로 정한다
- 표준편차가 평균의 큰 비율이면 "the benchmark result may be unstable" 경고가 나온다 — 무시하지 않는다. `python -m pyperf system tune` 또는 `--rigorous`(워커 수 2배)로 다시 잰다. `--fast` 는 대략 보기용
- DB 를 쓰는 코드는 sqlite 로 충분하다. 바꾼 것이 쿼리 수 · ORM 경로라면 같은 DB 에서 비교한다. 네트워크 DB 지연은 부하 테스트 쪽에서 본다
- `compare_to --min-speed 5` 로 5% 미만 차이를 숨길 수 있다. 판정 근거로는 표본 분포와 효과크기를 같이 적는다 (`ST-20`)

## 3. pytest-benchmark (pytest-django)

```python
# tests/test_bench.py
import pytest
from django.test import RequestFactory
from myapp import views

@pytest.mark.django_db
def test_order_list_view(benchmark):
    request = RequestFactory().get("/orders")
    response = benchmark(views.order_list, request)
    assert response.status_code == 200
```

```bash
pytest tests/test_bench.py --benchmark-warmup=on --benchmark-min-rounds=50 --benchmark-autosave
pytest tests/test_bench.py --benchmark-warmup=on --benchmark-min-rounds=50 --benchmark-compare --benchmark-compare-fail=median:10%
```

- 워밍업 기본값은 `auto` — **PyPy 에서만** 켜진다. CPython 에서도 첫 호출 비용(임포트 · 쿼리 캐시 · 연결 수립)을 빼려면 `--benchmark-warmup=on`
- `--benchmark-disable-gc` 는 GC 비용을 빼므로 할당이 많은 코드를 비교할 때는 끄지 않는다
- 결과 표의 `Outliers` 와 `IQR` 을 같이 본다. 실측 한 번에 Min 14.6 µs · Max 5,998 µs — 평균보다 median 이 안정적이다
- 시간 의존 코드(`time.sleep`)는 `monkeypatch` 로 빼고 잰다. 마이크로벤치마크는 CPU 경로만 본다

## 4. 하지 않는 것

- `DEBUG = True` 설정으로 재지 않는다 — 쿼리마다 기록 비용이 붙는다 (`DJ-02`)
- `timeit` 한 번 · `time.time()` 차이 한 번으로 판정하지 않는다 — 반복 분포가 없다
- 두 버전을 다른 시각 · 다른 머신에서 재지 않는다. 같은 머신에서 번갈아 돌린다 (`ST-20`)
