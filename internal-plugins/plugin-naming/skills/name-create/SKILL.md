---
name: name-create
description: 플러그인·스킬·커맨드·에이전트·코드 식별자의 이름을 짓거나 바꾸거나 검토할 때 사용한다. 새 플러그인/스킬/커맨드/에이전트를 만들 때, 디렉터리나 파일 이름을 정할 때, 변수·함수·클래스·API 필드 이름을 정할 때 자동으로 적용한다. 트리거 — "이름 뭐로", "네이밍", "이름 지어줘", "이름 바꿔", "플러그인 만들어", "스킬 만들어", "커맨드 추가", "rename", "naming", "what should I call". kebab-case {대상}-{관심사} 패턴과 glossary.json 사전을 강제한다.
---

# 이름 짓기

규칙 원본: [`references/naming-rules.md`](../../references/naming-rules.md)
단어 사전: [`references/glossary.json`](../../references/glossary.json)

## 순서

1. **개념을 한국어로 한 줄로 쓴다.** "네이밍 규칙을 검증하는 공통 플러그인"
2. **대상과 관심사로 쪼갠다.** 대상=공통, 관심사=naming
3. **각 단어를 사전에서 찾는다.**
   ```bash
   jq -r '.[][] | select(.use=="<단어>" or (.deny[]?=="<단어>")) | "use=\(.use) deny=\(.deny) (\(.meaning))"' \
     "${CLAUDE_PLUGIN_ROOT}/references/glossary.json"
   ```
   - `deny` 에 걸리면 그 항목의 `use` 로 바꾼다.
   - 사전에 없는 새 개념이면 `glossary-update` 스킬로 먼저 등록한다.
4. **조립한다.** `{대상}-{관심사}` / `common-{관심사}` / `{역할}-standard`
5. **검증한다.**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" <이름 또는 경로>
   ```

## 체크리스트

- [ ] kebab-case 인가 (소문자 + 하이픈)
- [ ] 두 단어 이상인가 (언어·프레임워크·범용 단어 단독 금지)
- [ ] 같은 단어가 두 번 나오지 않는가 (`spring-spring-boot-naming`)
- [ ] 줄임말이 없는가 — 있다면 공식 약어이고 glossary 에 등록돼 있는가
- [ ] 사전의 `deny` 단어를 쓰지 않았는가
- [ ] 이름만 보고 무엇을 하는지 알 수 있는가

## 코드 식별자에 적용할 때

사전은 **단어 선택**만 강제한다. 케이싱은 대상 언어 컨벤션을 따른다.

| 사전 | Java/Kotlin | 파일·디렉터리 | API 필드 |
|---|---|---|---|
| `create` + `order` | `createOrder` | `create-order` | `createOrder` |
| `start` + `datetime` | `startDatetime` | - | `startDatetime` |
| `duration` | `duration` | - | `duration` |

`from`/`to` 대신 `start`/`end`, `fetch` 대신 `get` 처럼 사전이 이미 정한 단어를 그대로 쓴다.

## 하지 말 것

- 사전에 없다고 임의로 동의어를 쓰지 않는다. 등록하거나, 등록된 단어를 쓴다.
- 이름이 길어진다고 줄이지 않는다. `document-sync` 는 되고 `doc-sync` 는 안 된다.
- 훅이 막았을 때 이름을 우회(`docs-sync`, `doc_sync`)하지 않는다. 사전이 지시한 `use` 단어로 바꾼다.
