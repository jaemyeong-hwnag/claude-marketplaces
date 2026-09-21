---
name: name-create
description: 플러그인·스킬·커맨드·에이전트·코드 식별자의 이름을 짓거나 바꾸거나 검토할 때 사용한다. 새 플러그인/스킬/커맨드/에이전트를 만들 때, 디렉터리·파일·변수·함수·클래스·API 필드 이름을 정할 때 자동으로 적용한다. 트리거 — "이름 뭐로", "네이밍", "이름 지어줘", "rename", "naming". kebab-case {대상}-{범위}-{관심사}-{목적} 슬롯 패턴과 glossary.json 사전을 강제한다.
---

# 이름 짓기

규칙 원본: [`references/naming-rules.md`](../../references/naming-rules.md)
단어 사전: [`references/glossary.json`](../../references/glossary.json)

## 순서

1. **개념을 한국어로 한 줄로 쓴다.** "네이밍 규칙을 검증하는 공통 플러그인"
2. **슬롯으로 쪼갠다.** `{대상}-{범위}-{관심사}-{목적}` 중 필요한 것만, 이 순서로.
   - 대상=공통, 관심사=naming → `common-naming`
   - 대상=plugin, 관심사=structure, 목적=validate → `plugin-structure-validate`
3. **각 단어를 사전에서 찾는다.**
   ```bash
   jq -r '.[][] | select(.use=="<단어>" or (.deny[]?=="<단어>")) | "use=\(.use) deny=\(.deny) (\(.meaning))"' \
     "${CLAUDE_PLUGIN_ROOT}/references/glossary.json"
   ```
   - `deny` 에 걸리면 그 항목의 `use` 로 바꾼다.
   - 사전에 없는 새 개념이면 `glossary-update` 스킬로 먼저 등록한다.
4. **조립한다.** 슬롯 순서를 지킨다. `common-{관심사}` / `{역할}-standard` 도 그대로 쓴다.

   | 슬롯 | 어디서 오는가 | 사전 등록 |
   |---|---|---|
   | 대상·범위 | 도메인 고유명사 (`spring`, `notion`, `order`) | 필요 없다 |
   | 관심사 | 사전 `quality` 카테고리 | **필수** |
   | 목적 | 사전 `action`·`role` 카테고리 | **필수** |

   끝 단어는 항상 관심사 아니면 목적이므로 사전에 없으면 막힌다.
5. **검증한다.**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" <이름 또는 경로>
   ```

## 6. 통과해도 반드시 직접 판단한다

검증기는 정량 규칙만 본다. **통과는 시작이지 끝이 아니다.** `🤔 AI 가 판단할 것` 이 나오면 멈추고 판단한다.

핵심 질문 하나다 — **이름만 보고 무엇을 가리키는지 말할 수 있는가?**

| 이름 | 판단 | 고친 이름 |
|---|---|---|
| `plugin-structure-validate` | 무슨 구조인지 안 드러남 | `plugin-directory-structure` |
| `spring-name` | 무슨 이름인지 안 드러남 | `spring-project-name` |
| `notion-document-sync` | 노션 문서를 동기화한다 — 드러남 | 그대로 |

같은 단어라도 이름마다 답이 다르다. `spring-naming` 의 `naming` 은 충분하고, `spring-name` 의 `name` 은 모자라다.
**그래서 미리 표시해두지 않고 매번 판단한다.**

**옳지 않으면 이름을 다시 만든다.** 답이 안 나오면 이름을 굴리지 말고 무엇을 만드는지부터 다시 정한다.

## 체크리스트

- [ ] kebab-case 인가 (소문자 + 하이픈)
- [ ] 두 슬롯 이상 네 슬롯 이하인가
- [ ] 슬롯 순서가 `{대상}-{범위}-{관심사}-{목적}` 인가 (`review-standard` 처럼 뒤집히지 않았는가)
- [ ] 끝 단어가 사전에 `use` 로 등록돼 있는가
- [ ] 같은 단어가 두 번 나오지 않는가 (`spring-spring-boot-naming`)
- [ ] 줄임말이 없는가 — 있다면 공식 약어이고 glossary 에 등록돼 있는가
- [ ] 사전의 `deny` 단어를 쓰지 않았는가
- [ ] 이름만 보고 **무엇을** 다루는지 알 수 있는가 (`structure` → 무슨 구조인가)
- [ ] 이름만 보고 무엇을 하는지 알 수 있는가
- [ ] `🤔 AI 가 판단할 것` 항목을 그냥 넘기지 않았는가

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
