# regional-academic-database-searcher 출처 카탈로그

기준일 2026-10. 한국을 먼저, 그다음 일본 · 중국 · 프랑스 · 독일 · 중남미 · 러시아의 자국어 학술 DB 에서 찾는다.

## 언제 쓰는가

- 띄운다: 한국어 논문 · 학위논문 · 국내 연구보고서가 필요한 요청, 한국 사례 · 정책 · 법 · 교육처럼 국내 문헌이 핵심인 주제.
- 띄운다: 일본 · 중국 · 프랑스 · 중남미 · 러시아 연구가 필요하거나 영어 색인에서 결과가 적은 지역 주제.
- 띄우지 않는다: 영어권 논문만으로 충분한 요청(`academic-index-searcher`), 특허(`discipline-database-searcher` 의 KIPRIS).

## 출처

### 한국 (우선)

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| RISS | `riss.kr` | 한국교육학술정보원. 국내 학위논문 · 학술지 · 단행본 통합 검색, 해외 논문 일부 | 무료 일부 (원문은 DBpia · KISS 등 제공처 로그인. API 는 키 필요 — TODO, 비영리 기관 대상) | WebSearch `site:riss.kr 검색어` |
| KCI | `kci.go.kr` | 한국연구재단 한국학술지인용색인. 등재 · 등재후보 학술지와 피인용 | 무료 (API 는 키 필요 — TODO, 공문 신청) | WebSearch `site:kci.go.kr 검색어` |
| DBpia | `dbpia.co.kr` | 누리미디어. 국내 학술지 원문 | 무료 일부 (원문은 기관 구독 또는 개별 구매) | WebSearch `site:dbpia.co.kr 검색어` |
| KISS | `kiss.kstudy.com` | 한국학술정보. 국내 학술지 원문, 사회과학 비중이 크다 | 무료 일부 (원문은 기관 구독) | WebSearch `site:kiss.kstudy.com 검색어` |
| ScienceON | `scienceon.kisti.re.kr` | KISTI. 과학기술 논문 · 특허 · 보고서 · 동향 통합 | 무료 일부 (API 는 키 필요 — TODO) | WebSearch `site:scienceon.kisti.re.kr 검색어` |
| NTIS | `ntis.go.kr` | 국가R&D 과제 · 성과 · 연구보고서 | 무료 (API 는 키 필요 — TODO) | WebSearch `site:ntis.go.kr 검색어` |
| 국회도서관 | `dl.nanet.go.kr` · `nanet.go.kr` | 학위논문 · 학술기사 · 정책자료. 원문 일부는 도서관 · 협정 기관 PC 에서만 열린다 | 무료 일부 | WebSearch `site:dl.nanet.go.kr 검색어` |

### 다른 지역

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| CiNii Research | `cir.nii.ac.jp` | 일본 NII. 논문 · 책 · 학위논문 · 연구 데이터. 구 CiNii Articles 는 2022-04-18 에 여기로 통합됐다 | 무료 | WebSearch `site:cir.nii.ac.jp 검색어`. 검색 결과 페이지는 WebFetch 로 열면 빈 내용이 온다 (2026-10 확인) |
| J-STAGE | `jstage.jst.go.jp` | 일본 JST. 일본 학회지 원문, 대부분 무료 | 무료 | WebSearch `site:jstage.jst.go.jp 검색어` |
| CNKI | `cnki.net` | 중국 최대 학술 DB. 2023-04 부터 해외 이용자의 학위논문 · 학회 · 통계연감 등 일부 DB 접근이 막혔다 (이후 변동 `미확인`) | 기관 구독 | WebSearch `site:cnki.net 검색어` (서지만) |
| Wanfang Data | `wanfangdata.com.cn` | 중국 학술지 · 학위논문 | 기관 구독 | WebSearch `site:wanfangdata.com.cn 검색어` |
| HAL | `hal.science` | 프랑스 공공 오픈 아카이브. 논문 · 학위논문 원문 | 무료 | WebSearch `site:hal.science 검색어` |
| BASE | `base-search.net` | 독일 빌레펠트대. 유럽 리포지터리 집계 (`academic-index-searcher` 와 같은 출처) | 무료 | WebSearch `site:base-search.net 검색어` |
| SciELO | `scielo.org` | 중남미 · 포르투갈 · 스페인 · 남아공 OA 저널 | 무료 | WebSearch `site:scielo.org 검색어` (국가별로 `scielo.br` 등) |
| Redalyc | `redalyc.org` | 중남미 · 이베리아 OA 저널 | 무료 | WebSearch `site:redalyc.org 검색어` |
| eLIBRARY.ru | `elibrary.ru` | 러시아 과학전자도서관 · 러시아 과학인용색인(RSCI). 원문은 회원 가입 필요 | 무료 일부 | WebSearch `site:elibrary.ru 검색어` |

## 검색 문법과 요령

### 검색어를 그 나라 언어로 바꾼다

| 지역 | 바꾸는 법 |
|---|---|
| 한국 | 영어 개념어 + 한국어 번역어를 둘 다 넣는다 (`"생성형 AI" OR "생성형 인공지능"`). 국내 논문은 영문 초록 · 영문 키워드가 있는 경우가 많아 영어로도 한 번 더 찾는다 |
| 일본 | 한자어는 일본식 표기로 (`機械学習` · `深層学習` · `生成AI`). 외래어는 가타카나 (`トランスフォーマー`) |
| 중국 | 간체자로 (`机器学习` · `深度学习` · `大语言模型`). 번체로 찾으면 대만 자료가 섞인다 |
| 프랑스 | 프랑스어 용어 (`apprentissage automatique`). HAL 은 영어 논문도 많다 |
| 중남미 | 스페인어 · 포르투갈어 둘 다 (`aprendizaje automático` · `aprendizado de máquina`) |
| 러시아 | 키릴 문자 (`машинное обучение`) |

- 번역어는 그 나라 학회 · 정부 문서에서 쓰는 용어를 고른다. 사전 직역이 다를 수 있다 — 첫 검색 결과의 제목 · 키워드에서 실제로 쓰는 말을 보고 다시 찾는다.
- 사람 이름은 현지 표기와 로마자 표기를 둘 다 넣는다.

### 한국 DB 요령

- 순서: RISS 로 넓게 찾는다 → KCI 로 등재 여부 · 피인용을 확인한다 → 원문은 DBpia · KISS · 학회 홈페이지.
- 학위논문은 RISS 와 국회도서관. 석사 · 박사를 구분해 적는다.
- 과학기술 · 국가R&D 보고서는 ScienceON · NTIS. 정책 연구는 국회도서관의 정책자료.
- 같은 논문이 DBpia 와 KISS 에 둘 다 있을 수 있다. 서지를 합친다.
- 국내 DB 는 WebFetch 로 검색 결과 페이지가 잘 열리지 않는다(동적 페이지). WebSearch `site:` 으로 찾고 상세 페이지를 연다.

### HAL

- API 질의는 Solr 문법이고 `title_s:"..."` · `authFullName_s:"..."` 필드가 쓰인다는 2차 자료가 있다 — `미확인`. 웹 검색은 WebSearch `site:hal.science` 로 한다.

### CNKI · Wanfang

- 해외에서 원문 접근이 막혀 있을 수 있다. 서지와 초록만 확인하고 "원문 접근 제한" 을 적는다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 심사 완료 (KCI 등재 · 등재후보) | KCI 에서 학술지 등재 상태를 확인했다 |
| 심사 완료 (KCI 미등재) | 학술지 논문이지만 KCI 등재지가 아니다. 학회지 질 차이가 커서 따로 표시한다 |
| 학위논문 (석사 · 박사) | RISS · 국회도서관 · CiNii · HAL 의 학위논문 |
| 연구보고서 | NTIS · ScienceON 의 정부 과제 보고서. 동료 심사를 거치지 않았다 |
| 학술대회 발표 | 국내 학술대회 논문집 · 초록. 심사 수준이 저널보다 낮다 |
| 원문 접근 제한 | 유료 · 기관 구독 · 지역 제한으로 원문을 보지 못했다 |

주의:

- 국내 학술대회 논문과 학술지 논문은 같은 제목으로 두 번 실리기도 한다. 학술지판을 우선한다.
- 결과를 요약할 때 원어 제목을 그대로 두고 한국어 번역을 괄호로 붙인다.
- 중국 · 러시아 저널은 국제 색인 등재 여부(Scopus · Web of Science) 확인이 어렵다. 확인 못 하면 "국제 색인 등재 `미확인`" 으로 적는다.
