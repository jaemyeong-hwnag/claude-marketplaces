# academic-index-searcher 출처 카탈로그

기준일 2026-10. 분야를 가리지 않는 학술 색인에서 논문 · 서지 · 인용 수를 찾고, 원문은 출판사 플랫폼으로 연결한다.

## 언제 쓰는가

- 띄운다: 분야가 정해지지 않은 논문 검색, DOI · 서지 확인, 인용 수 · 피인용 논문 확인, 오픈 액세스 사본 찾기.
- 띄운다: 다른 에이전트가 찾은 논문의 출판 여부 · 게재지를 확인할 때.
- 띄우지 않는다: 프리프린트만 찾는 요청(`preprint-searcher`), 의학 · CS 등 분야 DB 가 정해진 요청(`discipline-database-searcher`), 한국어 · 비영어권 논문(`regional-academic-database-searcher`), 화제 논문 · 동향(`research-trend-searcher`).

## 출처

### 무료 색인

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| OpenAlex | `openalex.org` | 전 분야 논문 · 저자 · 기관 · 인용. Microsoft Academic Graph 후속 | 무료 일부 (검색 호출은 유료 과금 단위가 있다) | `reference-search.sh openalex` |
| Semantic Scholar | `semanticscholar.org` | 전 분야, CS · 생의학이 두텁다. TLDR · 인용 맥락 | 무료 (키 없이 공용 한도, 키가 있으면 전용 한도) | `reference-search.sh semantic-scholar` |
| Crossref | `crossref.org` | DOI 메타데이터. 서지 확인 · DOI 찾기 | 무료 | `reference-search.sh crossref` |
| Google Scholar | `scholar.google.com` | 전 분야, 학위논문 · 보고서 · 판례까지. 피인용 수 | 무료 (API 없음) | WebSearch `site:scholar.google.com 검색어` 는 잘 안 잡힌다. WebFetch `scholar.google.com/scholar?q=검색어` 는 봇 차단이 잦다 — 다른 색인으로 찾고 Scholar 는 피인용 수 확인에만 |
| Dimensions | `dimensions.ai` | 논문 · 연구비 · 특허 · 임상시험 연결 | 무료 일부 (무료 웹앱은 개인 비영리용, 분석 기능은 구독) | WebSearch `site:app.dimensions.ai 검색어` |
| Lens.org | `lens.org` | 학술 논문과 특허를 한 곳에서 | 무료 일부 (API 는 키 필요 — TODO) | WebSearch `site:lens.org 검색어` |
| BASE | `base-search.net` | 전 세계 기관 리포지터리 · 학위논문의 OA 사본 | 무료 | WebSearch `site:base-search.net 검색어`. WebFetch 는 봇 차단 페이지가 온다 (2026-10 확인) |
| CORE | `core.ac.uk` | 리포지터리 OA 원문 집계 | 키 필요 — TODO | WebSearch `site:core.ac.uk 검색어` |
| DOAJ | `doaj.org` | 오픈 액세스 저널 목록과 논문. 저널 정당성 확인 | 무료 | WebSearch `site:doaj.org 저널명` |
| Unpaywall | `unpaywall.org` | DOI 로 합법 OA 사본 위치 찾기 | 키 필요 — TODO (이메일 등록) | WebSearch `"DOI" filetype:pdf` 로 대신한다 |

### 유료 색인 — 기관 접속 안내만

이 에이전트는 직접 검색하지 못한다. 결과에 "기관 구독으로 확인 필요" 라고 적고 사용자에게 소속 도서관 경유 접속을 안내한다.

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Scopus | `scopus.com` | Elsevier 의 초록 · 인용 색인 | 기관 구독 | 사용자 안내만 |
| Web of Science | `webofscience.com` | Clarivate 의 인용 색인 (SCIE · SSCI · AHCI) | 기관 구독 | 사용자 안내만 |
| ProQuest | `proquest.com` | 학위논문 · 신문 · 업계지 묶음 | 기관 구독 | 사용자 안내만. 학위논문은 `discipline-database-searcher` |
| EBSCO | `ebsco.com` | 분야별 DB 묶음 (CINAHL · EconLit · MLA 등) | 기관 구독 | 사용자 안내만 |

### 출판사 플랫폼 — 원문 받는 곳

색인에서 찾은 DOI 가 가리키는 곳이다. 검색 출발점으로 쓰지 않는다. 초록 페이지는 대부분 무료로 열린다.

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| ScienceDirect | `sciencedirect.com` | Elsevier 저널 · 책 | 무료 일부 | DOI 로 열기, WebSearch `site:sciencedirect.com 제목` |
| SpringerLink | `link.springer.com` | Springer 저널 · 책 · 학회 (LNCS 포함) | 무료 일부 | WebSearch `site:link.springer.com 제목` |
| Wiley Online Library | `onlinelibrary.wiley.com` | Wiley 저널 | 무료 일부 | WebSearch `site:onlinelibrary.wiley.com 제목` |
| Taylor & Francis Online | `tandfonline.com` | T&F 저널, 인문 · 사회과학 비중이 크다 | 무료 일부 | WebSearch `site:tandfonline.com 제목` |
| SAGE Journals | `journals.sagepub.com` | 사회과학 · 의학 저널 | 무료 일부 | WebSearch `site:journals.sagepub.com 제목` |
| Oxford Academic | `academic.oup.com` | OUP 저널 · 책 | 무료 일부 | WebSearch `site:academic.oup.com 제목` |
| Cambridge Core | `cambridge.org` | CUP 저널 · 책 | 무료 일부 | WebSearch `site:cambridge.org/core 제목` |
| Nature Portfolio | `nature.com` | Nature 와 자매지, Scientific Reports | 무료 일부 | WebSearch `site:nature.com 제목` |
| Science | `science.org` | AAAS 의 Science 와 자매지 | 무료 일부 | WebSearch `site:science.org 제목` |
| Cell Press | `cell.com` | Cell 과 자매지 | 무료 일부 | WebSearch `site:cell.com 제목` |
| PLOS | `journals.plos.org` | PLOS ONE 등 전부 OA | 무료 | WebSearch `site:journals.plos.org 제목` |
| MDPI | `mdpi.com` | 전부 OA, 저널 수가 많다 | 무료 | WebSearch `site:mdpi.com 제목` |
| Frontiers | `frontiersin.org` | 전부 OA | 무료 | WebSearch `site:frontiersin.org 제목` |

## 검색 문법과 요령

### OpenAlex (`api.openalex.org/works`)

| 하는 일 | 문법 |
|---|---|
| 전문 검색 (제목 · 초록 · 전문 · 키워드) | `search=검색어` |
| 범위를 좁힌 검색 | `search.title=` · `search.title_and_abstract=` |
| 불리언 | 대문자 `AND` · `OR` · `NOT`, 구는 큰따옴표. 빼기(`-`)는 제외가 아니다 — `NOT` 을 쓴다 |
| 근접 | `"climate change"~5` |
| 필터 결합 (AND) | `filter=publication_year:2024,is_oa:true` |
| 범위 · 비교 | `from_publication_date:2022-01-01,to_publication_date:2022-12-31` · `cited_by_count:>100` |
| 같은 속성 OR | `institutions.country_code:fr\|gb` (최대 100개, 다른 속성끼리는 안 된다) |
| 부정 | `country_code:!us` |
| 정렬 | 기본은 관련도. `sort` 옵션 이름은 문서에서 확인하지 못했다 — `미확인` |

`filter=title.search:` 꼴은 폐기 예정이다. `search.title=` 을 쓴다.

### Crossref (`api.crossref.org/works`)

| 하는 일 | 문법 |
|---|---|
| 서지 문자열로 찾기 (인용문 붙여넣기) | `query.bibliographic=제목 저자 연도` |
| 저자 · 게재지 | `query.author=` · `query.container-title=` |
| 정렬 | `sort=relevance` · `published` · `is-referenced-by-count` |
| 응답 우선 처리 | `mailto=` 를 붙이면 polite pool |

날짜 · 유형 필터 이름은 이번에 확인하지 못했다 — `미확인`. 인용 한 줄만 있고 DOI 를 모를 때 `query.bibliographic` 이 가장 잘 맞는다.

### Semantic Scholar

- 일반 검색은 관련도순이다. bulk 검색은 `paperId` · `publicationDate` · `citationCount` 로 정렬하고 한 번에 1,000건까지 준다.
- `|` 로 OR 를 쓴다. `+` · `-` · 따옴표의 동작과 연도 · 분야 필터 파라미터 이름은 이번에 공식 문서로 확인하지 못했다 — `미확인`. 스크립트 옵션을 따른다.
- 키 없는 요청은 모든 사용자가 한도를 나눠 쓴다. 429 가 오면 잠시 뒤 다시 하거나 OpenAlex 로 넘어간다.

### Google Scholar

| 하는 일 | 문법 |
|---|---|
| 저자 | `author:"d knuth"` |
| 정확한 제목 | 제목을 큰따옴표로 |
| 제목에 모든 단어 | `allintitle:` (도움말의 예시에만 나온다) |
| 사이트 | `site:` 은 논문의 대표 버전만 본다 |
| 날짜 | 왼쪽 "Since 연도" 또는 "Sort by date" (고급 검색에서 연도 범위) |
| 게재지 | 고급 검색의 publication 칸. 인라인 `source:` 는 공식 도움말에 없다 — `미확인` |

### 요령

- 순서: OpenAlex 또는 Semantic Scholar 로 찾는다 → Crossref 로 DOI · 서지를 맞춘다 → OA 사본은 BASE · CORE · 출판사 페이지에서.
- 제목만 알 때는 Crossref `query.bibliographic`, 주제로 넓게 찾을 때는 OpenAlex `search`.
- 출판사 플랫폼은 검색창보다 WebSearch `site:` 가 빠르다. 원문이 유료면 저자 사본을 `"제목" filetype:pdf` 로 찾는다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 심사 완료 | 저널 · 학회에 게재되고 DOI 가 출판사 페이지로 연결된다 |
| 프리프린트 | 게재지가 arXiv · SSRN 등 프리프린트 서버뿐이다. 색인은 프리프린트와 게재본을 같은 항목으로 합치기도 한다 — DOI 접두사와 게재지를 본다 |
| 학위논문 · 기관 보고서 | Scholar · BASE 가 돌려준 리포지터리 문서 |
| 철회 | 출판사 페이지 · Crossref 에 retraction 표시가 있다. 결과에서 빼지 말고 철회라고 적는다 |
| 기관 구독으로 확인 필요 | 유료 색인 · 유료 원문이라 내용을 직접 확인하지 못했다 |

주의:

- 인용 수는 색인마다 다르다. 어느 색인 기준인지 적는다 (Scholar 가 가장 크게 나온다).
- MDPI · Frontiers 는 저널마다 질 차이가 크다. 저널명과 그 저널의 DOAJ · Web of Science 등재 여부를 같이 적는다.
- 약탈적 저널 의심(DOAJ 미등재 OA 저널, 심사 기간이 비정상적으로 짧음, 저널명이 유명 저널과 비슷함)은 "게재지 신뢰도 확인 필요" 로 표시한다. 판단 기준은 `thinkchecksubmit.org` 체크리스트를 쓴다.
- Scholar 의 "[인용]" · "[도서]" 항목은 원문이 없는 경우가 많다. 서지만 있으면 그렇게 적는다.
