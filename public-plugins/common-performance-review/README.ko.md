# common-performance-review

[English](README.md) · **한국어** · [简体中文](README.zh-CN.md)

코드 변경의 성능을 빠짐없이 리뷰한다 — 언어 무관. 시간 · 공간 복잡도 · DB 쿼리(N+1 · 인덱스 · 페이지네이션) · 네트워크 · IO · 동시성 · 캐싱 · 페이로드 · 자원 해제 · 정규식 9개 범주 필수 판정, 루프 안 쿼리 · await · 무한 조회 등 19개 패턴 탐지와 작성 시 알림, 측정 방법 제시.

이 플러그인은 **코드를 읽고** 성능 위험을 찾는다. 결정적 패턴 검사가 후보를 내고, 스킬이 호출 맥락과 데이터 규모를 읽어 판정한다. 실행 중인 시스템에 부하를 걸어 재는 일은 `common-stress-test` 가 맡는다 — 리뷰에서 `측정필요` 로 남긴 것을 그쪽으로 넘긴다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-performance-review@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| performance-review | 성능 봐줘 · 느려질까 · N+1 · 복잡도 · 쿼리 많이 나가나 · 메모리 | 패턴 검사 → 9개 범주 필수 판정 → 규모 가정 · 신뢰도 · 검증 방법이 붙은 지적 |
| /performance-validate | 직접 호출 | 바뀐 줄(기본) 또는 지정한 경로에서 `PF-01` ~ `PF-20` 패턴을 찾는다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| performance-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | 이번에 쓴 줄에서 나온 패턴을 **알린다** (`PF-01` ~ `PF-20`). 막지 않는다 |

## 주의

- 패턴은 **후보**다. 컬렉션이 이미 Set 인지, 반복 수가 상수인지, 이미 배치인지는 맥락을 읽어야 안다 — 판정은 스킬이 한다
- 루프는 줄 단위로 추정한다 (중괄호 · Python 들여쓰기). 다른 함수를 거쳐 루프 안에서 일어나는 호출이나 지연 로딩 연관 접근(`order.getCustomer()`)은 패턴이 못 본다 — 스킬의 범주 판정이 맡는다
- 보는 파일: `.py` · `.java` · `.kt` · `.kts` · `.scala` · `.go` · `.js` · `.jsx` · `.mjs` · `.cjs` · `.ts` · `.tsx` · `.cs` · `.php` · `.swift` · `.rs` · `.sql`
- 테스트 경로는 보지 않는다. 보려면 `--include-tests`
- 의도한 줄이면 그 줄 끝이나 바로 윗줄에 `performance-ignore` 주석을 둔다
- 숫자(100 ms · 쿼리 100개 등)는 출처의 예시다. 기준은 서비스가 정한다
- 스크립트는 bash · awk · jq 만 쓴다

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `PF-01` ~ `PF-08` | 루프 안 DB 호출 · 원격 호출 · 순차 await · 정규식 컴파일 · 선형 탐색 · 문자열 누적 · 컬렉션 복사 · 무거운 객체 생성 | 경고 |
| `PF-10` ~ `PF-14` | `SELECT *` · OFFSET 페이지네이션 · 상한 없는 조회 · 앞 `%` LIKE · `ORDER BY RAND()` | 경고 |
| `PF-15` ~ `PF-20` | 비동기 안 블로킹 · 타임아웃 없는 HTTP · ReDoS 의심 정규식 · EAGER 연관 · 상한 없는 캐시 · 개수에 전체 로딩 | 경고 |
| `PF-30` ~ `PF-38` | 9개 범주 — 시간 · 공간 · 쿼리 · 네트워크 · 동시성 · 캐싱 · 페이로드 · 자원 해제 · 정규식 — 모두 판정 | AI 판단 |
| `PF-40` ~ `PF-47` | 지적 형식 · 규모 가정 필수 · 심각도와 신뢰도 분리 · 변경 전후 비교 · 맥락 확인 · 마이크로 최적화는 낮음 · 기능 동등성 · 캐시 무효화 | AI 판단 |

원본: [`references/performance-rules.md`](references/performance-rules.md) · 근거: [`references/performance-methods.md`](references/performance-methods.md)

## 사용

```bash
scripts/performance-validate.sh --diff                # 기본 브랜치 대비 바뀐 줄
scripts/performance-validate.sh --diff HEAD~3         # 기준 지정
scripts/performance-validate.sh src/                  # 경로 전체
scripts/performance-validate.sh --strict src/         # 경고가 있으면 exit 2 (CI)
test/performance-validate.test.sh                     # 회귀 테스트
```

## 근거

ISO/IEC 25010:2023 · ISO/IEC 5055 (CWE-1309) · CWE-400 · CWE-1333 · OWASP API4:2023 · Jin et al. PLDI 2012 · Chen et al. ICSE 2014 · Yang et al. ICSE 2018 · Davis et al. FSE 2018 · Infer Cost · Dean & Barroso CACM 2013 · GitLab 데이터베이스 · MR 성능 가이드 · Amazon Builders' Library · Azure 성능 안티패턴 · SWE-Perf · SWR-Bench. 각 항목의 출처 · 확인 수준은 `references/performance-methods.md` 에 있다.

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
