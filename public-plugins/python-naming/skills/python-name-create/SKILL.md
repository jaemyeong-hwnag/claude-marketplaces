---
name: python-name-create
description: Python 모듈·클래스·함수·변수 이름을 PEP 8 로 짓는다. 파이썬 코드를 새로 쓰거나 이름을 짓거나 바꿀 때, 모듈 파일 이름을 정할 때 사용한다. 트리거 — ".py", "파이썬 이름", "PEP 8", "snake_case", "모듈 이름", "함수 이름". 모양은 훅이 막고 단어 선택을 판단한다.
---

# Python 이름 짓기

규칙 원본: [`references/python-naming-rules.md`](../../references/python-naming-rules.md)
기계 검증: [`scripts/validate-python-naming.sh`](../../scripts/validate-python-naming.sh)

모양(케이스 · 모듈 파일 이름)은 훅이 막는다. 이 스킬은 **어떤 단어를 쓸지**를 정한다.

## 1. 모양 — 먼저 맞춘다

| 대상 | 모양 | 예 |
|---|---|---|
| 모듈 파일 · 패키지 | 소문자 snake_case, 하이픈 없음. 패키지는 밑줄 없이 짧게 | `order_service.py`, `orders/` |
| 클래스 | CapWords (약어는 대문자 그대로) | `OrderService`, `HTTPServer` |
| 예외 클래스 | CapWords + `Error` | `OrderNotFoundError` |
| 함수 · 메서드 · 변수 · 매개변수 | snake_case | `cancel_order`, `order_id` |
| 모듈 수준 상수 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 내부용 | 앞 밑줄 하나 | `_parse_row`, `_cache` |
| 이름 맹글링 | 앞 밑줄 둘 (서브클래스 충돌을 피할 때만) | `__token` |
| 첫 매개변수 | 인스턴스 `self`, 클래스 메서드 `cls` | `def create(cls, …)` |
| TypeVar | 짧은 CapWords, 변성은 접미사 | `T`, `KT`, `T_co`, `T_contra` |
| 내장 이름과 겹칠 때 | 뒤 밑줄 하나 | `id_`, `type_`, `class_` |

## 2. 단어 — 이 순서로 판단한다

1. **무엇을 가리키는지 한 문장으로 말할 수 있는가.** `data` · `info` · `manager` · `utils.py` · `helpers.py` · `process()` 는 말하지 않는다 → 다루는 것과 하는 일을 넣는다 (`order_price.py`, `calculate_total`)
2. **줄임말 금지.** `cnt` · `usr` · `svc` · `mgr` X. 업계 표준(`id`, `url`, `http`, `api`)과 관용 이름(`i`, `df`, `np`, `pd`)만
3. **내장 이름을 가리지 않는다.** `list` · `dict` · `id` · `type` · `input` · `filter` · `format` · `hash` · `sum` 을 변수로 쓰지 않는다. 먼저 더 구체적인 이름(`order_ids`, `event_type`), 그래도 그 이름이어야 하면 `id_`
4. **밑줄 접두사 = 공개 범위.** 모듈 밖에서 쓰지 않으면 `_name`. `__name` 은 "private" 이라는 뜻으로 쓰지 않는다 — 맹글링이 필요할 때만. `__x__` 는 새로 만들지 않는다
5. **boolean** — `is_` · `has_` · `can_` · `should_` + 형용사·과거분사 (`is_paid`, `has_items`). 부정형(`is_not_paid`) 대신 반대 단어
6. **컬렉션은 복수형** — `orders`, `items_by_id`. `order_list` · `order_dict` X
7. **함수는 동사로** — `cancel_order`, `find_by_email`, `to_dict`. `@property` 는 명사 (`total`, `is_empty`)
8. **같은 개념 = 같은 단어.** 코드베이스에서 이미 쓰는 단어를 먼저 찾는다 (`grep -rn "def fetch_\|def get_\|def retrieve_" .`)

## 3. 절차

1. 대상이 무엇을 다루고 무엇을 하는지 한 문장으로 쓴다
2. 그 문장의 명사 · 동사로 이름을 만든다. 기존 코드에서 같은 개념의 단어를 찾아 맞춘다
3. 1절 모양으로 쓴다
4. 이름을 바꾸는 경우 — 참조를 모두 찾아 같이 바꾼다. 모듈 파일을 바꾸면 `import` 문 · 문자열로 적힌 경로(설정 · `entry_points`)도 바꾼다. 공개 API 면 호환성(옛 이름 별칭)을 먼저 확인한다

훅이 막으면 메시지의 **제안 이름**으로 고친다. 제안은 모양만 바꾼 것이므로 단어가 틀렸으면 2절로 다시 짓는다.
외부 라이브러리의 camelCase 메서드를 재정의해야 하면 `@override` 를 붙이거나 그 줄에 `# noqa: N802` 를 붙인다 — 이름을 바꾸면 부모가 부르지 못한다.

## 4. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-python-naming.sh" app
```

기존 위반은 훅이 막지 않는다 (새로 생긴 것만). 한꺼번에 고칠 때는 위 명령으로 찾는다.
