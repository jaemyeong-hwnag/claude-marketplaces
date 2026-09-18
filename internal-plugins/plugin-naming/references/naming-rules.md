# 네이밍 규칙 (단일 원본)

이 문서가 이름에 대한 유일한 기준이다. 스킬·에이전트·훅은 모두 이 문서를 참조한다.
단어 사전은 [`glossary.json`](./glossary.json), 기계 검증은 [`scripts/validate-naming.sh`](../scripts/validate-naming.sh).

## 1. 형식

- kebab-case (소문자 + 하이픈)만 사용한다.
- 슬롯은 `{대상}-{범위}-{관심사}-{목적}` 네 개다. **필요한 슬롯만 쓰되 순서는 바꾸지 않는다.**
- 최소 두 슬롯, 최대 네 슬롯.

| 슬롯 | 뜻 | 사전 카테고리 | 예 |
|---|---|---|---|
| 대상 | 무엇을 다루는가 | `artifact`·`platform`·`abbreviation`·`time`·**미등록** | `plugin`, `spring`, `notion` |
| 범위 | 대상 안에서 어디까지인가 | 위와 같음 | `document`, `config` |
| 관심사 | 어떤 성질을 보는가 | `quality` | `naming`, `coverage`, `standard` |
| 목적 | 무엇을 하려는가 | `action`·`role` | `validate`, `create`, `sync`, `reviewer` |

```
plugin-naming               대상 + 관심사
name-create                 대상 + 목적
spring-naming               대상 + 관심사
notion-document-sync        대상 + 범위 + 목적
document-naming-validate    대상 + 관심사 + 목적
```

- 공통 플러그인은 `common-{관심사}`.
  - `common-test`, `common-logging`
- 번들 플러그인은 `{역할}-standard`.
  - `backend-standard`, `frontend-standard`

다섯 단어 이상은 막는다. 길어지면 슬롯을 더하지 말고 대상을 좁힌다.

### 슬롯은 사전 카테고리로 판정한다

단어가 어느 슬롯인지는 `glossary.json` 의 **카테고리**가 정한다. 그래서 순서를 기계가 검사할 수 있다.

- `action`·`role` → 목적
- `quality` → 관심사
- 그 밖의 카테고리와 미등록 단어 → 대상·범위

왼쪽에서 오른쪽으로 등급이 커지기만 해야 한다. `review-standard`(목적 뒤에 관심사), `glossary-update-plugin`(목적 뒤에 대상)은 막힌다.

### 끝 단어만 사전에 등록돼야 한다

끝 단어는 항상 `{관심사}` 아니면 `{목적}` 이므로 **사전에 `use` 로 등록돼 있어야 한다.**
앞 단어(`{대상}`·`{범위}`)는 `spring`·`kotlin`·`notion`·`order` 같은 도메인 고유명사라 사전이 통제하지 않는다.

사전이 모든 프레임워크·제품명을 담을 수는 없다. 통제할 가치가 있는 건 "무엇을 보고 무엇을 하는가"를 말하는 뒷부분이다.

적용 대상: 플러그인명, 스킬명, 커맨드명, 에이전트명, 그리고 코드 식별자(케이싱은 각 언어 컨벤션을 따르되 단어 선택은 동일).

## 2. 금지

| 금지 | 예 |
|---|---|
| 언어명 단독 사용 | `java`, `kotlin`, `react` |
| 프레임워크명 단독 사용 | `spring`, `nextjs` |
| 맥락 중복 | `spring-spring-boot-naming` |
| 슬롯 다섯 개 이상 | `plugin-document-config-naming-review` |
| 슬롯 순서 위반 | `review-standard`, `glossary-update-plugin` |
| 끝 단어가 사전에 없음 | `plugin-banana`, `order-service` |

단독 사용이 금지된 단어라도 구성 단어로는 쓸 수 있다: `spring-naming` (O), `spring` (X).

### 검증 방식

금지 단어를 목록으로 열거하지 않는다. 목록은 새 언어·프레임워크(`rails`, `laravel`, `gradle`)를 놓친다.
대신 **한 단어짜리 이름을 종류를 불문하고 막는다.** "단독 사용 금지"는 곧 구조 규칙이므로, 단어를 몰라도 전부 걸린다.

단어 수준의 금지는 `glossary.json` 의 `deny` 가 담당한다. 새로 막고 싶은 단어가 생기면 스크립트가 아니라 사전에 추가한다.

구조와 사전으로 잡히지 않는 것(`spring-boot` 처럼 프레임워크 풀네임을 그대로 쓴 2단어 이름 등)은 `naming-reviewer` 가 사람 기준으로 판정한다.

## 3. 원칙

- 의도가 이름만으로 파악될 것.
- 발음과 검색이 쉬울 것.
- 동일 개념에는 동일 단어를 쓸 것 (→ `glossary.json`).

## 4. 줄임말

- 원칙적으로 금지.
- 예외는 해당 기술·프로젝트가 **공식적으로 정식 명칭으로 쓰는** 약어, 또는 업계 표준 약어뿐이다.
- 판단 기준: *공식 문서가 그 줄임말을 정식 명칭으로 쓰는가?*
  - 허용: `k8s` (Kubernetes 공식), `api` (업계 표준)
  - 금지: `doc` (document 의 공식 약어가 아님), `repo`, `cfg`
- 허용된 줄임말은 반드시 `glossary.json` 에 `use` 로 등록해 관리한다. 끝 단어라면 **차단**되고, 앞 단어라면 3자 이하일 때 경고한다.

## 5. 사전 (glossary.json)

사전은 아래 순서로 해석된다. 프로젝트가 자기 사전을 가지면 플러그인 기본 사전을 대신한다.

| 순위 | 위치 | 용도 |
|---|---|---|
| 1 | `$NAMING_GLOSSARY` | 테스트·일회성 검증 |
| 2 | `$CLAUDE_PROJECT_DIR/references/glossary.json` | 프로젝트 전용 사전 |
| 3 | `${CLAUDE_PLUGIN_ROOT}/references/glossary.json` | 플러그인 기본 사전 |

프로젝트 사전을 두면 플러그인 사전은 **병합되지 않고 대체된다.** 공통 단어까지 포함해 복사한 뒤 도메인 단어를 더한다.

- 끝 단어는 `glossary.json` 의 `use` 단어만 사용한다. 앞 단어는 도메인 고유명사를 허용한다.
- `deny` 목록의 단어는 위치를 가리지 않고 플러그인명·스킬명·커맨드명·에이전트명에 쓸 수 없다.
- `validate-naming.sh` 가 deny 사용·끝 단어 미등록·슬롯 순서를 자동으로 막는다.
- 새 관심사·목적 단어가 필요하면 이름을 비틀지 말고 `glossary-update` 스킬로 먼저 등록한다.

**카테고리가 곧 슬롯이다.** 새 항목을 추가할 때 카테고리를 잘못 고르면 슬롯 판정이 틀어진다.
`meaning` 에는 단어의 뜻만 적는다 — 이번 용례나 대상을 섞어 쓰지 않는다 (`structure` 는 "구성 요소의 배치 구조"이지 "디렉터리 구조"가 아니다).

### 값 규칙

- `use`, `deny` 값은 모두 소문자.
- 사전은 원형만 저장한다. 케이싱은 적용 대상의 컨벤션을 따른다 (`create` → `createOrder`, `CreateOrderRequest`).

### 항목 규칙

- `use`: 소문자 단일 단어 또는 복합어
- `deny`: 소문자 배열, 최소 1개
- `meaning`: 한국어, 한 줄 이내
- 카테고리별로 `use` 알파벳 순 정렬, 카테고리 자체도 알파벳 순 정렬

### 추가 규칙

- 새 단어를 추가하기 전에 `deny` 전체를 먼저 검색한다.
- 기존 항목의 동의어이면 그 항목의 `deny` 에 추가한다.
- 새로운 개념이면 새 항목으로 추가한다.
- 하나의 단어를 여러 카테고리에 중복 등록하지 않는다.

### 구조

```json
{
  "{카테고리}": [
    {
      "use": "사용할 단어",
      "deny": ["금지 동의어1", "금지 동의어2"],
      "meaning": "의미 설명"
    }
  ]
}
```

## 6. 검증

```bash
# 이름 하나 또는 경로
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" plugins/spring-naming
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" order-service

# 저장소 전체
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --all .

# 사전 구조만
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --glossary
```

종료 코드 `2` 는 규칙 위반이다. `Write`/`Edit` PreToolUse 훅에 연결돼 있어 위반하는 이름으로는 파일이 만들어지지 않는다.
