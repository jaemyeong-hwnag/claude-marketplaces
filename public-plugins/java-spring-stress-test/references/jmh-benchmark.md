# JMH 마이크로벤치마크 절차

규칙: [`spring-stress-rules.md`](spring-stress-rules.md) `SPR-10` · `SPR-14`. 확인 기준 JMH 1.36 · 1.37 (소스) · Gradle 플러그인 `me.champeau.jmh` 0.7.3.

HTTP 부하 측정으로 원인을 메서드 하나로 좁힌 뒤에 쓴다. 서버 전체 용량은 부하 측정으로 본다.

## 1. 설정 (Gradle)

```groovy
plugins { id 'me.champeau.jmh' version '0.7.3' }

jmh {
    warmupIterations = 5      // JMH 기본 5
    warmup = '10s'            // 기본 10s
    iterations = 5            // 기본 5
    timeOnIteration = '10s'   // 기본 10s
    fork = 3                  // 기본 5. 0 금지 (SPR-10)
    resultFormat = 'JSON'     // 기본 CSV
}
```

- 벤치마크 소스는 `src/jmh/java` 에 둔다. `./gradlew jmh` 결과는 `build/results/jmh/results.json`
- Maven 은 `jmh-java-benchmark-archetype` 으로 별도 모듈을 만들고 `java -jar target/benchmarks.jar -f 3 -wi 5 -i 5 -rf json` 으로 돈다
- 명령행 옵션: `-f` fork · `-wi` 워밍업 반복 · `-i` 측정 반복 · `-w` / `-r` 반복 시간 · `-rf json` · `-prof gc`

## 2. 벤치마크 작성

```java
@State(Scope.Benchmark)
@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Warmup(iterations = 5, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(3)
public class PriceBench {
    @Param({"10", "1000"}) int n;
    List<Item> items;

    @Setup public void setUp() { items = Fixtures.items(n); }

    @Benchmark public long total() { return calculator.total(items); }      // 반환값으로 dead code 제거를 막는다
    @Benchmark public void each(Blackhole bh) { for (Item i : items) bh.consume(calculator.price(i)); }
}
```

| 함정 | 결과 | 대책 |
|---|---|---|
| 결과를 버림 | JIT 가 계산을 지운다 (dead code elimination) | 반환하거나 `Blackhole.consume` |
| 입력이 상수 | 상수 접기 | `@State` 필드에서 읽는다 |
| `@Fork(0)` | 호스트 JVM 의 프로파일 · 옵션이 섞인다. JMH 가 "debugging purposes" 만이라고 경고한다 | fork 1 이상, 비교는 2 이상 |
| 반복 안에서 준비 작업 | 준비 비용이 측정에 들어간다 | `@Setup(Level.Trial)` · `Level.Iteration` |
| Spring 컨텍스트를 띄워서 잼 | 프록시 · AOP 를 재는지 로직을 재는지 섞인다 | 대상 클래스를 직접 만든다. 프록시 비용이 궁금하면 따로 잰다 |

## 3. 실행 출력 (실측)

`gradle jmh` (플러그인 0.7.3 → JMH 1.36, `fork = 2`, 워밍업 3 × 1s, 측정 5 × 1s, 2 CPU 컨테이너, 호스트 부하 높음) 의 끝 표:

```
Benchmark            (n)  Mode  Cnt     Score     Error  Units
ConcatBench.builder   10  avgt   10    25.892 ±  11.974  ns/op
ConcatBench.builder  100  avgt   10   304.407 ±  77.573  ns/op
ConcatBench.plus      10  avgt   10   200.035 ± 158.478  ns/op
ConcatBench.plus     100  avgt   10  2228.750 ± 622.437  ns/op
```

- 플러그인 0.7.3 의 기본 JMH 는 1.36 이다. 다른 버전은 `jmh { jmhVersion = '1.37' }`
- `Cnt` = fork × 측정 반복. `Error` 는 99.9% 신뢰구간의 반폭이다 (JMH `Result` 가 0.999 로 계산)
- JSON 에는 `primaryMetric.score` · `scoreError` · `scoreConfidence` · `rawData`(fork 별 반복값 배열)가 있다. 비교 통계는 `rawData` 로 한다
- 위 실측의 `builder n=10` `rawData` 는 fork 1 이 `21.2 20.5 21.6 23.6 44.4`, fork 2 가 `25.5 21.6 21.3 23.4 35.9` 였다. 마지막 반복이 튄 것은 같은 호스트의 다른 부하다 — Error 가 Score 의 46% 면 비교에 쓰지 않는다
- JDK 17 이상에서는 `Blackhole mode: compiler` 가 자동으로 쓰인다. 다른 Blackhole 모드 결과와 비교하지 않는다
- 출력 앞의 `# Warmup Iteration` 값이 측정 반복과 비슷해졌는지 본다. 실측 `builder n=10` 은 워밍업 26.7 → 23.1 → 21.0, 측정 20.5 ~ 23.6 이었다

## 4. 비교 판정 (`SPR-14`)

1. 두 버전을 **같은 머신에서 번갈아** 돌린다 (A B A B …). 클라우드 인스턴스는 변동이 크다 — Laaber et al. EMSE 2019
2. fork 를 늘린다 — 변동은 실행(fork) 수준과 반복 수준에서 따로 생긴다. 반복만 늘리면 실행 수준 변동을 놓친다 — Kalibera & Jones ISMM 2013
3. 워밍업을 확인한다 — JMH 벤치 586개 중 43.5% 가 정상 상태에 일관되게 이르지 못했고 개발자가 정한 워밍업이 맞은 경우는 19% 뿐이었다 — Traini et al. EMSE 28 (2023). 반복값 시계열에서 최근 k 회의 변동계수가 0.01 ~ 0.02 아래인지 본다 — Georges et al. OOPSLA 2007
4. 차이를 **효과크기와 신뢰구간**으로 보고한다 ("A 가 5.5% ± 2.5% 빠르다"). 두 신뢰구간이 겹치거나 차이의 신뢰구간이 0 을 포함하면 차이 없음 — Georges 2007
5. 분포가 치우쳤으면 `rawData` 를 펴서 `common-stress-test` 의 회귀 판정(`ST-20` Mann-Whitney U · Cliff's delta)에 넣는다

## 5. 하지 않는 것

- 운영 서버 · 부하 측정 중인 머신에서 돌리지 않는다 (CPU 경합)
- 노트북 절전 · 터보 상태가 바뀌는 환경의 결과를 비교 기준으로 쓰지 않는다. 환경을 결과와 같이 남긴다 (JDK · CPU · fork · 반복)
