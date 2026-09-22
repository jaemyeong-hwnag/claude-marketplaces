# Kotlin 네이밍 규칙 (단일 원본)

Kotlin 코드(`*.kt`)의 **식별자 모양**을 정한다. 기계 검증은 [`scripts/validate-kotlin-naming.sh`](../scripts/validate-kotlin-naming.sh).

근거는 Kotlin 공식 문서 Coding conventions 의 Naming rules 절(Kotlin 언어 문서 · kotlinlang 사이트)이다. Android Kotlin style guide(Android 개발자 문서)는 참고만 한다 — `@Composable` 함수 이름처럼 공식 가이드가 허용한 범위에서만 따른다.
기계는 공식 가이드가 **분명히 정한 것만** 막는다. 관례가 갈리는 것은 경고하고, 단어를 고르는 일은 AI 가 판단한다 (4절).

`*.kts`(`build.gradle.kts` 같은 빌드 스크립트)는 보지 않는다.

## 1. 조항

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `KN-01` | 패키지 | 조각은 소문자로 시작한다. 여러 단어는 이어 붙이거나(`ordercancel`) camelCase(`orderCancel`) — 공식 컨벤션이 둘 다 허용한다. 밑줄 없음 | 대문자 시작은 차단, 밑줄은 경고 |
| `KN-02` | class · interface · object · enum class · annotation class · data / sealed / value class · fun interface · typealias | UpperCamelCase — `OrderService`, `PaymentState` | 차단 |
| `KN-03` | 파일 이름 | 최상위 선언이 클래스류 하나뿐이면 파일 이름 = 그 이름 (`OrderService.kt`). 그 밖에는 내용을 말하는 UpperCamelCase (`OrderExtensions.kt`) | 하나뿐일 때 차단, 그 밖은 경고 |
| `KN-04` | `const val` | SCREAMING_SNAKE_CASE — `MAX_RETRY_COUNT` | 차단 |
| `KN-05` | `fun` 이름 | lowerCamelCase — `cancelOrder`, `String.toSlug` | 차단 |
| `KN-06` | `val` · `var` (프로퍼티 · 지역 변수 · 생성자 프로퍼티) | 소문자로 시작하는 snake_case(`user_name`)를 쓰지 않는다 → `userName` | 차단 |
| `KN-07` | 타입 이름 안의 약어 | 대문자 4개 이상 연속이면 약어를 한 단어처럼 — `HttpClient` (`HTTPClient` X). 두 글자 약어는 대문자로 둔다 — `IOStream` | 경고 |

```kotlin
package com.example.order                                  // KN-01

const val MAX_RETRY_COUNT = 3                              // KN-04

class OrderCancelService(                                  // KN-02 · KN-03 (OrderCancelService.kt 가 아니면 경고 — const 가 함께 있다)
    private val orderRepository: OrderRepository,          // KN-06
) {
    private val _state = MutableStateFlow(OrderState.Idle) // KN-06 백킹 프로퍼티
    val state: StateFlow<OrderState> = _state

    suspend fun cancelOrder(orderId: Long) { }             // KN-05
}
```

KN-03 의 판단은 **편집 뒤 전체 내용**으로 한다. 최상위 선언은 중괄호 · 괄호 밖에서 시작하는 `class` · `interface` · `object` · `fun` · `val` · `var` · `typealias` 다. 클래스류가 하나이고 다른 최상위 선언이 없을 때만 파일 이름과 비교한다. 멀티플랫폼 접미사는 떼고 본다 — `Platform.jvm.kt` 는 `Platform`.

### 예외 — 막지 않는 것

| 경우 | 이유 |
|---|---|
| 이름 없는 `companion object` · `object : Runnable { }` 식 | 이름이 없다 |
| 백틱 이름 — ``fun `cancels paid order`()`` | 공식 가이드가 테스트에서 허용한다 |
| 테스트 경로(`/test/` · `/androidTest/` · `…Test/` 소스셋 · `*Test.kt` · `*Tests.kt`)의 함수 이름 밑줄 — `cancel_whenPaid_throws` | 공식 가이드가 테스트 메서드 이름의 밑줄을 허용한다 |
| `@Composable` 함수(같은 줄이나 바로 위 어노테이션 줄) — `OrderScreen()` | Compose 의 UI 함수는 UpperCamelCase 로 쓴다 |
| 반환 타입이 이름과 같은 팩터리 함수 — `fun Foo(x: Int): Foo` | 공식 가이드가 허용한다 |
| 백킹 프로퍼티 `_name` | 공식 가이드의 백킹 프로퍼티 이름이다 |
| SCREAMING_SNAKE_CASE `val` — `val DEFAULT_TIMEOUT = 30.seconds` | 최상위 · object 안의 깊이 불변 값은 이렇게 쓴다. 불변인지는 기계가 모른다 — AI 가 판단한다 |
| UpperCamelCase `val` — `val EmptyOrder = Order()` | 싱글턴 참조는 이렇게 쓴다 |
| `serialVersionUID` | 언어가 정한 이름이다 |
| 매개변수 · enum 상수 · 람다 매개변수 | 선언을 문법 없이 가려낼 수 없다. AI 가 판단한다 (enum 상수는 SCREAMING_SNAKE_CASE 나 UpperCamelCase) |
| `build/` · `target/` · `out/` · `.gradle/` · `generated/` · `node_modules/` · `.git/` | 생성물 · 의존성이다 |

주석(중첩 블록 주석 포함) · 문자열 · raw string(`"""…"""`) · 문자 리터럴 · 백틱 이름 안의 단어는 코드로 읽지 않는다.

## 2. 새로 생긴 위반만 막는다

훅은 편집 **전** 파일과 편집 **뒤** 내용을 둘 다 검사해 **늘어난 위반만** 막는다.

- `Write` — `content` 가 편집 뒤 내용이다. 파일이 이미 있으면 그 내용과 비교한다
- `Edit` — 현재 파일에 `old_string` → `new_string` 치환을 적용해 편집 뒤 내용을 만든다

레거시 파일의 다른 줄을 고치다가 기존 이름 때문에 막히지 않는다. 기존 위반을 고치고 싶으면 CLI 로 찾는다 (5절).

## 3. 차단과 경고

| | 훅 | CLI |
|---|---|---|
| 차단 조항 | 종료 코드 `2` + stderr — Claude 가 제안한 이름으로 다시 쓴다 | `❌` + 종료 코드 `2` |
| 경고 조항 | `additionalContext` 로 알린다 | `⚠️` + 종료 코드 `0` |

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-kotlin-naming.sh` | `KN-01` ~ `KN-07` — 모양 |
| 판단 | AI (`kotlin-name-create` 스킬) | 이름이 무엇을 가리키는지 말하는가, 단어 선택, 줄임말, 확장 함수 · Boolean · Flow · suspend 함수 이름 |

AI 가 판단할 것:

1. **이름만 보고 무엇인지 말할 수 있는가.** `process()`, `data`, `info`, `Manager`, `Util` 은 무엇을 다루는지 말하지 않는다. 파일 이름도 같다 — `Utils.kt` 보다 `OrderFormatting.kt`
2. **줄임말을 쓰지 않았는가.** `cnt` → `count`, `usr` → `user`. 업계 표준 약어(`id`, `url`, `http`, `api`)만 쓰고, 세 글자 이상이면 한 단어처럼 (`userId`, `HttpClient`)
3. **확장 함수는 수신 타입과 이어 읽히는가.** `String.toSlug()`, `Order.isCancellable()` — 수신 타입 이름을 함수 이름에 다시 넣지 않는다 (`String.stringToSlug` X)
4. **Boolean 프로퍼티는 참/거짓으로 읽히는가.** `isActive`, `hasItems`, `canCancel` — `flag`, `status` X. 부정형 대신 반대 단어
5. **함수는 동사, 변환은 `to` · `as`.** 새 객체를 만들면 `toDto()`, 같은 것을 다른 타입으로 보면 `asFlow()`. 상태를 바꾸면 동사(`sort`), 새 값을 돌려주면 과거분사(`sorted`)
6. **`Flow` · `suspend` 함수.** `Flow` 를 돌려주는 함수 · 프로퍼티는 무엇이 흐르는지 명사로 (`orders: Flow<List<Order>>`, `observeOrders()`). `suspend` 함수는 일반 함수처럼 동사로 — `Async` · `Suspend` 접미사를 붙이지 않는다
7. **팩터리 함수** 는 반환 타입과 같은 이름(`Foo(...)`)이나 `of` · `from` · `create` 로 — 그 밖에는 lowerCamelCase
8. **테스트 이름** 은 백틱 문장(``fun `cancels paid order`()``)이나 `given_when_then` 밑줄 — 한 프로젝트에서 하나로
9. **같은 개념에 같은 단어를 쓰는가.** 한 코드베이스에서 `fetch` · `get` · `load` 를 섞지 않는다

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-kotlin-naming.sh" src/main/kotlin/com/example/order/OrderService.kt  # 파일
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-kotlin-naming.sh" src/main/kotlin                                   # 디렉터리
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-kotlin-naming.sh" --all .                                           # 프로젝트 전체
```

종료 코드 `2` 가 위반이다. 경고만 있으면 `0` 이다.
