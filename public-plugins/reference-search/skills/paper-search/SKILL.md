---
name: paper-search
description: 논문 · 연구 결과 · 선행 연구 · 최신 동향 · SOTA · 메타분석을 분야 가리지 않고 찾을 때 사용한다. 출처별 에이전트(학술 색인 · 프리프린트 · 분야 DB · 국가 DB · 연구 동향)를 요청 깊이에 맞게 골라 병렬로 찾고 병합 · 검증한다. 트리거 — "논문 찾아", "선행 연구", "관련 연구", "최신 연구", "근거 있어", "paper", "literature".
---

# 논문 검색

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
| 늘 | `academic-index-searcher` |
| 심사 전 최신 연구가 필요하다 (기본으로 넣는다) | `preprint-searcher` |
| 분야가 뚜렷하다 (의학 · 법 · 교육 · 특허 · 학위논문 …) | `field-database-searcher` |
| 국내 · 한국 · 특정 나라 자료 | `regional-database-searcher` |
| "요즘 · 동향 · 화제 · 트렌드" | `research-trend-searcher` | <!-- document-slop-ignore -->
| 산업 적용 사례도 묻는다 | `company-blog-searcher` (기업 사례 스킬의 묶음) |

상한보다 많으면 절차 2절의 표대로 카탈로그를 얹어 합친다. 묶음을 버리지 않는다.

## 3. 찾는다

절차 4 ~ 8절 — 검색어 만들기 → 한 메시지에서 병렬로 띄우기 → 병합 → (깊게) 스노볼링 → 검증.
에이전트 없이 찾을 때(빠르게 · 개수 0)는 스킬이 직접 부른다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/reference-search.sh" openalex "<검색어>" --from <YYYY-MM-DD> --limit 8
```

## 4. 이 스킬에서 더 볼 것

- 서베이 · 체계적 리뷰를 먼저 찾아 분야 지도를 잡는다.
- 원조 논문 · 고전을 묻는 요청은 기간 제한을 풀고 피인용 순으로 본다.
- 의학 · 보건은 체계적 리뷰 · 메타분석 · 임상 가이드라인을 단일 연구보다 앞에 둔다.
- 결론 문장에 근거의 상태(심사 완료 · 프리프린트)를 같이 쓴다 (`RS-15`).

## 5. 낸다

절차 9절. 결과는 도구 결과에서 온 것만 쓴다 (`RS-10`). `.md` 로 쓰면 새 DOI · arXiv ID 를 훅이 확인한다.
