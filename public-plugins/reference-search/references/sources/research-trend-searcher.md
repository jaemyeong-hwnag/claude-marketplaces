# research-trend-searcher 출처 카탈로그

기준일 2026-10. 화제 논문, 학회 채택 · 수상 논문, 연구 동향 뉴스레터 · 커뮤니티 반응을 찾는다.

## 언제 쓰는가

- 띄운다: 화제 논문 요청, 특정 주간 · 월간 화제 논문, 학회(NeurIPS · CVPR 등) 채택 · Best Paper 목록, 어떤 논문에 대한 커뮤니티 반응.
- 띄운다: 한 분야의 흐름을 잡기 위해 뉴스레터 · 해설 기사가 필요할 때.
- 띄우지 않는다: 특정 주제의 논문을 빠짐없이 찾는 검색(`academic-index-searcher` · `field-database-searcher`), 프리프린트 서버 원문 검색(`preprint-searcher`).

## 출처

### 화제 논문 피드

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Hugging Face Papers (Daily) | `huggingface.co/papers` | 사용자가 올리고 추천한 AI 논문의 날짜별 목록. Daily · Weekly · Monthly 탭 | 무료 | `reference-search.sh huggingface`. 특정 날짜는 WebFetch `huggingface.co/papers/date/YYYY-MM-DD` |
| Hugging Face Trending Papers | `huggingface.co/papers/trending` | 코드 저장소가 붙은 화제 논문. Papers with Code 주소가 여기로 넘어온다 | 무료 | WebFetch `huggingface.co/papers/trending` |
| alphaXiv | `alphaxiv.org` | arXiv 논문 위 토론 · 화제 피드. 논문 주소는 `alphaxiv.org/abs/<arXiv ID>` | 무료 | WebFetch `alphaxiv.org/abs/<arXiv ID>` 로 토론 확인, WebSearch `site:alphaxiv.org 검색어` |
| Scholar Inbox | `scholar-inbox.com` | 튀빙겐대의 개인화 논문 추천 (arXiv 와 ML · CV · NLP 학회 OA 논문). 평가를 줘야 추천이 나온다 | 무료 (계정 필요) | 에이전트가 직접 쓰기 어렵다 — 사용자에게 안내만 |
| Papers with Code | `paperswithcode.com` | **종료** (2025-07). 주소는 Hugging Face Trending Papers 로 넘어간다. SOTA 리더보드는 대체되지 않았다 | - | 쓰지 않는다 |

### 학회 프로시딩 · 채택 목록

| 학회 | 분야 | 프로시딩 위치 | 찾는 방법 |
|---|---|---|---|
| NeurIPS | ML | `proceedings.neurips.cc` · `openreview.net` | `reference-search.sh openreview` · WebSearch `site:proceedings.neurips.cc 검색어` |
| ICML | ML | `proceedings.mlr.press` (PMLR) | WebSearch `site:proceedings.mlr.press 검색어` |
| ICLR | ML | `openreview.net` | `reference-search.sh openreview` |
| ACL · EMNLP · NAACL | NLP | `aclanthology.org` | WebSearch `site:aclanthology.org 검색어` |
| CVPR · ICCV | 비전 | `openaccess.thecvf.com` | WebSearch `site:openaccess.thecvf.com 검색어` |
| KDD · SIGMOD · SOSP · CHI | 데이터마이닝 · DB · 시스템 · HCI | `dl.acm.org` | WebSearch `site:dl.acm.org 학회명 검색어` |
| OSDI · NSDI · USENIX Security | 시스템 · 네트워크 · 보안 | `usenix.org/conferences` | WebSearch `site:usenix.org 검색어` |
| VLDB | DB | `vldb.org/pvldb` | WebSearch `site:vldb.org 검색어` |
| IEEE S&P · ICSE | 보안 · SE | `ieeexplore.ieee.org` · `computer.org` | WebSearch `site:ieeexplore.ieee.org 학회명 검색어` |
| 다른 분야 | 의학 (ASCO · AACR 연례회의 초록), 물리 (APS March Meeting), 지구과학 (AGU Fall Meeting) | 각 학회 사이트 | WebSearch `학회명 연도 abstracts 검색어` (구체 경로는 `미확인`) |

학회 연도 · 채택 결정 · 발표 형식(oral · spotlight · poster)을 결과에 같이 적는다.

### Best Paper

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Best Paper Awards in Computer Science | `jeffhuang.com/best_paper_awards` | CS 32개 학회의 1996 년 이후 Best Paper 목록, 해마다 갱신 (2026 수상 일부 반영 확인) | 무료 | WebFetch `jeffhuang.com/best_paper_awards/` |
| 각 학회 수상 발표 | 학회 사이트 · 블로그 | 해당 연도 수상작 | 무료 | WebSearch `학회명 연도 "best paper award"` |

### 뉴스레터 · 해설

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| The Batch | `deeplearning.ai/the-batch` | DeepLearning.AI 의 주간 AI 뉴스 | 무료 | WebSearch `site:deeplearning.ai/the-batch 검색어` |
| Import AI | `importai.substack.com` | Jack Clark 의 주간 AI 연구 해설 (2026 발행 확인) | 무료 | WebSearch `site:importai.substack.com 검색어` |
| Ahead of AI | `magazine.sebastianraschka.com` | Sebastian Raschka 의 LLM 연구 해설 (2026-05 글까지 확인) | 무료 일부 | WebSearch `site:magazine.sebastianraschka.com 검색어` |
| Last Week in AI | `lastweekin.ai` | 주간 AI 뉴스 · 팟캐스트. 2026 운영 여부 `미확인` | 무료 일부 | WebSearch `site:lastweekin.ai 검색어` |
| Nature Briefing | `nature.com/briefing` | Nature 편집자가 고른 평일 과학 뉴스 (2026-06 운영 확인) | 무료 | WebSearch `site:nature.com/articles "Nature Briefing" 검색어` |
| Quanta Magazine | `quantamagazine.org` | 수학 · 물리 · 생물 · CS 연구 해설 기사 (2026-10 발행 확인) | 무료 | WebSearch `site:quantamagazine.org 검색어` |

### 커뮤니티 반응

| 출처 | 도메인 | 다루는 것 | 접근 | 찾는 방법 |
|---|---|---|---|---|
| Hacker News | `news.ycombinator.com` · `hn.algolia.com` | 기술 커뮤니티의 논문 · 기사 토론 | 무료 | `reference-search.sh hackernews` |
| Reddit | `reddit.com` | r/MachineLearning 등 분야 서브레딧의 토론 | 무료 | WebSearch `site:reddit.com/r/MachineLearning 검색어` |

## 검색 문법과 요령

### Hugging Face Papers

- 논문 페이지는 `huggingface.co/papers/<arXiv ID>` 이다. 추천 수 · 저자 코멘트 · 연결된 모델 · 데이터셋 · Space 가 붙는다.
- 날짜별은 `huggingface.co/papers/date/YYYY-MM-DD`. Weekly · Monthly 탭의 주소 형식은 `미확인`.
- AI · ML 쪽에 치우쳐 있다. 다른 분야 화제성은 Quanta · Nature Briefing 으로 본다.

### alphaXiv

- arXiv 주소의 `arxiv.org` 를 `alphaxiv.org` 로 바꾸면 같은 논문의 토론 페이지가 열린다.
- 학회별 묶음 경로(`alphaxiv.org/conferences/neurips/2026`)가 있다.

### Hacker News (Algolia)

- 관련도순 `search` 와 날짜순 `search_by_date` 두 가지가 있다.
- `tags` 로 `story` · `comment` · `show_hn` · `ask_hn` · `front_page` 를 거른다. 숫자 필터 세부 문법은 스크립트 옵션을 따른다.
- 논문 제목이나 arXiv ID 로 찾으면 그 논문 토론 스레드가 나온다.

### Reddit

- r/MachineLearning 은 제목 앞 `[R]` (연구) · `[D]` (토론) · `[P]` (프로젝트) 말머리를 쓴다 (`미확인` — 이번에 확인하지 못했다).

### 요령

- "화제" 는 기간을 정해서 찾는다. 결과에 기준 날짜 · 기간(일 · 주 · 월)을 적는다.
- 피드에서 찾은 논문은 `preprint-searcher` · `academic-index-searcher` 로 원문 · 게재 상태를 확인하게 넘긴다.
- 뉴스레터 · 커뮤니티 글은 논문을 가리키는 길잡이로만 쓴다. 주장은 원 논문에서 확인한다.

## 결과에 붙일 상태

| 상태 | 붙이는 조건 |
|---|---|
| 화제 (출처 · 기간 · 지표) | 예: "HF Papers 2026-10 주간, 추천 312". 화제성은 질과 별개다 |
| 학회 채택 (학회 · 연도 · 형식) | 프로시딩 · OpenReview 에서 채택을 확인했다 |
| 수상 (학회 · 연도 · 상 이름) | 학회 발표 또는 Best Paper 목록에서 확인했다 |
| 프리프린트 | HF Papers · alphaXiv 에 오른 논문 대부분이 arXiv 프리프린트다 |
| 2차 해설 | 뉴스레터 · 기사 · 커뮤니티 글. 원 논문이 아니다 |

주의:

- HF Papers 추천 수 · HN 점수 · Reddit 추천은 홍보 · 소속 기관 규모에 좌우된다. 근거의 질로 쓰지 않는다.
- 학회 채택은 심사 완료지만 워크숍 논문은 본 학회 심사와 다르다. "워크숍" 을 따로 적는다.
- 뉴스레터는 저자 의견이 섞인다. 인용할 때 해설자 이름을 적는다.
