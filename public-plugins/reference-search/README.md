# reference-search

논문 · 연구 결과(분야 무관) · 다른 회사의 기술 사례 · 공식 문서 · 표준을 출처별 에이전트로 나눠 병렬로 찾는다 — 요청에 맞는 출처와 에이전트 수를 고르고, 키 없는 학술 API로 실제 메타데이터를 받아 병합 · 검증한다. 문서에 새로 쓰는 DOI · arXiv ID 가 실제로 없으면 차단한다.

| 층 | 무엇을 | 하는 것 |
|---|---|---|
| 1. 검색 | 스킬 3개 · 출처별 에이전트 10개 | 요청 깊이에 맞는 에이전트만 골라 한 번에 띄우고, 결과를 식별자로 병합한다 |
| 2. 검증 | `reference-reviewer` | 작성 맥락 없이 결과 표만 받아 항목마다 존재 · 지지를 판정한다 |
| 3. 차단 | PreToolUse 훅 | `.md` 에 새로 쓰는 DOI · arXiv ID 가 등록돼 있지 않으면 막는다 |

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install reference-search@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| paper-search | 논문 찾아 · 선행 연구 · 관련 연구 · 최신 연구 · 근거 있어 · paper · literature | 학술 색인 · 프리프린트 · 분야 DB · 국가 DB · 연구 동향 에이전트를 골라 찾는다. 서베이 우선, 깊게면 스노볼링 |
| company-reference-search | 다른 회사는 · 사례 찾아 · 기술 블로그 · 도입 사례 · 장애 사례 | 기업 블로그 · 발표 · 장애 사례 에이전트를 골라 찾는다. 회사 · 날짜 · 규모를 밝힌다 |
| technical-document-search | 공식 문서 · 스펙 · 표준 · RFC · 실제로 어떻게 쓰는지 | 공식 문서 · 표준과 코드 · 이슈 · 설계 문서 에이전트를 골라 찾는다. 문서 버전 · 폐기 여부를 밝힌다 |
| /reference-validate | 직접 호출 | 파일의 DOI · arXiv ID 존재 · 철회와 URL 상태를 확인한다 (`RS-01` ~ `RS-06`) |

## 포함된 에이전트

| 에이전트 | 설명 |
|---|---|
| academic-index-searcher | 전 분야 학술 색인(OpenAlex · Semantic Scholar · Crossref · Google Scholar 등). 스노볼링을 맡는다 |
| preprint-searcher | arXiv · bioRxiv · medRxiv · SSRN · OSF 등 프리프린트. 출판본이 나왔는지 확인한다 |
| field-database-searcher | 의학 · CS · 심리 · 경제 · 교육 · 인문 · 법 · 공학 · 화학 · 물리 · 특허 · 학위논문 DB 중 질문 분야에 맞는 것 |
| regional-database-searcher | 한국(RISS · KCI · DBpia · ScienceON 등) 우선, 일본 · 중국 · 유럽 · 중남미 DB 를 그 나라 말로 |
| research-trend-searcher | Hugging Face Papers · alphaXiv · 학회 Best Paper · 뉴스레터 · Hacker News 의 화제 논문과 주목도 근거 |
| company-blog-searcher | 국내외 기업 기술 블로그 · 아키텍처 사례 · 산업계 논문 · 기술 레이더 |
| conference-talk-searcher | 국내외 컨퍼런스 발표 영상 · 슬라이드 |
| postmortem-searcher | 장애 사후 분석 · incident report · 장애 회고 |
| official-document-searcher | 공식 문서 · 릴리스 노트 · RFC · W3C · ISO · NIST · OWASP |
| code-usage-searcher | GitHub 코드 · 이슈 · PR, KEP · PEP · Rust RFC · ADR |
| reference-reviewer | 병합한 결과 표만 받아 항목마다 존재(`확인` · `불일치` · `없음` · `철회`)와 지지(`지지` · `부분` · `아님`)를 판정한다. 결과를 고치지 않는다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| reference-validate.sh | PreToolUse (Write\|Edit\|MultiEdit) | `.md` 에 새로 생기는 DOI · arXiv ID 를 조회해 없으면 **막고** (`RS-01` · `RS-02`), 철회면 알리고 (`RS-03`), 확인하지 못하면 통과시키고 알린다 (`RS-04`) |

## 깊이와 에이전트 수

요청 복잡도로 깊이를 정하고, 사용자가 정한 값이 있으면 그것을 따른다.

| 깊이 | 에이전트 | 에이전트당 도구 호출 | 스노볼링 · 검증 |
|---|---|---|---|
| 빠르게 | 0 ~ 1개 | 3 ~ 10 | 스크립트 검증만 |
| 보통 | 2 ~ 4개 | 10 ~ 15 | `reference-reviewer` |
| 깊게 | 5 ~ 10개 | 10 ~ 15 | 스노볼링 한 번 + `reference-reviewer` |

- 요청에 `빠르게` · `깊게` · `에이전트 N개` · `arXiv 만` · `국내만` · `~ 빼고` 를 쓰면 그대로 따른다
- 기본값은 환경 변수로 둔다: `REFERENCE_SEARCH_DEPTH=quick|normal|deep`, `REFERENCE_SEARCH_MAX_AGENTS=<N>`
- 상한보다 묶음이 많으면 가까운 에이전트에 카탈로그를 얹어 합친다 — 출처를 버리지 않는다

## 출처와 키

`scripts/reference-search.sh` 는 키 없이 부른다: `openalex` · `openalex-citing` · `openalex-references` · `semantic-scholar` · `crossref` · `arxiv` · `biorxiv` · `medrxiv` · `pubmed` · `europepmc` · `openreview` · `huggingface` · `huggingface-daily` · `hackernews` · `rfc` · `github-repository` · `github-code` · `github-issue`.

- 키가 필요한 출처(KCI · RISS · ScienceON · NTIS · CORE · Unpaywall · IEEE · Springer · Scopus)는 넣지 않았다. 스크립트에 TODO 로 남겼고, 에이전트는 WebSearch `site:` 로 찾는다
- Semantic Scholar 와 arXiv 는 키 없이 부르면 요청 한도(429)에 자주 걸린다 (2026-10 개발 중 둘 다 429 를 받았다). 스크립트는 한 번 쉬고 다시 부른 뒤 종료 코드 6 과 대체 출처(OpenAlex)를 알린다
- `github-*` 은 `gh` 인증, `arxiv` 는 `xmllint` 가 필요하다

## 주의

- 훅은 **새로 생긴** 식별자만 본다 (Write 는 기존 파일에 없던 것, Edit 는 `old_string` 에 없던 것). 기존 문서를 고칠 때마다 전부 다시 조회하지 않는다
- 훅은 URL 을 보지 않는다. URL 은 `/reference-validate` 에서만 본다
- 인라인 코드 · 코드 펜스 안의 식별자는 예시로 보고 검사하지 않는다
- 네트워크가 없거나 한도에 걸리면 막지 않는다. 끄려면 `REFERENCE_VALIDATE=off`
- 있다고 확인한 식별자는 `${CLAUDE_PLUGIN_DATA}` 에 캐시한다. 없다고 나온 것은 캐시하지 않는다
- 에이전트 · 스킬의 `${CLAUDE_PLUGIN_ROOT}` 경로로 카탈로그 · 스크립트를 읽는다

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `RS-01` · `RS-02` | 새로 쓰는 DOI · arXiv ID 가 등록돼 있지 않다 | 차단 |
| `RS-03` | 철회된 논문 | 알림 |
| `RS-04` | 확인하지 못함 (네트워크 · 한도 · 상한) | 통과 + 알림 |
| `RS-05` · `RS-06` | URL 404 · 접근 제한 (`/reference-validate --urls`) | 실패 · 경고 |
| `RS-10` ~ `RS-20` | 도구 결과만 · 식별자 · 상태 · 경로 · 검색 기록 · 열어 본 요지만 · 병합 · 무게 · 철회 표시 · 기업 자료 날짜 · 검증 통과 · 깊이 · 지시 칸 (조항 순) | AI 판단 |

원본: [`references/reference-search-rules.md`](references/reference-search-rules.md) · 절차: [`references/search-orchestration.md`](references/search-orchestration.md) · 형식: [`references/result-schema.md`](references/result-schema.md) · 근거: [`references/reference-search-methods.md`](references/reference-search-methods.md) · 출처 카탈로그: [`references/sources/`](references/sources/)

## 사용

```bash
scripts/reference-search.sh openalex "agent memory" --from 2024-10-26 --limit 8
scripts/reference-search.sh openalex-citing 10.48550/arXiv.2005.11401
scripts/reference-validate.sh --urls docs/research.md
test/reference-validate.test.sh && test/reference-search.test.sh
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
