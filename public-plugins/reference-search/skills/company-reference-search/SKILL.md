---
name: company-reference-search
description: 다른 회사가 어떤 기술을 어떻게 썼는지 — 기업 기술 블로그 · 컨퍼런스 발표 · 장애 사례 · 아키텍처 사례 · 기술 선택 동향을 찾을 때 사용한다. 출처별 에이전트를 요청 깊이에 맞게 골라 병렬로 찾고 병합 · 검증한다. 트리거 — "다른 회사는", "사례 찾아", "기술 블로그", "도입 사례", "장애 사례", "how do companies".
---

# 기업 기술 사례 검색

절차: [`search-orchestration.md`](../../references/search-orchestration.md) · 규칙: [`reference-search-rules.md`](../../references/reference-search-rules.md) · 형식: [`result-schema.md`](../../references/result-schema.md)

## 1. 깊이와 에이전트 수를 정한다

절차 2절대로 정한다. 사용자가 깊이 · 개수 · 출처를 말했으면 그것을 따른다 (`RS-19`). 시작할 때 기본값을 읽는다.

```bash
echo "${REFERENCE_SEARCH_DEPTH:-} ${REFERENCE_SEARCH_MAX_AGENTS:-}"
```

띄우기 전에 "깊이 · 띄울 에이전트 · 이유" 를 한 줄로 알린다.

## 2. 에이전트를 고른다

| 조건 | 에이전트 |
|---|---|
| 늘 | `company-blog-searcher` |
| 발표 영상 · 슬라이드가 도움이 된다 (보통 · 깊게면 넣는다) | `conference-talk-searcher` |
| 장애 · 실패 · 사후 분석 · 운영 교훈 | `postmortem-searcher` |
| 대규모 시스템 설계처럼 산업계 논문이 있을 만한 주제 | `academic-index-searcher` (논문 스킬의 묶음) |
| 도입한 기술의 공식 권장 방식과 비교해야 한다 | `official-document-searcher` (기술 레퍼런스 스킬의 묶음) |

상한보다 많으면 절차 2절의 표대로 카탈로그를 얹어 합친다. 묶음을 버리지 않는다.

## 3. 찾는다

절차 4 ~ 8절 — 검색어 만들기 → 한 메시지에서 병렬로 띄우기 → 병합 → (깊게) 스노볼링 → 검증.
에이전트 없이 찾을 때(빠르게 · 개수 0)는 스킬이 직접 부른다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/reference-search.sh" openalex "<검색어>" --from <YYYY-MM-DD> --limit 8
```

## 4. 이 스킬에서 더 볼 것

- 회사 이름이 주어지면 그 회사 원문을 먼저, 없으면 비슷한 규모 · 도메인의 회사를 찾는다.
- 국내 사례 요청은 국내 블로그 · 행사를 먼저 본다.
- 사례마다 회사 · 날짜 · 규모 수치(글에 있는 것만)를 밝히고, 3년 넘은 사례는 지금도 유효한지 `미확인` 으로 둔다 (`RS-17`).
- 홍보성 글은 결과 · 수치가 측정인지 주장인지 구분해 쓴다.

## 5. 낸다

절차 9절. 결과는 도구 결과에서 온 것만 쓴다 (`RS-10`). `.md` 로 쓰면 새 DOI · arXiv ID 를 훅이 확인한다.
