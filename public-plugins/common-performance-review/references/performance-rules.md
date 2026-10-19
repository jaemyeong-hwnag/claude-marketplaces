# 성능 리뷰 규칙

코드 변경을 읽고 성능 위험을 찾는 규칙의 원본이다. 근거와 출처는 [`performance-methods.md`](performance-methods.md) 에 있다.

- `PF-01` ~ `PF-20` — 기계 패턴. `scripts/performance-validate.sh` 가 찾는다. **모두 경고**다. 후보일 뿐이므로 판정은 `PF-40` 이후를 따른다
- `PF-30` ~ `PF-38` — 필수 범주. 리뷰마다 전부 판정한다 (AI 판단)
- `PF-40` ~ `PF-47` — 지적 하나의 형식과 판정 규칙

정적 리뷰는 **가설을 낸다.** 확정은 측정(쿼리 수 assert · 실행 계획 · 벤치마크 · 프로파일)이 한다.

## 1. 기계 패턴 (경고)

루프는 `for` · `while` 과 콜백 반복(`forEach` · `map` · `flatMap` · `filter` · `reduce` …)이다. 루프 헤더(`for (x : repo.findAll())`) 는 한 번만 실행되므로 루프 안으로 보지 않는다.

| 조항 | 패턴 | 범주 | 근거 |
|---|---|---|---|
| `PF-01` | 루프 안 DB 호출 (리포지토리 · ORM · `execute` · `query` · `save` …) — N+1 | 쿼리 | CWE-1050 · CWE-1060 · Chen ICSE'14 · GitLab |
| `PF-02` | 루프 안 원격 호출 (HTTP · Redis · RPC) | 네트워크 | CWE-1050 · Azure Chatty I/O |
| `PF-03` | `for` / `while` 안의 `await` (콜백 · `for await` 는 제외) | 네트워크 · 동시성 | ESLint `no-await-in-loop` |
| `PF-04` | 루프 안 정규식 컴파일 | 시간 | SpotBugs `IIL_PATTERN_COMPILE_IN_LOOP` · staticcheck `SA6000` |
| `PF-05` | 루프 안 선형 탐색 (`contains` · `indexOf` · `includes`) — O(n·m) | 시간 | Jin PLDI'12 |
| `PF-06` | 루프 안 문자열 누적 (`s += "…"`) — O(n²) | 시간 · 공간 | CWE-1046 · SpotBugs `SBSC_USE_STRINGBUFFER_CONCATENATION` |
| `PF-07` | 루프 안 컬렉션 복사 (`[...acc, x]` · `concat` · `xs = xs + [..]`) — O(n²) | 시간 · 공간 | Biome `noAccumulatingSpread` |
| `PF-08` | 루프 안 무거운 객체 · 커넥션 생성 (`ObjectMapper` · `HttpClient` · `sql.Open` …) | 자원 | CWE-1072 · Azure Improper Instantiation |
| `PF-10` | `SELECT *` | 쿼리 | Karwin *Implicit Columns* · Azure Extraneous Fetching |
| `PF-11` | `OFFSET` 페이지네이션 | 쿼리 | Use The Index, Luke · GitLab |
| `PF-12` | 상한 없는 전체 조회 (`findAll()` · `objects.all()` · `findMany()` · `find({})`) | 쿼리 · 용량 | CWE-770 · OWASP API4:2023 · Google AIP-158 |
| `PF-13` | 앞에 `%` 가 붙는 `LIKE` · `__contains=` · `Containing(` | 쿼리 | CWE-1067 · Karwin *Poor Man's Search Engine* |
| `PF-14` | `ORDER BY RAND()` | 쿼리 | Karwin *Random Selection* |
| `PF-15` | 비동기 코드 안의 블로킹 호출 (Python `async def` 안 `time.sleep` · `requests` · `open`, JS · TS 의 `*Sync(`) | 동시성 | Ruff `ASYNC2xx` · Express 운영 가이드 |
| `PF-16` | 타임아웃 없는 HTTP 클라이언트 (Python `requests` · Go 기본 클라이언트) | 네트워크 | Amazon Builders' Library · golangci `noctx` |
| `PF-17` | 역추적이 폭발할 수 있는 정규식 (`(a+)+` · `.*` 셋 이상) | 정규식 | CWE-1333 · Cloudflare 2019 · Davis FSE'18 |
| `PF-18` | `FetchType.EAGER`, LAZY 를 적지 않은 `@ManyToOne` · `@OneToOne` | 쿼리 | Hibernate 6 Introduction |
| `PF-19` | 상한 없는 캐시 · static 컬렉션 (`lru_cache(maxsize=None)` · `static Map = new HashMap`) | 공간 | CWE-1042 · CWE-770 · Pylint `W1518` |
| `PF-20` | 개수 · 존재 확인에 전체 로딩 (`len(qs)` · `findAll().size()`) | 쿼리 · 공간 | Django DB 최적화 문서 |

보는 파일: `.py` · `.java` · `.kt` · `.kts` · `.scala` · `.go` · `.js` · `.jsx` · `.mjs` · `.cjs` · `.ts` · `.tsx` · `.cs` · `.php` · `.swift` · `.rs` · `.sql`.
테스트 경로(`test/` · `tests/` · `*_test.go` · `*.test.*` · `*.spec.*` · `*Test.java` · `test_*.py` …)는 `--include-tests` 를 줄 때만 본다. 테스트 경로인지는 git 최상위(저장소가 아니면 프로젝트 · 대상 디렉터리) 기준 상대 경로로 판정한다 — 저장소 바깥 상위 디렉터리 이름은 보지 않는다.
의도한 줄이면 그 줄 끝이나 바로 윗줄에 `performance-ignore` 주석을 둔다.

## 2. 필수 범주 (AI 판단)

리뷰는 아래 9개 범주마다 **`발견` · `문제없음` · `해당없음` · `측정필요` 중 하나**를 낸다. 하나라도 비면 리뷰가 끝나지 않은 것이다. `해당없음` · `문제없음` 도 한 줄 이유를 적는다.

| 조항 | 범주 | ISO 25010 | 반드시 볼 것 |
|---|---|---|---|
| `PF-30` | 시간 복잡도 | 시간 | 변경 **전후** Big-O. 중첩 반복 · 루프 안 선형 탐색 · 반복 정렬 · 조기 종료 누락 · 루프 불변 계산 |
| `PF-31` | 공간 · 할당 | 자원 | 전체 로딩 vs 스트림, 무한히 자라는 컬렉션 · 캐시, 핫패스의 큰 값 복사 · 임시 객체, 미리 잡지 않은 컨테이너 |
| `PF-32` | DB 쿼리 | 시간 · 자원 | 요청당 쿼리 수가 데이터 크기에 비례하는가(N+1), 안 쓰는 eager 로딩 · 컬럼, 인덱스(새 WHERE · ORDER BY · JOIN 컬럼), 페이지네이션, bulk, 트랜잭션 범위 |
| `PF-33` | 네트워크 · IO | 시간 | 왕복 횟수, 타임아웃 · 데드라인 전파, 재시도는 한 층에서만 + 지터, **트랜잭션 안 외부 호출 금지**, 비동기 안의 블로킹 |
| `PF-34` | 동시성 · 락 | 용량 | 락 범위 · 획득 빈도 · 순서, 풀 · 큐 크기의 근거(Little 의 법칙), 팬아웃의 꼬리 지연(타임아웃 · 부분 결과) |
| `PF-35` | 캐싱 | 자원 | 같은 입력으로 반복 계산되는가, 무효화 조건 · TTL, 동시 미스(thundering herd), 크기 상한 |
| `PF-36` | 페이로드 · 용량 | 용량 | 응답 · 요청 크기 상한, `page_size` 상한, 업로드 · 배열 길이 제한, 직렬화 비용 |
| `PF-37` | 자원 해제 | 자원 | 커넥션 · 스트림 · 응답 바디 · 커서 닫기, 커넥션 풀 사용 |
| `PF-38` | 정규식 | 시간 | 사용자 입력이 닿는 경로의 초선형 패턴 |

선택 범주 — 해당 스택일 때만: 프런트엔드 번들 · Web Vitals (LCP 2.5 s · INP 200 ms · CLS 0.1, p75), 마이그레이션 락 (`lock_timeout` · 배치 갱신), GC 언어의 큰 상주 캐시.

## 3. 지적의 형식과 판정

| 조항 | 규칙 |
|---|---|
| `PF-40` | 지적마다 `[범주/조항] 심각도 · 신뢰도 · 위치 · 근거 · 규모 가정 · 수정 · 검증` 을 적는다 |
| `PF-41` | **규모 가정**(행 수 · 요청 수 · 컬렉션 크기)이 없으면 심각도를 `낮음` 보다 올리지 않는다. 테스트 데이터에서 빠른 것은 근거가 아니다 |
| `PF-42` | **심각도와 신뢰도를 따로 적는다.** 설계 수준 · 설정 의존 · 런타임 의존은 diff 만으로 확정하지 않고 `측정필요` 로 둔다 |
| `PF-43` | 복잡도는 **변경 전후 비교**로 지적한다. 원래 O(n²) 였고 바뀌지 않았으면 이번 변경의 지적이 아니다 (별도 메모) |
| `PF-44` | 기계 패턴은 **호출자 · 데이터 출처를 읽고** 판정한다. 컬렉션이 이미 Set 인지, 반복 수가 상수인지, 이미 배치인지 확인한다 |
| `PF-45` | 측정 근거 없는 마이크로 최적화(박싱 · 짧은 문자열 연결 · 런타임이 이미 하는 최적화)는 `낮음` 이다 |
| `PF-46` | 수정 제안에는 **기능 동등성**(순서 · 중복 · null · 트랜잭션 의미)과 **검증 방법**을 같이 적는다 |
| `PF-47` | 캐시 제안은 반복 계산의 근거와 **무효화 조건**이 있을 때만 한다 |

심각도: `높음` — 데이터 · 요청 크기에 비례해 나빠지고 규모 가정상 사용자 지연 · 장애가 된다. `중간` — 비례하지만 상한이 작거나 경로가 드물다. `낮음` — 상수 배 · 마이크로 최적화.
신뢰도: `높음` — 코드만으로 확정. `중간` — 맥락 가정 하나가 필요. `낮음` — 런타임 · 데이터 분포에 달렸다 (`측정필요`).

## 4. 검증 방법 (측정)

| 지적 | 검증 |
|---|---|
| N+1 · 쿼리 수 | 쿼리 수 assert — Django `assertNumQueries` · django-zeal · nplusone, SQLAlchemy `raiseload('*')`, JVM QuickPerf `@ExpectMaxSelect` · hypersistence `SQLStatementCountValidator` · datasource-proxy `QueryCountHolder`, Prisma `$on('query')` 카운터, Rails `strict_loading` · Bullet. 데이터를 N 과 2N 으로 늘려 쿼리 수가 같아야 한다 |
| 인덱스 · 느린 쿼리 | `EXPLAIN (ANALYZE, BUFFERS)` 전후 — Seq Scan · 추정 대비 실제 rows · `Rows Removed by Filter` · 디스크 정렬 |
| 시간 복잡도 | N 을 2배씩 늘린 실행 시간 비율 (Python `big_O`), 마이크로벤치 — JMH · pytest-benchmark · Go `testing.B` + benchstat |
| 할당 · 메모리 | Go `testing.AllocsPerRun` · `-benchmem`, async-profiler alloc, 힙 스냅샷. 런타임 힙과 OS RSS 를 같이 본다 |
| 지연 · 용량 | 부하 테스트 — `common-stress-test` 플러그인 |

벤치마크 근거는 같은 머신 · 반복 실행 · 통계 검정(Mann-Whitney U · 부트스트랩)이 있을 때만 믿는다. 고정 임계값보다 상대 · 통계 기준이 낫다.
