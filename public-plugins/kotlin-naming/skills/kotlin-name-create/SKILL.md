---
name: kotlin-name-create
description: Kotlin 클래스·함수·프로퍼티·const·파일 이름을 Kotlin 컨벤션으로 짓는다. Kotlin 코드를 새로 쓰거나 이름을 짓거나 바꿀 때, data class·sealed class·확장 함수 이름을 정할 때 사용한다. 트리거 — ".kt", "코틀린 이름", "data class 이름", "companion object", "확장 함수 이름". 모양은 훅이 막고 단어 선택을 판단한다.
---

# Kotlin 이름 짓기

규칙 원본: [`references/kotlin-naming-rules.md`](../../references/kotlin-naming-rules.md)
기계 검증: [`scripts/validate-kotlin-naming.sh`](../../scripts/validate-kotlin-naming.sh)

모양(케이스 · 파일 이름)은 훅이 막는다. 이 스킬은 **어떤 단어를 쓸지**를 정한다.

## 1. 모양 — 먼저 맞춘다

| 대상 | 모양 | 예 |
|---|---|---|
| 패키지 | 소문자로 시작, 밑줄 없음 (camelCase 는 허용) | `com.example.ordercancel`, `com.example.orderCancel` |
| class · interface · object · typealias | UpperCamelCase | `OrderCancelService`, `PaymentState` |
| 파일 | 클래스 하나뿐이면 그 이름, 아니면 내용을 말하는 UpperCamelCase | `OrderCancelService.kt`, `OrderExtensions.kt` |
| `const val` · 깊이 불변인 최상위 / object `val` | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 함수 · 프로퍼티 · 지역 변수 · 매개변수 | lowerCamelCase | `cancelOrder`, `orderId` |
| 백킹 프로퍼티 | `_` + 공개 이름 | `_state` / `state` |
| 싱글턴 참조 `val` | UpperCamelCase 도 된다 | `val EmptyOrder = Order()` |
| `@Composable` 함수 · 팩터리 함수 | UpperCamelCase | `OrderScreen()`, `fun Order(id: Long): Order` |
| enum 상수 | SCREAMING_SNAKE_CASE 또는 UpperCamelCase — 프로젝트에 맞춘다 | `PAID`, `Paid` |
| 약어 | 두 글자는 대문자, 세 글자 이상은 한 단어처럼 | `IOStream`, `HttpClient`, `parseXml` |

이름 없는 `companion object` 는 그대로 둔다. 이름이 필요하면 역할로 (`companion object Factory`).

## 2. 단어 — 이 순서로 판단한다

1. **무엇을 가리키는지 한 문장으로 말할 수 있는가.** `data` · `info` · `Manager` · `Util` · `process()` 는 말하지 않는다 → 다루는 것과 하는 일을 넣는다 (`OrderPriceCalculator`, `calculateTotal`). 파일도 `Utils.kt` 대신 `OrderFormatting.kt`
2. **줄임말 금지.** `cnt` · `usr` · `svc` · `mgr` X. 업계 표준(`id`, `url`, `http`, `api`, `dto`)만
3. **역할 접미사 = 실제 역할.** `Repository` · `UseCase` · `ViewModel` · `Exception` · `Test` · `Request` · `Response` 는 그 역할일 때만. `data class` 는 담는 것 이름 (`OrderSummary`), sealed 계층은 상태 · 결과 이름 (`PaymentState.Paid`)
4. **확장 함수** — 수신 타입과 이어 읽힌다. `String.toSlug()`, `Order.isCancellable()`. 수신 타입 이름을 다시 넣지 않는다 (`Order.orderTotal` X → `Order.total`)
5. **Boolean 프로퍼티** — `is` · `has` · `can` · `should` + 형용사 · 과거분사 (`isPaid`, `hasItems`). 부정형(`isNotPaid`) 대신 반대 단어
6. **컬렉션은 복수형** — `orders`, `itemsById`. `orderList` X
7. **함수는 동사로** — `cancelOrder`, `findByEmail`. 변환은 `toX()`(새 객체) · `asX()`(보기), 상태를 바꾸면 `sort()`, 새 값이면 `sorted()`
8. **`Flow` · `suspend`** — `Flow` 는 흐르는 것을 명사로 (`orders: Flow<List<Order>>`) 또는 `observeX()`. `suspend fun` 은 일반 함수처럼 동사 — `Async` · `Suspend` 접미사 X
9. **팩터리** — 반환 타입과 같은 이름(`Order(...)`)이나 `of` · `from` · `create`
10. **테스트** — 백틱 문장(``fun `cancels paid order`()``)이나 `given_when_then`. 프로젝트에서 이미 쓰는 쪽
11. **같은 개념 = 같은 단어.** 코드베이스에서 이미 쓰는 단어를 먼저 찾는다 (`grep -rn "fun fetch\|fun load\|fun get" src`)

## 3. 절차

1. 대상이 무엇을 다루고 무엇을 하는지 한 문장으로 쓴다
2. 그 문장의 명사 · 동사로 이름을 만든다. 기존 코드에서 같은 개념의 단어를 찾아 맞춘다
3. 1절 모양으로 쓴다. 클래스 하나뿐인 파일은 파일 이름도 같이 정한다
4. 이름을 바꾸는 경우 — 참조를 모두 찾아 같이 바꾼다. public API 면 호환성을 먼저 확인한다 (`@Deprecated(ReplaceWith(...))`)

훅이 막으면 메시지의 **제안 이름**으로 고친다. 제안은 모양만 바꾼 것이므로 단어가 틀렸으면 2절로 다시 짓는다.

## 4. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-kotlin-naming.sh" src/main/kotlin
```

기존 위반은 훅이 막지 않는다 (새로 생긴 것만). 한꺼번에 고칠 때는 위 명령으로 찾는다.
