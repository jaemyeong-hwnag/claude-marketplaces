---
name: domain-document-get
description: docs/domain 3계층(_index → _meta → concept)에서 필요한 도메인 지식만 골라 읽는다. 기능 구현·버그 분석·리뷰 전에 도메인 규칙을 알아야 할 때, 이 작업이 어느 도메인인지 판별할 때 사용한다. 트리거 — "도메인 문서", "도메인 규칙", "어느 도메인", "영향 도메인", "_index.md", "_meta.md".
---

# 도메인 문서 읽기

규칙 원본: [`references/domain-document-rules.md`](../../references/domain-document-rules.md) — 5절

문서 루트는 `docs/domain` (`DOMAIN_DOCUMENT_ROOT` 로 바뀐다). 루트가 없으면 이 스킬은 할 일이 없다 — 만들 거면 `domain-document-create`.

## 순서

1. **`_index.md`** 를 읽는다. 요청의 말 · 식별자 · 경로 · 증상을 트리거 칸과 맞춰 후보 도메인을 고른다
   - 키워드가 두 도메인에 걸리면 "겹칠 때" 표를 먼저 본다
   - 그래도 애매하면 후보 2 ~ 3개를 든다
2. 후보의 **`{slug}/_meta.md`** 를 읽는다. 파트 표의 "언제 본다" 로 concept 을 고른다
   - 여러 후보면 `_meta.md` 몇 개를 열어 직접 판단한다
3. 고른 **concept 만** 읽는다. 도메인 전체를 읽지 않는다
4. 검색(grep)도 같은 순서 — `_meta.md` 들에서 먼저, 좁힌 뒤 concept

## 무엇을 돌려주나

- 고른 도메인과 이유 (어떤 트리거에 걸렸나)
- 읽은 concept 경로와 이번 작업에 필요한 규칙 · 엔티티 · 흐름
- 영향 도메인 — `_meta.md` "관계" 에 나온 다른 도메인 중 이번 작업이 건드리는 것
- 문서에 없거나 코드와 다른 것 — **코드가 맞다.** 작업이 끝날 때 `domain-document-update` 로 고칠 목록으로 남긴다

## 하지 않을 것

- `_index.md` 를 건너뛰고 concept 을 바로 grep 하지 않는다 — 비슷한 이름의 다른 도메인을 읽는다
- 문서만 보고 코드를 단정하지 않는다. 문서가 가리키는 위치(파일 · 심볼)를 열어 확인한다
- 어느 도메인에도 안 걸리면 억지로 고르지 않는다. "도메인 문서 없음" 이라고 말하고 코드에서 찾는다
