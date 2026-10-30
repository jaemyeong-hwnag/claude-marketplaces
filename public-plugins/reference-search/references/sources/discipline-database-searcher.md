# discipline-database-searcher 출처 카탈로그

기준일 2026-10. 분야별 전문 DB(의학 · CS · 심리 · 경제 · 교육 · 인문 · 법 · 공학 · 화학 · 물리 · 수학 · 농업 · 특허 · 학위논문)에서 찾는다.

## 질문 분야 → 볼 DB

먼저 이 표로 DB 를 고른다. 왼쪽부터 본다.

| 질문 분야 | 먼저 (무료) | 다음 | 기관 구독이면 안내 |
|---|---|---|---|
| 의학 · 생의학 | PubMed | Europe PMC · Cochrane Library | Embase |
| 임상시험 · 진행 중인 연구 | ClinicalTrials.gov | PubMed (`clinical trial[pt]`) | - |
| 간호 · 보건 | PubMed | Europe PMC | CINAHL |
| CS 일반 · 학회 논문 | DBLP | ACM DL · IEEE Xplore | - |
| ML · AI 학회 심사 기록 | OpenReview | DBLP | - |
| 전기 · 전자 · 통신 | IEEE Xplore | DBLP | Engineering Village |
| 공학 전반 | IEEE Xplore | - | Engineering Village |
| 심리학 | PubMed | Europe PMC | APA PsycInfo |
| 경제학 | (`preprint-searcher` 의 RePEc · NBER) | - | EconLit |
| 교육학 | ERIC | - | - |
| 인문학 · 문학 · 철학 | PhilPapers (철학) | JSTOR · Project MUSE | MLA International Bibliography |
| 법학 | (판례 · 법령은 각국 공식 사이트) | HeinOnline | Westlaw · LexisNexis |
| 화학 | PubMed (생화학) | ACS · RSC 저널 | CAS SciFinder · Reaxys |
| 물리 · 천문 | NASA ADS · INSPIRE-HEP | APS · IOP · AIP 저널 | - |
| 수학 | zbMATH Open | - | MathSciNet |
| 농업 · 환경 · 식품 | AGRIS | - | CABI Digital Library (CAB Abstracts) |
| 특허 | Google Patents · Lens | Espacenet · KIPRIS | - |
| 학위논문 | OATD | EThOS (영국) | ProQuest Dissertations & Theses |

## 언제 쓰는가

- 띄운다: 질문이 위 표의 한 분야에 속하고 그 분야 DB 의 색인 · 문법(MeSH, 학회 목록, 특허 분류 등)이 결과를 낫게 할 때.
- 띄운다: 임상시험 등록 정보, 특허, 학위논문처럼 일반 학술 색인이 약한 자료.
- 띄우지 않는다: 분야를 가리지 않는 검색(`academic-index-searcher`), 프리프린트만(`preprint-searcher`), 한국 · 일본 · 중국 등 지역 DB(`regional-academic-database-searcher`).

## 출처

### 의학 · 생명과학

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| PubMed | `pubmed.ncbi.nlm.nih.gov` | MEDLINE 과 PMC, 생의학 초록 | 무료 | `reference-search.sh pubmed` |
| Europe PMC | `europepmc.org` | PubMed 내용 + 프리프린트 · 연구비 · 특허 일부 · 전문 검색 | 무료 | `reference-search.sh europepmc` |
| Cochrane Library | `cochranelibrary.com` | 체계적 문헌고찰 · 임상시험 등록(CENTRAL) | 무료 일부 (전문은 구독 또는 국가 라이선스) | WebSearch `site:cochranelibrary.com 검색어` |
| ClinicalTrials.gov | `clinicaltrials.gov` | 임상시험 등록 · 결과. 구 사이트와 구 API 는 2024-06-25 종료, 새 사이트 · 새 API 만 있다 | 무료 | WebFetch `clinicaltrials.gov/search?term=검색어` |
| Embase | `embase.com` | Elsevier 의 생의학 · 약학 색인. 유럽 저널 · 학회 초록이 두텁다 | 기관 구독 | 사용자 안내만 |
| CINAHL | EBSCO 플랫폼 | 간호 · 보건 | 기관 구독 | 사용자 안내만 |

### 컴퓨터과학 · 공학

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| DBLP | `dblp.org` | CS 학회 · 저널 서지 | 무료 | WebSearch `site:dblp.org 검색어`. API · WebFetch 는 봇 확인 페이지가 온다 (2026-10 확인) |
| ACM Digital Library | `dl.acm.org` | ACM 학회 · 저널 (KDD · SOSP · SIGMOD · CHI 등). 2026-01-01 부터 전체 오픈 액세스 | 무료 | WebSearch `site:dl.acm.org 검색어` |
| IEEE Xplore | `ieeexplore.ieee.org` | IEEE 저널 · 학회 · 표준 | 무료 일부 | WebSearch `site:ieeexplore.ieee.org 검색어` |
| OpenReview | `openreview.net` | ICLR · NeurIPS 등의 투고 · 심사평 · 결정 | 무료 | `reference-search.sh openreview` |
| Engineering Village | `engineeringvillage.com` | Elsevier 의 공학 색인 (Compendex · Inspec) | 기관 구독 | 사용자 안내만 |

### 사회과학 · 인문 · 법

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| APA PsycInfo | `apa.org/pubs/databases/psycinfo` | 심리학 색인 | 기관 구독 | 사용자 안내만 |
| EconLit | `aeaweb.org/econlit` | 미국경제학회의 경제학 색인 | 기관 구독 | 사용자 안내만 |
| ERIC | `eric.ed.gov` | 미국 교육부의 교육학 색인 · 보고서 | 무료 | WebFetch `eric.ed.gov/?q=검색어` |
| JSTOR | `jstor.org` | 인문 · 사회과학 저널 과월호 | 무료 일부 (무료 계정 열람 한도, 전문은 기관) | WebSearch `site:jstor.org 검색어` |
| Project MUSE | `muse.jhu.edu` | 인문 · 사회과학 저널 · 책 | 무료 일부 | WebSearch `site:muse.jhu.edu 검색어` |
| PhilPapers | `philpapers.org` | 철학 색인 | 무료 | WebSearch `site:philpapers.org 검색어` |
| MLA International Bibliography | `mla.org` | 언어 · 문학 색인 (EBSCO 등에서 제공) | 기관 구독 | 사용자 안내만 |
| Westlaw | `westlaw.com` | 판례 · 법령 · 법학 논문 | 기관 구독 | 사용자 안내만 |
| LexisNexis | `lexisnexis.com` | 판례 · 법령 · 뉴스 | 기관 구독 | 사용자 안내만 |
| HeinOnline | `heinonline.org` | 법학 저널 과월호 · 법령 | 기관 구독 | 사용자 안내만. 서지는 WebSearch `site:heinonline.org 제목` |

### 화학 · 물리 · 천문 · 수학

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| CAS SciFinder | `scifinder-n.cas.org` | 화학 물질 · 반응 · 문헌. 2024 에 SciFinder-n 에서 CAS SciFinder 로 이름이 바뀌었다 | 기관 구독 | 사용자 안내만 |
| Reaxys | `reaxys.com` | Elsevier 의 화학 반응 · 물성 | 기관 구독 | 사용자 안내만 |
| ACS Publications | `pubs.acs.org` | 미국화학회 저널 | 무료 일부 | WebSearch `site:pubs.acs.org 검색어` |
| RSC Publishing | `pubs.rsc.org` | 영국왕립화학회 저널 | 무료 일부 | WebSearch `site:pubs.rsc.org 검색어` |
| APS Journals | `journals.aps.org` | Physical Review 계열 | 무료 일부 | WebSearch `site:journals.aps.org 검색어` |
| IOPscience | `iopscience.iop.org` | IOP 저널 | 무료 일부 | WebSearch `site:iopscience.iop.org 검색어` |
| AIP Publishing | `pubs.aip.org` | AIP 저널 | 무료 일부 | WebSearch `site:pubs.aip.org 검색어` |
| NASA ADS / SciX | `ui.adsabs.harvard.edu` · `scixplorer.org` | 천문 · 천체물리 (SciX 는 NASA 과학 전 분야로 확장). SciX 는 2025-09 공식 출시, ADS 는 SciX 로 이전 중이고 ADS 종료일은 `미확인` | 무료 | WebSearch `site:ui.adsabs.harvard.edu 검색어` |
| INSPIRE-HEP | `inspirehep.net` | 고에너지 물리 | 무료 | WebFetch `inspirehep.net/literature?q=검색어` |
| MathSciNet | `mathscinet.ams.org` | 미국수학회의 수학 리뷰 | 기관 구독 | 사용자 안내만 |
| zbMATH Open | `zbmath.org` | 수학 리뷰 · 서지 | 무료 | WebFetch `zbmath.org/?q=검색어` |

### 농업 · 환경

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| CABI Digital Library | `cabidigitallibrary.org` | CAB Abstracts · Global Health. 구 CAB Direct(`cabdirect.org`)는 2024-01 에 닫히고 이리로 옮겼다 | 기관 구독 | 사용자 안내만 |
| FAO AGRIS | `agris.fao.org` | FAO 의 농업 문헌 색인. 2025-10 에 "FAO AGRIS" 로 이름을 바꿨다 | 무료 | WebSearch `site:agris.fao.org 검색어` |

### 특허

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Google Patents | `patents.google.com` | 각국 특허 전문 · 번역 | 무료 | WebFetch `patents.google.com/?q=검색어` 또는 WebSearch `site:patents.google.com 검색어` |
| Espacenet | `worldwide.espacenet.com` | 유럽특허청의 전 세계 특허 | 무료 | WebSearch `site:worldwide.espacenet.com 검색어` |
| KIPRIS | `kipris.or.kr` | 한국 특허 · 실용신안 · 디자인 · 상표 | 무료 (API 는 키 필요 — TODO) | WebSearch `site:kipris.or.kr 검색어` |
| Lens.org | `lens.org` | 특허와 그 특허가 인용한 논문 | 무료 일부 | WebSearch `site:lens.org 검색어` |

### 학위논문

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| ProQuest Dissertations & Theses | `proquest.com` | 북미 중심 학위논문 | 기관 구독 | 사용자 안내만 |
| OATD | `oatd.org` | 공개 학위논문 색인. 원문은 각 대학 리포지터리 | 무료 | WebSearch `site:oatd.org 검색어` |
| EThOS | `ethos.bl.uk` | 영국 학위논문. 2023 사이버공격으로 중단, 2026-07 에 메타데이터 전용으로 복구되고 파일 내려받기는 아직 없다 | 무료 | WebSearch `site:ethos.bl.uk 검색어` 후 대학 리포지터리로 |
| DART-Europe | `dart-europe.org` | **종료** (2025-02 초). 쓰지 않는다 — BASE · OATD 로 대신한다 | - | - |

## 검색 문법과 요령

### PubMed

| 하는 일 | 문법 |
|---|---|
| 제목 · 초록 | `term[tiab]` · `term[ti]` |
| MeSH | `term[mh]` · 주제어 중심 `term[majr]` · 부표목 `[sh]` |
| 저자 | `name[au]` · 제1저자 `[1au]` · 마지막 저자 `[lastau]` |
| 저널 · 소속 | `[ta]` · `[ad]` |
| 출판 유형 | `systematic review[pt]` · `clinical trial[pt]` · `randomized controlled trial[pt]` |
| 언어 | `english[la]` |
| 날짜 | `2020/06/01[dp]` · `2019:2023[dp]` · `"last 5 years"[dp]` |
| 구 | 큰따옴표 `"kidney allograft"` |
| 근접 | `"rationing healthcare"[Title:~2]` |
| 자르기 | `colo*` (앞에 4글자 이상) |
| 부분집합 | `free full text[sb]` · `systematic[sb]` · `medline[sb]` · `hasabstract` |
| 프리프린트 빼기 | `NOT preprint[pt]` |

- 요령: 주제는 MeSH 와 `[tiab]` 를 OR 로 묶는다. MeSH 는 색인이 늦어 새 논문이 빠진다.
- 근거 수준이 중요하면 `systematic review[pt]` 와 Cochrane 을 먼저 본다.

### Europe PMC

- `TITLE:` · `AUTH:` · `TITLE_ABS:` (제목+초록) 필드를 쓴다. 프리프린트만은 `SRC:PPR`.
- 오픈 액세스 · 연도 필드 이름은 이번에 확인하지 못했다 — `미확인`. `europepmc.org/advancesearch` 의 질의 작성기가 정확한 이름을 보여준다.
- PubMed 에 없는 프리프린트 · 전문 검색이 필요할 때 쓴다.

### DBLP

- 단어는 대소문자 무시 앞부분 일치가 기본이다 (`sig` → SIGIR · signal).
- 정확한 단어: `graph$`. OR: `graph|network`.
- 빼기(`-`)는 2017 부터 꺼져 있어 일반 검색어로 처리된다. 학회 · 유형 거르기도 쓸 수 없다.
- 학회명은 DBLP 약칭(`conf/nips` · `conf/iclr`)이 페이지 경로에 들어간다. WebSearch `site:dblp.org/db/conf/iclr` 처럼 좁힌다.

### OpenReview

- 학회 그룹 경로는 `openreview.net/group?id=ICLR.cc/2026/Conference` 꼴이다.
- 심사평 · 점수 · 채택 결정까지 볼 수 있다. 채택 여부(Accept · Reject · Withdrawn)를 결과에 적는다.

### 특허

- Google Patents 는 출원인 · 발명자 · 날짜 · CPC 분류로 거를 수 있다 (고급 검색 화면). 질의 문법 세부는 `미확인`.
- 특허 번호를 알면 `patents.google.com/patent/<번호>` 로 바로 연다 (예: `US1234567B2`).

### 학위논문

- 학위논문 대부분은 대학 리포지터리에 원문이 있다. 색인에서 찾은 뒤 리포지터리 링크로 간다.
- 한국 학위논문은 `regional-academic-database-searcher` (RISS · 국회도서관).

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 심사 완료 | 저널 · 학회 게재 |
| 체계적 문헌고찰 · 메타분석 | PubMed `[pt]` · Cochrane 로 확인 — 근거 수준이 가장 높다고 적는다 |
| 임상시험 등록 | ClinicalTrials.gov 항목. 결과 게시 여부(Has Results)를 같이 적는다 |
| 학회 투고 (심사 중 · 거절 · 철회) | OpenReview 의 결정 상태 |
| 학위논문 | OATD · EThOS · ProQuest |
| 특허 (출원 · 등록) | 출원과 등록을 구분해 적는다. 특허는 동료 심사 문헌이 아니다 |
| 기관 구독으로 확인 필요 | 유료 DB 라 직접 확인하지 못했다 |

주의:

- PubMed 에도 프리프린트가 들어온다 (`preprint[pt]`). 심사 완료로 적지 않는다.
- IEEE · ACM 학회 논문은 학회 등급 차이가 크다. 학회명 약칭을 같이 적는다.
- 학위논문은 심사위원 심사를 거쳤지만 저널 심사와 같지 않다. "학위논문" 으로 따로 적는다.
- 법 자료는 관할(국가 · 주)과 시점을 적는다. 이 에이전트의 결과는 법률 자문이 아니다.
