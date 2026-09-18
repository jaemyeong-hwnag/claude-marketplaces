---
name: glossary-update
description: 네이밍 사전 glossary.json 에 단어를 추가·수정·삭제할 때 사용한다. 새 개념에 쓸 단어를 정할 때, 동의어를 금지어로 등록할 때, "이 단어 써도 되나" 판단할 때, 훅이 deny 단어를 막아서 사전을 고쳐야 할 때 자동으로 적용한다. 트리거 — "glossary", "사전에 추가", "단어 등록", "용어 정리", "이 단어 써도 되나", "deny 추가", "네이밍 사전". 중복 등록·정렬·구조 규칙을 지키며 검증까지 수행한다.
---

# 네이밍 사전 수정

대상 파일: [`references/glossary.json`](../../references/glossary.json)
규칙 원본: [`references/naming-rules.md`](../../references/naming-rules.md)

## 추가 전 반드시 검색

```bash
G="${CLAUDE_PLUGIN_ROOT}/references/glossary.json"
W=<추가하려는 단어>
jq -r --arg w "$W" 'to_entries[] | .key as $c | .value[]
  | select(.use==$w or (.deny[]?==$w)) | "\($c): use=\(.use) deny=\(.deny) — \(.meaning)"' "$G"
```

결과에 따라 갈린다.

| 결과 | 조치 |
|---|---|
| `use` 로 이미 있다 | 그대로 쓴다. 추가하지 않는다. |
| 다른 항목의 `deny` 에 있다 | 그 항목의 `use` 를 쓴다. 사전을 고치지 않는다. |
| 없는데 기존 항목과 같은 개념이다 | 그 항목의 `deny` 에 추가한다. |
| 없고 새로운 개념이다 | 해당 카테고리에 새 항목을 추가한다. |

## 항목 작성 규칙

```json
{ "use": "소문자 단일어 또는 복합어", "deny": ["소문자", "최소 1개"], "meaning": "한국어 한 줄" }
```

- 카테고리 안에서는 `use` 알파벳 순, 카테고리 자체도 알파벳 순으로 정렬한다.
- 한 단어를 두 카테고리에 중복 등록하지 않는다. `use` 와 `deny` 를 통틀어 모든 단어는 사전 전체에서 유일해야 한다.
- 사전에는 원형만 저장한다. 복수형·케이싱 변형은 넣지 않는다.

## 줄임말을 등록할 때

공식 약어만 `use` 로 등록할 수 있다. 등록 전에 근거를 확인한다.

- 공식 문서가 그 줄임말을 정식 명칭으로 쓰는가? (`k8s`, `api`, `sql`)
- 아니라면 등록하지 않고 전체 단어를 쓴다. (`doc` → `document`)
- 등록할 때는 풀네임을 `deny` 에 넣어 표기를 한쪽으로 고정한다.

## 수정 후 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --glossary
```

정렬·소문자·중복·`deny` 최소 1개·`meaning` 한 줄을 모두 검사한다. 종료 코드 0 이어야 끝난 것이다.
`PostToolUse` 훅이 glossary.json 저장 직후 같은 검증을 자동으로 돌린다.

## 파급 확인

단어를 `deny` 로 새로 막았다면 이미 그 단어를 쓰는 이름이 있는지 확인한다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --all .
```

기존 이름이 걸리면 사전 변경과 함께 이름도 고치거나, 등록을 재고한다.
