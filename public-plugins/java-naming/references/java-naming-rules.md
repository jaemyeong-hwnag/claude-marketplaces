# Java 네이밍 규칙 (단일 원본)

Java 코드의 **식별자 모양**을 정한다. 기계 검증은 [`scripts/validate-java-naming.sh`](../scripts/validate-java-naming.sh).

근거는 Google Java Style Guide 5장(Naming)과 Oracle Code Conventions for the Java Programming Language 9장이다. 둘이 다르면 Google 을 따른다.
기계는 두 가이드가 **분명히 정한 것만** 막는다. 관례가 갈리는 것은 경고하고, 단어를 고르는 일은 AI 가 판단한다 (4절).

## 1. 조항

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `JN-01` | 패키지 | 전부 소문자. 밑줄 없이 단어를 이어 붙인다 — `com.example.deepspace` | 대문자는 차단, 밑줄은 경고 |
| `JN-02` | 클래스 · 인터페이스 · enum · record · 어노테이션 | UpperCamelCase — `OrderService`, `ImmutableList` | 차단 |
| `JN-03` | public 최상위 타입 | 파일 이름과 같다 — `OrderService` 는 `OrderService.java` | 차단 |
| `JN-04` | `static final` 원시 타입 · `String` 필드 | UPPER_SNAKE_CASE — `MAX_RETRY_COUNT` | 차단 |
| `JN-05` | 메서드 · 필드 (접근 제어자로 시작하는 선언) | lowerCamelCase — `sendMessage`, `itemCount` | 차단 |
| `JN-06` | 타입 이름 안의 약어 | 한 단어처럼 쓴다 — `HttpClient`, `XmlParser` (`HTTPClient` X) | 경고 |

```java
package com.example.order;                       // JN-01

public class OrderCancelService {                // JN-02 · JN-03 (OrderCancelService.java)
    private static final int MAX_RETRY_COUNT = 3; // JN-04
    private final OrderRepository orderRepository; // JN-05

    public void cancelOrder(long orderId) { }     // JN-05
}
```

### 예외 — 막지 않는 것

| 경우 | 이유 |
|---|---|
| 테스트 메서드의 밑줄 — `cancel_whenPaid_throws` | Google 가이드가 JUnit 테스트 메서드 이름의 밑줄을 허용한다 |
| `serialVersionUID` | 언어가 정한 이름이다 |
| 원시 타입 · `String` 이 아닌 `static final` — `Logger log`, `List<String> names` | 깊이 불변인지 기계가 모른다. 상수면 UPPER_SNAKE_CASE, 아니면 lowerCamelCase — AI 가 판단한다 |
| 지역 변수 · 매개변수 · 접근 제어자 없는 멤버 | 선언을 문법 없이 가려낼 수 없다. AI 가 판단한다 |
| enum 상수 | enum 본문을 문맥 없이 가려낼 수 없다. UPPER_SNAKE_CASE 로 쓴다 |
| `package-info.java` · `module-info.java` | 파일 이름이 정해져 있다 |
| `build/` · `target/` · `out/` · `.gradle/` · `generated/` · `node_modules/` · `vendor/` | 생성물 · 의존성이다 |

주석과 문자열 리터럴 안의 단어는 코드로 읽지 않는다.

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
| 정량 | `validate-java-naming.sh` | `JN-01` ~ `JN-06` — 모양 |
| 판단 | AI (`java-name-create` 스킬) | 이름이 무엇을 가리키는지 말하는가, 단어 선택, 줄임말, 역할 접미사, boolean · 컬렉션 이름 |

AI 가 판단할 것:

1. **이름만 보고 무엇인지 말할 수 있는가.** `process()`, `data`, `info`, `Manager`, `Util` 은 무엇을 다루는지 말하지 않는다
2. **줄임말을 쓰지 않았는가.** `cnt` → `count`, `usr` → `user`. 업계 표준 약어(`id`, `url`, `http`, `api`)만 쓰고, 쓸 때는 한 단어처럼 (`userId`, `apiUrl`)
3. **역할 접미사가 역할과 맞는가.** `…Service` · `…Repository` · `…Controller` · `…Exception` · `…Test` 는 그 역할일 때만
4. **boolean 은 참/거짓으로 읽히는가.** `isActive`, `hasItems`, `canCancel` — `flag`, `status` X. 부정형(`isNotValid`) 피하기
5. **컬렉션은 복수형인가.** `orders`, `orderIdsByUser` — `orderList` 보다 `orders`
6. **메서드는 동사로 시작하는가.** `cancelOrder`, `findByEmail`, `toDto` — 게터는 `getX` · `isX`
7. **같은 개념에 같은 단어를 쓰는가.** 한 코드베이스에서 `fetch` · `get` · `retrieve` 를 섞지 않는다
8. **타입 매개변수** 는 대문자 한 글자(`T`, `E`, `K`, `V`)나 클래스 이름 + `T`(`RequestT`)

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-java-naming.sh" src/main/java/com/example/order/OrderService.java  # 파일
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-java-naming.sh" src/main/java                                      # 디렉터리
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-java-naming.sh" --all .                                            # 프로젝트 전체
```

종료 코드 `2` 가 위반이다. 경고만 있으면 `0` 이다.
