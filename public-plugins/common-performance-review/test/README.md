# common-performance-review 테스트

`scripts/performance-validate.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/performance-validate.test.sh          # 전체
test/performance-validate.test.sh TC-P2    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. bash · awk · jq · git 만 쓴다.

## 자동 TC (37건)

잡아야 하는 것과 잡으면 안 되는 것을 조항마다 같이 둔다.

### A. 루프 안 패턴 (`PF-01` ~ `PF-08`)

| ID | 케이스 |
|---|---|
| TC-P01 | 루프 본문의 리포지토리 호출은 잡고, 루프 헤더의 호출은 잡지 않는다 |
| TC-P02 | 루프 밖 DB 호출 · 주석 속 루프는 보지 않는다 |
| TC-P03 | 콜백 반복(forEach · map 람다) 안의 호출도 루프다 |
| TC-P04 | 중괄호 없는 한 줄 for 본문 · 다음 줄 본문, 그다음 줄은 루프 밖 |
| TC-P05 | 루프가 닫힌 뒤의 줄은 루프 밖이다 |
| TC-P06 | Python 들여쓰기 루프 · 컴프리헨션 · 한 줄 루프, 루프 헤더는 제외 |
| TC-P07 | Python 여러 줄 호출의 이어진 줄은 루프를 끝내지 않는다 |
| TC-P08 | Go range 루프의 db.QueryRow · http.Get |
| TC-P09 | for 안의 await 는 PF-03, Promise.all(map(async)) · for await 는 아니다 |
| TC-P10 | await 와 원격 호출이 한 줄이면 PF-02 만 |
| TC-P11 | 정규식 컴파일 · 선형 탐색(문자열 리터럴 인자는 제외) · 문자열 누적(숫자 += 는 제외) |
| TC-P12 | 배열 spread 누적 · reduce 의 ...acc, 루프 밖 spread · 원소 하나의 객체 spread 는 제외 |
| TC-P13 | 루프 안 무거운 객체 생성, 루프 밖은 제외 |
| TC-P14 | PF-03 은 루프마다 한 번, while · 재시도 루프 · sleep 은 제외 |
| TC-P15 | HTTP 세션 · 클라이언트의 get 은 PF-02 다 (DB 로 보지 않는다) |
| TC-P16 | 페이지 · 배치 단위로 읽는 루프의 조회는 PF-01 이 아니다 |

### B. 파일 수준 패턴 (`PF-10` ~ `PF-20`)

| ID | 케이스 |
|---|---|
| TC-P20 | SELECT * · OFFSET · 앞 % LIKE · ORDER BY RAND(), COUNT(*) · SQL 주석은 제외 |
| TC-P21 | 상한 없는 조회 · 개수에 전체 로딩, 슬라이스는 제외 |
| TC-P22 | Python async 안 블로킹, 안쪽 동기 함수 · 동기 함수는 제외 |
| TC-P23 | JS 동기 IO 는 비동기 코드가 있는 파일에서만 |
| TC-P24 | requests timeout — 다음 줄의 timeout 은 인정하고, 다른 호출의 timeout 은 인정하지 않는다 |
| TC-P25 | Go 기본 HTTP 클라이언트, Timeout 있으면 통과 |
| TC-P26 | 중첩 수량자 정규식은 잡고, 평범한 정규식 · 구분자로 시작하는 반복 그룹은 잡지 않는다 |
| TC-P27 | EAGER · LAZY 없는 @ManyToOne, LAZY 면 통과 (다음 애너테이션의 LAZY 는 인정하지 않는다) |
| TC-P28 | 상한 없는 캐시, maxsize 가 있으면 통과 |

### C. 억제 · 범위

| ID | 케이스 |
|---|---|
| TC-P40 | performance-ignore 는 그 줄과 다음 줄만 끈다 |
| TC-P41 | 디렉터리 검사는 node_modules · 테스트 경로 · 비대상 확장자를 건너뛴다, --include-tests 면 본다 |
| TC-P42 | --strict 는 경고가 있으면 exit 2, 없으면 0, 기본은 경고가 있어도 0 |
| TC-P43 | --diff 는 기준 이후 추가된 줄과 추적 안 된 새 파일만 본다 |
| TC-P44 | 모르는 옵션 · 없는 경로는 오류(1) |
| TC-P45 | git 작업 트리는 .gitignore 를 따른다 |
| TC-P46 | 테스트 경로는 저장소(아니면 대상 디렉터리) 기준이다 — 바깥 상위의 `test/` · `spec/` 는 무시하고 검사하며, 안쪽 `test/` · `tests/` · 최상위 `fixtures/` · `__tests__/` · `spec/` · `testdata/` 는 건너뛴다 |

### D. 훅

| ID | 케이스 |
|---|---|
| TC-P50 | PostToolUse Write — additionalContext 로 알린다 |
| TC-P51 | Edit — 이번에 쓴 줄에서 나온 것만 알린다 |
| TC-P52 | PreToolUse · 비대상 파일 · 테스트 파일 · 훅 이벤트 없는 입력은 조용하다 |
| TC-P53 | 훅은 경고를 10건으로 자른다 |
| TC-P54 | 훅의 테스트 판정도 저장소 기준이다 — 상위 경로에 `test/` 가 있어도 알리고, 저장소 안 `tests/` · 최상위 `fixtures/` · `__tests__/` · `spec/` · `testdata/` 는 조용하다 |

## eval

| 케이스 | 무엇을 보나 |
|---|---|
| `n-plus-one-review` | 스킬 이름 없이 성능을 봐 달라고 하면 `performance-review` 가 발동하고 N+1 을 짚는다 |
| `loop-query-hook` | 루프 안 DB 조회 코드를 저장하면 훅이 `PF-01` 로 알린다 |
