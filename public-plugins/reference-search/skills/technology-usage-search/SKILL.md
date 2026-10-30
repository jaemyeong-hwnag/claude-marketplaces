---
name: technology-usage-search
description: 공식 문서 · 릴리스 노트 · 마이그레이션 가이드 · 표준(RFC · W3C · ISO · NIST · OWASP) · 실제 사용 코드 · 이슈 · 설계 문서(KEP · PEP)를 찾을 때 사용한다. 출처별 에이전트를 요청 깊이에 맞게 골라 병렬로 찾고 검증한다. 트리거 — "공식 문서", "스펙", "표준", "RFC", "레퍼런스 찾아", "실제로 어떻게 쓰는지", "official docs".
---

# 기술 레퍼런스 검색

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
| 늘 | `official-document-searcher` |
| 실제 사용법 · 알려진 버그 · 설계 이유 · 문서에 없는 동작 | `code-usage-searcher` |
| 다른 회사의 운영 경험도 묻는다 | `company-blog-searcher` (기업 사례 스킬의 묶음) |

상한보다 많으면 절차 2절의 표대로 카탈로그를 얹어 합친다. 묶음을 버리지 않는다.

## 3. 찾는다

절차 4 ~ 8절 — 검색어 만들기 → 한 메시지에서 병렬로 띄우기 → 병합 → (깊게) 스노볼링 → 검증.
에이전트 없이 찾을 때(빠르게 · 개수 0)는 스킬이 직접 부른다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/reference-search.sh" openalex "<검색어>" --from <YYYY-MM-DD> --limit 8
```

## 4. 이 스킬에서 더 볼 것

- 버전이 있는 질문은 그 버전의 문서를 찾고, 문서 버전을 결과에 밝힌다.
- 표준은 폐기 · 갱신(obsoleted · updated by) 여부를 확인한다 (`RS-16`).
- 빠르게 깊이의 단순 확인(옵션 하나, 표준 번호 하나)은 에이전트 없이 WebSearch · WebFetch · `reference-search.sh rfc` 로 끝낸다.
- 문서와 코드가 다르면 둘 다 적고 어느 쪽이 실제 동작인지 근거를 단다.

## 5. 낸다

절차 9절. 결과는 도구 결과에서 온 것만 쓴다 (`RS-10`). `.md` 로 쓰면 새 DOI · arXiv ID 를 훅이 확인한다.
