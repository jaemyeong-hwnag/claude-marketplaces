# preprint-searcher 출처 카탈로그

기준일 2026-10. 심사 전 원고를 올리는 프리프린트 서버에서 논문을 찾는다.

## 언제 쓰는가

- 띄운다: 아직 저널에 실리지 않은 연구, 특정 기간에 올라온 원고, arXiv ID · 프리프린트 DOI 확인, 워킹페이퍼(경제 · 경영 · 법).
- 띄운다: 게재본이 유료라 같은 내용의 무료 프리프린트를 찾을 때.
- 띄우지 않는다: 심사 완료 논문만 원하는 요청(`academic-index-searcher`), 화제성 · 인기 순위(`research-trend-searcher`).

## 출처

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| arXiv | `arxiv.org` | 물리 · 수학 · CS · 통계 · 계량생물 · 계량금융 · 전기전자 · 경제 | 무료 | `reference-search.sh arxiv` |
| bioRxiv | `biorxiv.org` | 생물학. 2025-03 부터 비영리 openRxiv 가 운영 | 무료 | `reference-search.sh biorxiv` |
| medRxiv | `medrxiv.org` | 임상 · 보건. openRxiv 운영 | 무료 | `reference-search.sh medrxiv` |
| SSRN | `ssrn.com` | 경제 · 경영 · 법 · 사회과학 워킹페이퍼. Elsevier 소유 | 무료 일부 (내려받기는 회원 가입) | WebSearch `site:papers.ssrn.com 검색어` |
| NBER | `nber.org` | 미국 경제학 워킹페이퍼 | 무료 일부 | WebSearch `site:nber.org/papers 검색어` |
| RePEc (IDEAS · EconPapers) | `ideas.repec.org` · `econpapers.repec.org` | 경제학 워킹페이퍼 · 논문 색인 | 무료 | WebSearch `site:ideas.repec.org 검색어` |
| PsyArXiv | `osf.io/preprints/psyarxiv` | 심리학. 2025-08 부터 사전 검수로 바뀌었다는 보고가 있다 (`미확인`) | 무료 | WebSearch `site:osf.io/preprints/psyarxiv 검색어` |
| SocArXiv | `osf.io/preprints/socarxiv` | 사회학 · 사회과학. 메릴랜드대 도서관이 기관 거점 | 무료 | WebSearch `site:osf.io/preprints/socarxiv 검색어` |
| OSF Preprints | `osf.io/preprints` | 분야 공통 서버와 위 두 곳 같은 커뮤니티 서버 | 무료 | WebSearch `site:osf.io/preprints 검색어` |
| ChemRxiv | `chemrxiv.org` | 화학. Cambridge Open Engage 위에서 운영 (2021 이전) | 무료 | WebSearch `site:chemrxiv.org 검색어` |
| EarthArXiv | `eartharxiv.org` | 지구과학. OSF 에서 CDL 의 Janeway 로 옮겼다 | 무료 | WebSearch `site:eartharxiv.org 검색어` |
| TechRxiv | `techrxiv.org` | IEEE 운영, 공학 · CS. 게재 확정본은 받지 않는다 | 무료 | WebSearch `site:techrxiv.org 검색어` |
| Research Square | `researchsquare.com` | 분야 공통. Springer Nature 소유, 저널 투고와 연동(In Review) | 무료 | WebSearch `site:researchsquare.com 검색어` |
| Preprints.org | `preprints.org` | 분야 공통. MDPI 운영 | 무료 | WebSearch `site:preprints.org 검색어` |

## 검색 문법과 요령

### arXiv

| 하는 일 | 문법 (API `search_query`) |
|---|---|
| 필드 접두사 | `ti:` 제목 · `au:` 저자 · `abs:` 초록 · `co:` 코멘트 · `jr:` 저널 참조 · `cat:` 카테고리 · `rn:` 보고서 번호 · `all:` 전부 |
| 불리언 | `AND` · `OR` · `ANDNOT`, 괄호로 묶는다 |
| 구 | 큰따옴표 (URL 에서는 `%22`) |
| 제출일 범위 | `submittedDate:[202301010600 TO 202401010600]` (YYYYMMDDTTTT, GMT) |
| 정렬 | `sortBy=relevance` · `lastUpdatedDate` · `submittedDate`, `sortOrder=ascending` · `descending` |
| 페이지 | `start` · `max_results` (요청당 최대 2,000, 질의당 30,000) |
| 특정 논문 | `id_list=2401.01234` (`id:` 접두사는 버전 처리가 틀리므로 쓰지 않는다) |

- 예: `cat:cs.CL AND ti:"retrieval augmented"`.
- 카테고리 예: `cs.LG` · `cs.CL` · `cs.CV` · `cs.AI` · `stat.ML` · `q-bio.NC` · `econ.EM` · `hep-th` · `quant-ph`.
- 하루치 신규 목록은 WebFetch `arxiv.org/list/<카테고리>/new`.
- 버전: ID 뒤 `v2` 처럼 붙는다. 인용할 때 어느 버전인지 적는다.
- 코멘트(`co:`)에 "Accepted at NeurIPS 2025" 같은 게재 정보가 들어 있는 경우가 많다.

### bioRxiv · medRxiv

- 고급 검색에서 제목 · 초록 · 저자 · 전문 · 날짜 범위 · 주제 컬렉션을 고른다. 주제 컬렉션은 bioRxiv 기준 27개다.
- 게재본이 나오면 프리프린트 페이지에 "Now published in" 링크가 붙는다. 이걸로 게재 여부를 확인한다.

### SSRN · NBER · RePEc

- SSRN 은 같은 논문이 여러 버전 · 여러 제목으로 올라온다. 날짜가 늦은 쪽과 게재지를 확인한다.
- NBER 워킹페이퍼 번호(`w31234`)로 찾으면 정확하다.
- RePEc 는 같은 논문의 워킹페이퍼판과 저널판을 묶어 보여준다. 게재 여부 확인에 쓴다.

### 공통 요령

- 서버 자체 검색창보다 WebSearch `site:` 이 빠르다. 결과가 적으면 Semantic Scholar · OpenAlex 로 같은 제목을 다시 찾는다 (두 색인 모두 프리프린트를 모은다).
- 프리프린트를 찾으면 같은 제목으로 게재본이 있는지 한 번 더 찾는다 (`academic-index-searcher` 의 Crossref).

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 프리프린트 | 기본값. 심사를 거치지 않았다 |
| 프리프린트 (게재됨: 게재지) | 서버 페이지의 게재 링크 · arXiv `jr:` · 색인에서 게재본을 확인했다 |
| 워킹페이퍼 | SSRN · NBER · RePEc 의 경제 · 경영 원고 |
| 철회 · 철회 요청 | 서버가 withdrawn 표시를 했다 |

주의:

- 프리프린트 서버의 검수는 형식 · 범위 · 윤리 확인이다. 내용의 타당성은 보증하지 않는다.
- medRxiv 원고를 임상 판단 근거로 쓰지 않는다고 적는다 (서버 자체가 그렇게 경고한다).
- 버전마다 결론이 바뀔 수 있다. 인용한 버전 번호 · 날짜를 적는다.
- Research Square(Springer Nature) · Preprints.org(MDPI) 는 출판사가 운영한다. 운영사를 결과에 같이 적는다.
