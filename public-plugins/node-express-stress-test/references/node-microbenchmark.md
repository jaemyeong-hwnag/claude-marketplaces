# Node.js 마이크로벤치마크 절차

핸들러 안의 코드 한 조각(직렬화 · 검증 · 정규식 · 변환)을 비교할 때 쓴다. HTTP 부하 측정을 대신하지 않는다.
tinybench 4.1.0 · mitata 1.0.34 · Node.js 22.23 에서 돌려 본 결과로 적었다.

## 1. 도구 고르기

| | tinybench | mitata |
|---|---|---|
| 워밍업 | `warmupTime`(ms) · `warmupIterations` | 자동 |
| 반복 | `time`(ms) 동안 또는 `iterations` 회 | 자동 (시간 · 표본 수 기준) |
| 출력 | `bench.table()` — 평균 · 중앙값 지연, 처리량, 표본 수, **rme(상대 오차 %)** | avg · min … max · p75 · p99 · 히스토그램 · 메모리(`--expose-gc`) · `summary` 의 배수 비교 |
| 결과를 코드로 | `task.result.latency.{mean,p99,rme,samples}` (ms) | `run()` 반환값 |
| 최적화 제거 방지 | 반환값을 쓰게 한다 | `do_not_optimize(x)` |

둘 다 **한 프로세스 안의 반복** 통계다. 두 구현의 차이를 주장할 때는 2절의 프로세스 반복을 더한다.

## 2. 절차

1. 대상 코드를 함수로 떼고, 입력은 운영 크기로 만든다 (빈 배열 · 한 줄짜리 문자열 X)
2. 결과를 버리지 않는다 — 반환하거나 `do_not_optimize` 로 감싼다. 버리면 JIT 가 계산을 지울 수 있다
3. CPU 를 고정하고(`taskset` · `docker --cpuset-cpus`) 다른 부하가 없을 때 돌린다
4. 워밍업을 둔다. tinybench 는 `warmupTime` 을 명시한다
5. 같은 비교를 **새 프로세스로 5회 이상** 돌리고, 순서를 번갈아 바꾼다 (A B B A …). 프로세스마다 JIT 결과가 다르다
6. 프로세스별 중앙값으로 차이를 낸다 — 비교 통계(Mann-Whitney U · 효과크기 CI)는 `common-stress-test` 의 판정 절차를 따른다
7. rme 가 수 % 를 넘거나 p99 가 평균의 몇 배면 노이즈가 크다 — 3번부터 다시 본다

## 3. tinybench

```js
// bench-serialize.mjs
import { Bench } from 'tinybench';

const items = Array.from({ length: 1000 }, (_, i) => ({ id: i, name: 'item' + i, price: i * 10 }));
const bench = new Bench({ name: 'serialize', time: 1000, warmupTime: 200 });
bench
  .add('JSON.stringify', () => JSON.stringify(items))
  .add('manual concat', () => { let s = '['; for (const it of items) s += `{"id":${it.id}},`; return s; });

await bench.run();
console.table(bench.table());
```

출력 (실측):

```
│ Task name        │ Latency avg (ns) │ Latency med (ns) │ Throughput avg (ops/s) │ Throughput med (ops/s) │ Samples │
│ 'JSON.stringify' │ '75918 ± 0.47%'  │ '72958 ± 2458.0' │ '13433 ± 0.15%'        │ '13707 ± 469'          │ 13176   │
│ 'manual concat'  │ '48546 ± 0.72%'  │ '44417 ± 1042.0' │ '21814 ± 0.16%'        │ '22514 ± 519'          │ 20600   │
```

- `± %` 는 평균의 상대 오차(rme), 중앙값 옆 `±` 는 MAD 다
- tinybench 4 는 결과가 `task.result.latency` · `task.result.throughput` 아래에 있다 (3.x 와 다르다)

## 4. mitata

```js
// bench-serialize.mjs
import { bench, run, summary, do_not_optimize } from 'mitata';

const items = Array.from({ length: 1000 }, (_, i) => ({ id: i, name: 'item' + i, price: i * 10 }));
summary(() => {
  bench('JSON.stringify', () => do_not_optimize(JSON.stringify(items)));
  bench('manual concat', () => { let s = '['; for (const it of items) s += `{"id":${it.id}},`; return do_not_optimize(s); });
});
await run();
```

```bash
node --expose-gc bench-serialize.mjs   # --expose-gc 가 있으면 반복당 메모리도 낸다
```

출력 (실측, 색 제거):

```
benchmark                   avg (min … max) p75 / p99    (min … top 1%)
JSON.stringify                74.41 µs/iter  75.13 µs
                     (67.67 µs … 373.83 µs) 102.54 µs
                    ( 39.83 kb …  76.57 kb)  41.66 kb
manual concat                 50.54 µs/iter  46.96 µs
                       (40.71 µs … 3.09 ms) 327.50 µs
summary
  manual concat
   1.47x faster than JSON.stringify
```

- `summary` 의 배수는 한 프로세스의 평균 비다. p99 가 크게 다르면(위 327 µs vs 103 µs) 평균 비만으로 고르지 않는다 — 꼬리와 할당량(kb)을 같이 본다
- 위 예에서 빠른 쪽이 반복당 메모리 5배를 쓴다. 서버에서는 GC 로 다른 요청의 꼬리 지연이 될 수 있다

## 5. 프로파일러

원인을 찾을 때만 쓴다. 그 실행의 수치는 결과로 보고하지 않는다 (`NEX-04`).

| 도구 | 쓰임 |
|---|---|
| `node --cpu-prof` | V8 CPU 프로파일 `.cpuprofile` — Chrome DevTools 로 연다 |
| 0x | 플레임 그래프 |
| clinic (doctor · flame · bubbleprof) | 이벤트 루프 지연 · I/O 대기 원인 분류 |
