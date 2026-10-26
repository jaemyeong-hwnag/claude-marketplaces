# reference-search 테스트

`scripts/reference-validate.sh` 와 `scripts/reference-search.sh` 의 회귀 테스트다. 스크립트 · 규칙을 고치면 여기부터 돌린다.

## 실행

```bash
test/reference-validate.test.sh          # 전체
test/reference-validate.test.sh TC-V1    # ID 접두사로 필터
test/reference-search.test.sh
```

종료 코드 0 이면 전체 통과다. 네트워크를 쓰지 않는다 — `PATH` 앞에 `curl` · `gh` 스텁을 두고 테스트 안의 픽스처 응답을 돌려준다. bash · jq · xmllint 를 쓴다.

## reference-validate.test.sh (34건)

### A. 훅 차단 (RS-01 · RS-02)

| ID | 케이스 |
|---|---|
| TC-V01 | 등록된 DOI 를 Write → 통과, 출력 없음 |
| TC-V02 | 없는 DOI 를 Write → deny, 메시지에 그 DOI (RS-01) |
| TC-V03 | 없는 arXiv ID 를 Edit 의 new_string 에 → deny (RS-02) |
| TC-V04 | old_string 에 이미 있던 식별자는 새로 생긴 것이 아니다 → 조회 안 함 |
| TC-V05 | 파일에 이미 있던 식별자를 Write 로 다시 쓰면 조회 안 함, 새 것만 조회 |
| TC-V06 | 없는 것과 있는 것이 섞이면 없는 것만 메시지에 |
| TC-V07 | MultiEdit 의 new_string 들을 모두 본다 |

### B. 알림 · 통과 (RS-03 · RS-04)

| ID | 케이스 |
|---|---|
| TC-V10 | 철회된 DOI → 통과 + additionalContext (RS-03) |
| TC-V11 | 조회 시간 초과 → 통과 + 확인 못 함 알림 (RS-04) |
| TC-V12 | arXiv 429 → arXiv DOI 로 다시 확인해 있으면 통과 |
| TC-V14 | arXiv 429 · arXiv DOI 도 없음 → deny (RS-02) |
| TC-V15 | arXiv 429 · arXiv DOI 도 시간 초과 → 차단하지 않고 확인 못 함 (RS-04) |
| TC-V13 | 상한을 넘은 식별자는 조회하지 않고 확인 못 함으로 알린다 |

### C. 검사 대상

| ID | 케이스 |
|---|---|
| TC-V20 | .md 가 아닌 파일은 검사 안 함 |
| TC-V21 | REFERENCE_VALIDATE=off 면 검사 안 함 |
| TC-V22 | 식별자 없음 → 조회 0회 |
| TC-V23 | Read 같은 다른 도구 → 검사 안 함 |

### D. 식별자 추출

| ID | 케이스 |
|---|---|
| TC-V30 | 문장부호 · 마크다운 링크 꼬리를 떼고, 괄호가 든 DOI 는 살린다 |
| TC-V31 | arXiv 새 형식 · 버전 · 옛 형식 · URL 형식을 뽑는다 |
| TC-V32 | arXiv 접두사 없는 숫자(2023.12345)는 arXiv ID 로 보지 않는다 |
| TC-V33 | 한국어 조사 · 전각 문장부호가 붙은 DOI 는 조사 앞에서 끊는다 |
| TC-V34 | 출판사 URL 꼬리(bioRxiv v1 · .pdf · /abstract · 쿼리 · 끝 슬래시)를 뗀다 |
| TC-V35 | <> 가 든 SICI DOI 는 살리고 인코딩해 조회한다, 자동 링크 꺾쇠는 뗀다 |
| TC-V36 | 주제 분류가 붙은 옛 arXiv ID(math.DG/0211159)는 math/0211159 로 조회한다 |
| TC-V37 | 인라인 코드 · 코드 펜스 안의 예시 식별자는 보지 않는다 |

### E. 파일 모드 (/reference-validate)

| ID | 케이스 |
|---|---|
| TC-V40 | 없는 DOI → 종료 1, ❌ RS-01 |
| TC-V41 | 모두 있으면 종료 0 |
| TC-V42 | --urls: 404 는 실패, 403 은 경고 (RS-05 · RS-06) |
| TC-V45 | --urls: 괄호가 든 URL 은 살리고 문장 끝 괄호만 뗀다 |
| TC-V43 | --urls 없이는 URL 을 조회하지 않는다 |
| TC-V44 | 없는 파일 → 종료 1 |

### F. 캐시

| ID | 케이스 |
|---|---|
| TC-V50 | 한 번 있다고 확인한 DOI 는 다시 조회하지 않고, 철회 여부도 캐시에서 낸다 |
| TC-V51 | 없다고 나온 DOI 는 캐시하지 않는다 |
| TC-V52 | 남이 만든 캐시 디렉터리는 읽지도 쓰지도 않는다 |

## reference-search.test.sh (27건)

### A. 출처별 정규화

| ID | 케이스 |
|---|---|
| TC-S01 | openalex — 칸 정규화, DOI 접두 URL 제거, arXiv 위치에서 ID |
| TC-S02 | semantic-scholar — externalIds 에서 DOI · arXiv, 기간 필터 |
| TC-S03 | crossref — 날짜 0 채움, 저자 이름 합치기 |
| TC-S04 | arxiv — Atom 파싱, 단어마다 all: AND, 기간은 submittedDate |
| TC-S05 | pubmed — esearch 뒤 esummary, 철회 표시 |
| TC-S06 | pubmed — 결과 0건이면 esummary 를 부르지 않는다 |
| TC-S07 | biorxiv — Europe PMC 프리프린트 필터, kind preprint |
| TC-S08 | openreview — content.*.value, forum URL |
| TC-S09 | huggingface — 검색 결과 상한을 스크립트가 자른다 |
| TC-S10 | huggingface-daily — 검색어 없이 동작 |
| TC-S11 | hackernews — 날짜 정렬은 search_by_date, 기간은 created_at_i |
| TC-S12 | rfc — RFC DOI 와 rfc-editor URL |
| TC-S13 | github-repository — gh 결과 정규화 |
| TC-S14 | openalex-citing — DOI 로 작품 ID 를 찾고 cites 필터 |
| TC-S15 | openalex-references — 참고문헌이 없으면 0건으로 끝난다 |

### B. 실패와 사용법

| ID | 케이스 |
|---|---|
| TC-S20 | 429 가 두 번이면 종료 6 과 대체 출처 안내 |
| TC-S21 | 429 뒤 성공하면 결과를 낸다 — 재시도 |
| TC-S22 | 응답 없음 → 종료 5 |
| TC-S23 | HTTP 500 → 종료 5 |
| TC-S24 | 키가 필요한 출처 → 종료 3, 조회하지 않음 |
| TC-S25 | 모르는 출처 → 종료 2 |
| TC-S26 | 검색어가 없으면 종료 2 |
| TC-S27 | --limit · --from 형식 오류 → 종료 2 |
| TC-S28 | gh 가 없으면 github-* 만 종료 4 |
| TC-S29 | 값 없는 마지막 옵션 → 바로 종료 2 (무한 루프 없음) |
| TC-S30 | arxiv — 불용어를 빼고 질의한다 |
| TC-S31 | huggingface · openreview — --from 이전 결과를 거른다 |

## 자동화하지 않은 것

- 실제 API 응답 형식이 바뀌는 것 — 픽스처는 2026-10 에 실제 응답을 보고 만들었다. 출처가 형식을 바꾸면 테스트는 통과하고 실제 호출은 빈 결과를 낸다. 수동으로 `scripts/reference-search.sh <출처> <검색어> --limit 1` 을 돌려 본다
- 스킬의 에이전트 선택 · 병합 · 검증 절차 — eval(`evals/`)로 본다. `eval-all.sh` 는 `Bash` 를 `git` 에만 허용하고 `WebFetch` 를 주지 않아 에이전트가 스크립트 · 원문을 쓰지 못한다. 그래서 케이스는 스킬 발동 · 에이전트 분담만 채점한다. 결과에 실제 식별자가 나오는지는 도구를 허용해 직접 돌린다 (2026-10-26 1회, 식별자 포함 통과)

```bash
claude plugin eval evals/paper-search-trigger/prompt.md --no-publish --trust-plugin --runs 1 --ablation none \
  --allow-tools 'Bash(*reference-search.sh*)' 'Bash(*reference-validate.sh*)' WebFetch
```
