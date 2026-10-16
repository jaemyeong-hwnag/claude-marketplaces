# 성능 리뷰 근거

규칙 원본 [`performance-rules.md`](performance-rules.md) 의 조항이 기대는 출처다. 번호 I* 는 업계, A* 는 학술 자료다. 오프라인에서 읽도록 URL 대신 저자 · 제목 · 발표처 · 연도로 적는다.

조사 기준일 2026-10-16.
표시: **[부분]** 미러 · 2차 출처로만 확인 / **[미확인]** 1차 출처 미확인 / **[DOI 미대조]** 기억으로 적은 DOI — 인용 전 DOI 를 대조한다.

---

## 0. 설계 원칙과 근거

| # | 원칙 | 근거 |
|---|---|---|
| 1 | **결정적 패턴 검사를 먼저, LLM 판단은 그 위에** — LLM 단독 성능 버그 탐지는 F1 이 낮고, LLM 리뷰 오탐의 48% 가 "주변 맥락 무시" | 학술 A45 · A46, PowerStation A15 |
| 2 | **절대 복잡도가 아니라 diff 전후 비교로 지적** — O(n)→O(n²) 같은 *증가*만 보고 | Infer Cost `EXECUTION_TIME_COMPLEXITY_INCREASE` (A21) |
| 3 | **ORM · 루프 · API 오용이 최우선 범주** — 정적 탐지 가능, 수정은 대개 5줄 미만 | Jin PLDI'12, Yang ICSE'18 (78% 가 5줄 미만), Selakovic ICSE'16 |
| 4 | **데이터 규모 가정을 함께 적는다** — DB 앱 성능 버그 대부분이 "테스트 데이터에선 빠른" 확장성 문제 | Yang ICSE'18 (느린 액션 40 중 34), GitLab 100k 행 테스트 |
| 5 | **정적 리뷰는 가설 생성, 확정은 측정** — 0.01% 회귀는 리뷰로 못 잡는다. 실행 계획 · 벤치마크 · 쿼리 수 assert 를 요구 | Meta ServiceLab/FBDetect, Netflix, GitLab DB review |
| 6 | **신뢰도 · 심각도를 분리 출력** — 설계 수준(27%) · 설정 의존 버그는 diff 만으로 판단 불가 → "측정 필요" 로 분리 | Zhao TSE'22, Han ESEM'16, Mozilla 오탐 12.5% |
| 7 | **수정 제안은 기능 동등성 + 측정을 같이 요구** — LLM 최적화는 정확성을 자주 깬다 | ECCO, SWE-Perf |

---

## 1. 업계 레퍼런스

### 1.1 운영 전 성능 회귀 탐지 (CI · 리뷰)

| # | 조직 · 제목 | 플러그인이 가져갈 것 |
|---|---|---|
| I1 | Meta — ServiceLab (OSDI 2024 Best Paper) | 배포 전 0.01% 회귀 탐지, 회귀 중앙값 0.14%. → 이런 크기는 리뷰로 못 잡으니 **증거 요구** 역할로 한정 |
| I2 | Meta — FBDetect (SOSP 2024) **[부분]** | 회귀 함수를 최근 PR 과 연결. → "핫패스 함수 변경" 을 우선순위 신호로 |
| I3 | Meta — Strobelight (2025) | `auto`→`auto&` 한 글자로 서버 ~15,000대 절감. → **핫패스 값 복사** 규칙 |
| I4 | Netflix — Fixing Performance Regressions Before they Happen (2022) **[부분]** | 고정 임계값 실패 → 직전 40회 평균+4σ, e-divisive 변화점. → 임계값은 **상대 · 통계 기준** 권고 |
| I5 | MongoDB — Change Point Detection in CI (ICPE 2020) | 유용한 알림 비율 ~1% → 67% |
| I6 | Figma — Keeping Figma Fast (2023) | PR 마다 벤치마크, 10분 내 피드백, 잡음 때문에 여유 20% |
| I7 | Google — Performance Hints (Jeff Dean · Sanjay Ghemawat) | 구현 전 추정(연산 수 × 단가), `reserve`, 루프 불변식 끌어올리기, 뷰 타입 인자, 핫패스 로그 샘플링, 할당 수 줄이기 |
| I8 | Google — Code Review Guide "What to look for" | **성능 항목이 없다** → 별도 플러그인이 필요한 근거 |
| I9 | Cloudflare — 2019-07-02 장애 | `.*.*=.*` 정규식 역추적으로 전 세계 CPU 고갈. → 사용자 입력 정규식 규칙, RE2 권고 |
| I10 | Microsoft — Performance antipatterns for cloud apps | 10개 카탈로그(Busy DB, Chatty I/O, Extraneous Fetching, Improper Instantiation, No Caching, Retry Storm, Synchronous I/O …) — **범주 체계로 바로 사용 가능**. Chatty I/O 예제: SELECT 45회 → 1회로 410 → 3,970 req/min |
| I11 | Uber — Saved 70K Cores (2021) | GC 가 CPU 최대 소비자, 할당 줄이기, `ReadMemStats` 폴링의 STW 비용 |
| I12 | Discord — Go → Rust (2020) | GC 언어의 큰 상주 캐시 = 꼬리 지연 위험 신호 |
| I13 | Datadog — Go 1.24 memory regression (2025) | 런타임 힙은 그대로, RSS +20%. → 런타임 · 의존성 업그레이드 PR 도 성능 리뷰 대상 |

### 1.2 네트워크 · 재시도 · 캐싱 · 과부하

| # | 조직 · 제목 | 규칙 |
|---|---|---|
| I14 | Amazon Builders' Library — Timeouts, retries, and backoff with jitter | 모든 원격 호출에 연결 · 요청 타임아웃(p99.9 기준), 재시도는 **한 층에서만**(5층×3회 = 243배), 지터, 토큰 버킷, 멱등일 때만 재시도 |
| I15 | Amazon — Caching challenges and strategies | 요청 합치기(thundering herd), 부정 캐시, soft/hard TTL, 기본 TTL 금지, 캐시 끈 상태 부하 테스트 |
| I16 | Amazon — Avoiding fallback **[부분]** | 새 폴백 경로 → 테스트 요구 |
| I17 | Amazon — Using load shedding **[부분]** | |
| I18 | Google SRE — Addressing Cascading Failures | 재시도 예산, 데드라인 전파, 큐 ≤ 풀의 50%, 503 부하 덜기 |
| I19 | Stripe — Scaling your API with rate limiters | 리미터 4종, fail open, 다크 런치 |
| I20 | Stripe — Idempotency | 변경 요청에 `Idempotency-Key` |
| I21 | Google AIP-158 Pagination | 컬렉션 API 는 **처음부터** 페이지네이션, `page_size` 상한 강제 |

### 1.3 DB 쿼리 · ORM

| # | 조직 · 제목 | 규칙 |
|---|---|---|
| I22 | GitLab — Database review guidelines | 원시 SQL 마다 `EXPLAIN ANALYZE` 첨부, 변경 전후 계획, 쿼리 ≤ 100ms, 마이그레이션 트랜잭션 ≤ 15s, 최대 limit + 0 아닌 offset 으로 테스트 |
| I23 | GitLab — Query performance guidelines | 콜드/웜 캐시 구분, 필터 조합마다 인덱스 만들지 말 것 |
| I24 | GitLab — MR performance guidelines (**가장 체크리스트에 가까움**) | 루프 안 SQL 금지, **쿼리 수가 컬렉션 크기에 비례하면 안 됨**, 목록은 전부 페이지네이션, 전체 COUNT 회피, keyset, 100k 행 테스트, HTTP 타임아웃, **트랜잭션 안 외부 호출 금지**, 큰 문서는 스트림 파싱 |
| I25 | GitLab — Query count limits | 요청 · 워커당 SQL 100개 한도, 테스트에서 넘으면 예외 |
| I26 | GitLab — Migration style guide | 짧은 `lock_timeout` + 재시도, 트랜잭션당 락 하나, 락 순서 고정, 대량 갱신은 배치 |
| I27 | Rails — Strict Loading | `strict_loading_by_default`, `find_each`(배치 1,000) |
| I28 | Bullet gem | N+1 + **안 쓰는 eager load** + counter cache 누락 |
| I29 | Prosopite gem | 같은 스택에서 같은 쿼리 지문 2회 이상 = N+1. → "루프 안 ID 단건 조회" 휴리스틱 |
| I30 | Shopify — GraphQL N+1 batching | 리졸버 안 직접 DB 조회 = N+1 후보, DataLoader |
| I31 | Django — Database access optimization | `select_related`/`prefetch_related`, `count()`/`exists()`, `iterator()`, `values()`, `bulk_*`, `fk_id` — **체크리스트로 거의 그대로** |
| I32 | Hibernate 6 Introduction | "N+1 selects 가 Java 데이터 접근 성능 문제의 가장 흔한 원인". `@ManyToOne` EAGER 기본값은 결함, 배치 fetch 는 완화일 뿐 |
| I33 | Use The Index, Luke — No Offset | OFFSET 대신 keyset |

### 1.4 기준 숫자

| # | 출처 | 숫자 |
|---|---|---|
| I34 | Latency Numbers Every Programmer Should Know | 메모리 100ns, SSD 랜덤 150µs, DC 왕복 500µs, 대륙간 150ms → 루프 안 왕복 1회 ≈ 메모리 접근 5,000회. (I7 표는 DC 왕복 50µs — 인용 시 출처 명시) |
| I35 | The Tail at Scale (CACM 2013) | p99 1s 서버 100대 팬아웃 → 요청 63% 가 1s 초과. hedge 는 p95 대기 후 추가 부하 ~5% |
| I36 | Marissa Mayer @ Web 2.0 (2006) | 0.5s 지연 → 트래픽 · 매출 −20%. **"Amazon 100ms = 매출 1%" 는 1차 출처 미확인 — 인용 금지** |
| I41 | web.dev — Web Vitals | LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 (p75) |
| I42 | web.dev — Performance budgets 101 | 핵심 경로 압축 후 170KB, Lighthouse ≥ 80 |

### 1.5 지속적 프로파일링

- Google-Wide Profiling (IEEE Micro 2010)
- Parca · Grafana Pyroscope
- → 정적 리뷰 결과를 프로파일로 검증하라는 권고의 근거로만 쓴다.

### 1.6 찾지 못한 것

GitHub 블로그의 N+1 · 쿼리 리뷰 1차 글, LinkedIn 회귀 탐지 1차 글, Notion/Figma DB 리뷰 가이드, Shopify 사내 N+1 도구 1차 글. 공개 DB 리뷰 규정으로는 **GitLab 이 사실상 유일하게 구체적**이다. Pinterest 성능 수치(I43)와 Think with Google 이탈률(I37)은 출처마다 달라 인용하지 않는다.

---

## 2. 학술 레퍼런스

### 2.1 성능 버그 실증 연구

| # | 인용 | 핵심 발견 → 시사점 |
|---|---|---|
| A1 | Jin, Song, Shi, Scherpelz, Lu. *Understanding and Detecting Real-World Performance Bugs*. PLDI 2012 [DOI 미대조] | 버그 109개, 패치 25개에서 "효율 규칙" 추출 → 새 문제 332개 발견(219개는 규칙을 **다른 앱에 이식**해서). → 규칙 카탈로그는 언어 · 프로젝트를 넘어 재사용된다 |
| A2 | Nistor et al. *Toddler*. ICSE 2013 | 반복마다 비슷한 메모리 접근을 하는 루프 = 성능 버그. 새 버그 42개 |
| A3 | Nistor et al. *CARAMEL*. ICSE 2015 (Distinguished) | 조건이 참이 되면 나머지 반복이 낭비되는 루프 → 조기 종료. 새 버그 150개 |
| A4 | Selakovic, Pradel. *Performance Issues and Optimizations in JavaScript*. ICSE 2016 | 1위 원인 **비효율 API 사용**. 엔진 바꿔도 일관된 최적화는 42.68% 뿐 → 마이크로 최적화는 낮은 심각도 |
| A5 | Zaman, Adams, Hassan. *A Qualitative Study on Performance Bugs*. MSR 2012 | 성능 버그 리포트는 재현성이 낮다 |
| A6 | Nistor, Jiang, Tan. *Discovering, Reporting, and Fixing Performance Bugs*. MSR 2013 | 상당수가 **코드 추론**으로 발견 → 리뷰로 잡을 여지가 크다 |
| A7 | Song, Lu. *Statistical Debugging for Real-World Performance Problems*. OOPSLA 2014 | 좋은 입력 vs 나쁜 입력 비교 |
| A8 | Han, Yu. *Performance Bugs for Highly Configurable Software*. ESEM 2016 | 설정 조합에서만 드러남 → "측정 필요" |
| A9 | Zhao et al. *Large-Scale Empirical Study of Real-Life Performance Issues*. TSE 2022 | 570건, ~27% 는 여러 파일에 걸친 설계 수준 수정, 성능 테스트 추가는 ~15% 뿐 → 성능 수정 PR 에 측정 근거 요구 |
| A10 | Yang et al. *Performance Bugs in Data Science Libraries*. FSE 2025 | 절반 이상이 비효율 데이터 처리(자료구조) |

### 2.2 ORM · DB 기반 앱

| # | 인용 | 핵심 |
|---|---|---|
| A11 | T.-H. Chen et al. *Detecting Performance Anti-patterns for ORM Applications*. ICSE 2014 [DOI 미대조] | 루프 안 one-by-one 처리(N+1) 정적 탐지 + 영향 순위 |
| A12 | T.-H. Chen et al. *Redundant Data Access in ORM*. TSE 2016 | 트랜잭션 **87%** 에 불필요한 조회, 고치면 응답 ~17% 개선 |
| A13 | C. Yan et al. *Database Performance Inefficiencies in Real-world Web Apps*. CIKM 2017 | Rails 27개 정적 분석 |
| A14 | J. Yang et al. *How not to Structure Your Database-Backed Web Applications*. ICSE 2018 [DOI 미대조] | 느린 액션 40 중 34 가 확장성 문제, 중앙값 2배 · 최대 39배, **78% 이상이 5줄 미만 수정**, 가장 흔한 신고 = 인덱스 누락 [부분] |
| A15 | J. Yang et al. *PowerStation*. FSE 2018 Demo | IDE 정적 분석으로 1,221개 이슈 → 규칙 기반이 이미 재현율 높음 |
| A16 | J. Yang et al. *View-Centric Performance Optimization* (Panorama). ICSE 2019 | 화면 요소별 DB 비용, 페이지네이션 · 비동기 로딩 제안 |

### 2.3 알고리즘 복잡도 · 최악 입력

| # | 인용 | 핵심 |
|---|---|---|
| A17 | Burnim, Juvekar, Sen. *WISE*. ICSE 2009 | 기호 실행으로 최악 입력 생성기 |
| A18 | Petsios et al. *SlowFuzz*. CCS 2017 | 자원 사용량 유도 퍼징 |
| A19 | Lemieux et al. *PerfFuzz*. ISSTA 2018 | 점근적 성능 버그를 D3 · Express 등에서 발견 |
| A20 | Davis et al. *ReDoS in Practice*. FSE 2018 | npm · PyPI 초선형 정규식 수천 개, 안티패턴 규칙은 **위양성 많음** → 사용자 입력 경로일 때만 심각도 상향 |
| A21 | Çiçek et al. *Static Resource Analysis at Scale*. SAS 2020 + Infer Cost | **diff 에서 복잡도 증가만 보고** — 오탐 줄이는 핵심 설계 |

※ "Accidentally Quadratic" 은 블로그 사례 모음(학술 아님) — 예시 소스로만.

### 2.4 메모리 · 캐싱 · 동시성

| # | 인용 | 핵심 |
|---|---|---|
| A22 | Nguyen, Xu. *Cachetor*. FSE 2013 | 같은 값 반복 생성 = 캐시 후보 → 캐시 제안은 "같은 입력 반복 계산" 근거 + 무효화 조건 필수 |
| A23 | Xu, Mitchell, Arnold et al. *Software Bloat Analysis*. FoSER 2010 | 임시 객체 · 저효용 자료구조 |
| A24 | Alam et al. *SyncPerf*. EuroSys 2017 | 경합 없이도 **빈번한 락 획득 · 넓은 임계구역**이 문제, 수정 시 2.5–42% 개선 |
| A25 | Drepper. *What Every Programmer Should Know About Memory* (2007) | 캐시 계층 · 지역성 |

### 2.5 꼬리 지연 · 시스템 법칙

| # | 인용 | 리뷰 적용 |
|---|---|---|
| A26 | Dean, Barroso. *The Tail at Scale*. CACM 2013 | 팬아웃 코드 → 타임아웃 · hedge · 부분 결과 |
| A27 | Little. *L = λW*. Operations Research 1961 | 풀 크기 변경 근거 |
| A28 | Gunther. USL (CMG 1993) | 일관성 비용 β>0 이면 확장할수록 처리량 감소 |
| A29 | Patterson. *Latency Lags Bandwith*. CACM 2004 | 대역폭 120–2200배 vs 지연 4–20배 → **왕복 횟수**가 기준 |

### 2.6 CI 성능 회귀 · 마이크로벤치마크

| # | 인용 | 핵심 |
|---|---|---|
| A30 | Leitner, Bezemer. ICPE 2017 | OSS Java 111개 — 성능 테스트는 소수 · 방치 |
| A31 | Laaber, Leitner. MSR 2018 | 일부 벤치마크 변동 50% 이상 |
| A32 | Laaber et al. *Microbenchmarking in the Cloud*. EMSE 2019 | 같은 인스턴스 · 무작위 순서 반복 + Wilcoxon/부트스트랩이면 ≤10% 회귀 탐지 → 벤치마크 근거 검증 항목 |
| A33 | Daly et al. (MongoDB) ICPE 2020 | E-Divisive |
| A34 | Fleming et al. *Hunter* (DataStax) ICPE 2023 | |
| A35 | Meta *FBDetect* SOSP 2024 | |
| A36 | Besbes et al. Mozilla CPD. arXiv 2606.18377 (2026 프리프린트) | Perfherder 알림 12.5% 오탐, 6.8% 누락 → 성숙 시스템도 신뢰도 표시 필요 |

### 2.7 LLM 과 성능 최적화 · 리뷰

| # | 인용 | 핵심 |
|---|---|---|
| A37 | Shypula et al. *PIE*. ICLR 2024 | gem5 로 잡음 제거, 최선 6.86배 |
| A38 | Huang et al. *EffiBench*. NeurIPS 2024 | GPT-4 코드 실행 시간 = 정답의 3.12배 |
| A39 | Waghjale et al. *ECCO*. EMNLP 2024 | 효율 개선 시도가 **기능 정확성을 깎는다** |
| A40 | Du et al. *Mercury*. NeurIPS 2024 | Pass 65% vs Beyond <50% |
| A41 | Qiu et al. *ENAMEL*. ICLR 2025 | 모든 모델이 전문가 미만 — 알고리즘 설계 · 최적화 인식 부족 |
| A42 | He et al. *SWE-Perf*. arXiv 2507.12415 | 실제 저장소: 전문가 10.85% vs 최고 에이전트 2.26% → 플러그인 강점은 **최적화가 아니라 탐지** |
| A43 | Garg et al. *DeepPERF* (Microsoft) | C# 수정 53% 일치, PR 19 중 11 승인 |
| A44 | Garg et al. *RAPGen*. ICSE-SEIP 2025 | 과거 수정 지식베이스 검색 → 60% 가 개발자 이상. → **"패턴 → 수정 예시" 카탈로그** 설계 근거 |
| A45 | Imran et al. *LLMs for Performance Bug Detection*. SANER 2026 RENE | 오픈 LLM 의 Java 성능 버그 탐지 F1 낮음, 퓨샷 효과 미미 |
| A46 | *SWR-Bench*. arXiv 2509.01494 | LLM 리뷰 오탐 48% = 맥락 이해 부족 → **주변 코드 · 호출자 읽기 강제** |
| A47 | Opu et al. *Agentic AI performance PRs*. arXiv 2512.24630 | 최적화 유형별 수용률 차이 |

---

## 3. 방법론 · 표준 · 도구

### 3.1 방법론

| 이름 | 쓸 점 |
|---|---|
| USE Method (Gregg) | 새 자원(풀 · 큐 · 커넥션 · FD)마다 사용률 · 포화 · 오류 |
| Gregg 안티 메서드 | Streetlight · Random Change · Passive Benchmarking → "근거 없는 최적화" 지적 |
| RED Method | 새 엔드포인트의 Rate · Errors · Duration 계측 |
| Google SRE Golden Signals | 성공/실패 지연 분리, 평균 말고 히스토그램 |
| Amdahl · Roofline | 핫패스 아닌 곳 최적화는 낮은 우선순위 |

### 3.2 표준 — **규칙 ID 체계로 가장 바로 쓸 수 있는 부분**

- **ISO/IEC 25010 Performance efficiency** — Time behaviour · Resource utilization · Capacity. 결과 분류 축.
- **ISO/IEC 5055 (CISQ) → CWE-1309 "Efficiency" 15개**

| CWE | 리뷰 규칙 |
|---|---|
| 404 · 1091 | 커넥션 · 스트림 · 응답 바디 해제 |
| 1042 · 1043 | static 가변 컬렉션 누적, 거대 집계 객체 |
| 1046 | 루프 안 문자열 연결 |
| 1049 | 대형 테이블 과다 조회 · 조인 |
| **1050** | **루프 안 DB · IO · 네트워크 호출** |
| 1057 · 1073 | 레포지토리 밖 데이터 접근, 한 함수의 과다 DB 접근 |
| **1060** | **서버 측 데이터 접근 과다 (N+1)** |
| 1067 · 1094 | 인덱스 못 타는 순차 탐색, 과도한 범위 스캔 |
| 1072 | 커넥션 풀 미사용 |
| 1089 | 인덱스 과다 (쓰기 비용) |
| 424 | (간접) |

- **자원 고갈 (보안 × 성능)**
  - CWE-400 계열: 405(증폭), **770(한도 없는 할당)**, 779(과도한 로깅), 1235(핫패스 오토박싱)
  - **CWE-1333 ReDoS**
  - **OWASP API4:2023 Unrestricted Resource Consumption** — 타임아웃, 업로드 크기, **페이지당 레코드 상한**, 배열 길이 상한, GraphQL 배칭

### 3.3 DB 공통

| 이름 | 규칙 |
|---|---|
| Use The Index, Luke | keyset |
| SQL Antipatterns (Karwin) | Index Shotgun, Implicit Columns(`SELECT *`), Poor Man's Search(`LIKE '%x%'`), `ORDER BY RAND()`, Spaghetti Query |
| PostgreSQL EXPLAIN | Seq Scan 적정성, 추정 vs 실제 rows, `loops`, `Rows Removed by Filter`, `external merge`, Hash `Batches>1` |
| pg_stat_statements | `total_exec_time` · `mean_exec_time` · `rows/calls` · 캐시 적중 |

### 3.4 언어별 정적 분석 규칙 (애드온의 매핑 원천)

**Java / Spring**
- SpotBugs PERFORMANCE (38개) — 핵심: `SBSC_USE_STRINGBUFFER_CONCATENATION`, `IIL_PREPARE_STATEMENT_IN_LOOP`, `IIL_PATTERN_COMPILE_IN_LOOP`, `WMI_WRONG_MAP_ITERATOR`, `DMI_BLOCKING_METHODS_ON_URL`, `DMI_COLLECTION_OF_URLS`, `DM_BOXED_PRIMITIVE_*`
- PMD performance (25개) — `AvoidInstantiatingObjectsInLoops`, `UseStringBufferForStringAppends`, `UseIOStreamsWithApacheCommonsFileItem`
- Error Prone — `ErroneousThreadPoolConstructorChecker`, `ConstantPatternCompile`, `UnnecessaryCopy`, `@NoAllocation`
- SonarQube `performance` 태그 — **접근 실패, 규칙 ID 미확인**
- N+1 · 쿼리 수 assert: hypersistence-utils `SQLStatementCountValidator` (), datasource-proxy `QueryCountHolder` (), QuickPerf `@ExpectMaxSelect` · `@DisableSameSelectTypesWithDifferentParamValues` · `@ExpectJdbcBatching` · `@ExpectMaxSelectedColumn` ( 유지보수 상태 미확인), spring-hibernate-query-utils (**unmaintained**)
- Spring Boot `spring.jpa.open-in-view` 기본 true

**Kotlin** — detekt performance (8개) — `SpreadOperator`, `CouldBeSequence`, `ForEachOnRange`, `ArrayPrimitive`. JVM 도구는 Java 와 공유.

**Python / Django / FastAPI**
- Ruff — `PERF101~403`(특히 `PERF203` 루프 안 try), `B019`(cached 인스턴스 메서드 누수), **`ASYNC210/212/220~222/230/240/250/251`(async 안 블로킹 — FastAPI 핵심)**
- Pylint — `R1713`(join), `R1728/R1729`(제너레이터), `C0206`, `R6201`, `W1518`
- Semgrep django/performance
- Django `assertNumQueries` (), nplusone (), django-zeal (), SQLAlchemy `raiseload('*')` ()

**Node / NestJS / Express / 프런트**
- ESLint `no-await-in-loop`; Biome performance — **`noAccumulatingSpread`**(reduce+spread O(n²)), `noAwaitInLoops`, `noBarrelFile`, `useTopLevelRegex`
- Oxlint perf — `no-map-spread`, `unicorn/prefer-set-has`
- eslint-plugin-react-perf
- CodeQL JS Performance (`ReDoS`, `PolynomialReDoS`)
- Express 운영 성능 — 동기 API 금지(`--trace-sync-io`), CPU 작업은 worker threads
- Prisma 쿼리 이벤트 ; TypeORM `maxQueryExecutionTime`
- NestJS 공식 성능 가이드 — **확인 못 함**

**Go**
- staticcheck SA6 — `SA6000`(루프 안 regexp), `SA6002`(sync.Pool 비포인터), `SA6005`
- go-critic performance (13개) — `hugeParam`, `rangeValCopy`, `appendCombine`
- perfsprint (`concat-loop`) ; prealloc
- golangci-lint — **`bodyclose`, `sqlclosecheck`, `rowserrcheck`, `noctx`**

### 3.5 같은 개념 → 언어별 규칙 매핑 예시

| 개념 (CWE) | Java | Go | Python | JS/TS |
|---|---|---|---|---|
| 루프 안 문자열 연결 (1046) | SpotBugs `SBSC_…`, PMD `UseStringBufferForStringAppends` | perfsprint `concat-loop` | Pylint `R1713` | Biome `noAccumulatingSpread` (유사) |
| 루프 안 regex 컴파일 | SpotBugs `IIL_PATTERN_COMPILE_IN_LOOP`, Error Prone `ConstantPatternCompile` | staticcheck `SA6000` | — | Biome `useTopLevelRegex` |
| 루프 안 원격 호출 (1050) | SpotBugs `IIL_PREPARE_STATEMENT_IN_LOOP` | — | — | ESLint `no-await-in-loop` |
| async 안 블로킹 | — | — | Ruff `ASYNC2xx` | Express `--trace-sync-io` |
| 자원 미해제 (404/772) | — | `bodyclose`, `sqlclosecheck` | Pylint `R1732` | — |
| 값 복사 | — | go-critic `hugeParam` · `rangeValCopy` | — | — |

### 3.6 측정 · CI 게이트 도구

| 목적 | 도구 |
|---|---|
| 쿼리 수 assert | Django `assertNumQueries`, django-zeal, nplusone, SQLAlchemy `raiseload`, QuickPerf, hypersistence, datasource-proxy, Prisma `$on('query')`, Rails Bullet/Prosopite/strict_loading, GitLab query limit 패턴 |
| 할당 assert | Go `testing.AllocsPerRun`, QuickPerf `@MeasureHeapAllocation`, Error Prone `@NoAllocation` |
| 복잡도 실측 | Python big_O, 그 외 언어는 "N 을 2배로 → 시간 비율" 직접 작성 |
| 마이크로벤치 | JMH, pytest-benchmark `--benchmark-compare-fail=mean:5%`, Go `b.Loop()` + benchstat (Mann-Whitney U) |
| 프로파일러 | async-profiler, py-spy, pprof, 0x, clinic.js(**미유지**), flame graph(Differential) |
| 회귀 게이트 | github-action-benchmark, Bencher, CodSpeed |

### 3.7 확인 못 한 것

SonarQube 규칙 ID, CISQ 하위 변형 세 번째 CWE, Hibernate 설정 본문, TypeORM 옵션 상세, NestJS 성능 가이드, CodeQL Python 성능 쿼리, QuickPerf · nplusone 유지보수 상태.
