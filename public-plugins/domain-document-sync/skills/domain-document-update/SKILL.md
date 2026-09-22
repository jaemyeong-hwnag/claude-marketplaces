---
name: domain-document-update
description: 코드 변경을 docs/domain 도메인 문서에 반영한다 — concept 을 고치고 바뀐 경우만 _meta · _index 를 맞춘다. 도메인 코드를 고친 뒤, 동기 게이트(S-01)가 완료를 막을 때, 문서가 코드와 다를 때 사용한다. 트리거 — "문서 갱신", "도메인 문서 반영", "문서 동기", "S-01", "완료 보류".
---

# 도메인 문서 갱신

규칙 원본: [`references/domain-document-rules.md`](../../references/domain-document-rules.md) — 4 · 6절
골격: [`references/templates.md`](../../references/templates.md)

## 1. 무엇이 바뀌었나

```bash
git diff HEAD --stat
"${CLAUDE_PLUGIN_ROOT}/scripts/domain-document-sync.sh" map .   # 도메인별 code 글롭
```

바뀐 코드마다 걸리는 도메인을 찾고, 그 도메인의 `_meta.md` → 관련 concept 을 읽는다 (`domain-document-get` 순서).

## 2. 도메인 지식이 바뀌었나

| 바뀐 것 | 판정 |
|---|---|
| 규칙 · 계산 · 검증 · 권한 | 문서 고침 |
| 엔티티 · 필드 · 상태값 · 테이블 · 관계 | 문서 고침 |
| 흐름 · 순서 · 상태 전이 · 외부 계약(API · 이벤트) | 문서 고침 |
| 코드 위치 이동 (파일 · 모듈 이름) | `_meta.md` 위치 · `code:` 고침 |
| 내부 리팩터 · 이름 정리 · 테스트 · 포맷 · 로그 | 안 고침 → 면제 |

## 3. 고친다 — 아래에서 위로

1. **concept** — 바뀐 사실만 고친다. 코드에서 확인한 것을 위치(파일 · 심볼)와 함께. 없어진 규칙은 지운다
2. **`_meta.md`** — 파트가 늘거나 나뉘었을 때, "언제 본다" · 관계 · `code:` 가 바뀌었을 때만
3. **`_index.md`** — 도메인 한 줄 · 트리거가 바뀌었을 때만. 새 식별자 · 경로 · 증상 문구가 생겼으면 트리거에 흘려 넣는다
4. concept 이 300줄을 넘으면 "언제 보는가" 기준으로 나누고 `_meta.md` 파트 표에 등재한다

안 바뀐 계층은 건드리지 않는다.

## 4. 확인

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/domain-document-sync.sh" validate .
```

`❌` 가 없어야 끝이다.

## 5. 면제

도메인 지식이 그대로면 문서를 억지로 고치지 않는다. **사용자에게 이유를 한 줄로 알린 뒤** 차단 메시지가 알려준 면제 파일에 쓴다.

```bash
echo 'n/a {slug}' >> "{차단 메시지의 .ack 경로}"    # 모든 도메인이면 'n/a'
```

면제는 그 요청에만 유효하다. 알리지 않고 면제하지 않는다.
