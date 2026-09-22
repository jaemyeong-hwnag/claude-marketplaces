---
name: java-name-create
description: Java 클래스·메서드·필드·상수·패키지 이름을 Java 컨벤션으로 짓는다. Java 코드를 새로 쓰거나 이름을 짓거나 바꿀 때, DTO·엔티티·서비스 이름을 정할 때 사용한다. 트리거 — ".java", "자바 이름", "클래스 이름", "메서드 이름", "변수명", "rename". 모양은 훅이 막고 단어 선택을 판단한다.
---

# Java 이름 짓기

규칙 원본: [`references/java-naming-rules.md`](../../references/java-naming-rules.md)
기계 검증: [`scripts/validate-java-naming.sh`](../../scripts/validate-java-naming.sh)

모양(케이스 · 파일 이름)은 훅이 막는다. 이 스킬은 **어떤 단어를 쓸지**를 정한다.

## 1. 모양 — 먼저 맞춘다

| 대상 | 모양 | 예 |
|---|---|---|
| 패키지 | 소문자, 밑줄 없음 | `com.example.ordercancel` |
| 타입 | UpperCamelCase, 파일 이름 = public 타입 | `OrderCancelService` |
| 메서드 · 필드 · 변수 · 매개변수 | lowerCamelCase | `cancelOrder`, `orderId` |
| 상수 (`static final` + 깊이 불변) · enum 상수 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `PAID` |
| 타입 매개변수 | 한 글자 또는 이름 + `T` | `T`, `RequestT` |
| 약어 | 한 단어처럼 | `HttpClient`, `userId`, `parseXml` |

## 2. 단어 — 이 순서로 판단한다

1. **무엇을 가리키는지 한 문장으로 말할 수 있는가.** `data` · `info` · `Manager` · `Util` · `process()` 는 말하지 않는다 → 다루는 것과 하는 일을 넣는다 (`OrderPriceCalculator`, `calculateTotal`)
2. **줄임말 금지.** `cnt` · `usr` · `svc` · `mgr` X. 업계 표준(`id`, `url`, `http`, `api`, `dto`)만
3. **역할 접미사 = 실제 역할.** `Service` · `Repository` · `Controller` · `Exception` · `Test` · `Request` · `Response` 는 그 역할일 때만
4. **boolean** — `is` · `has` · `can` · `should` + 형용사·과거분사 (`isPaid`, `hasItems`). 부정형(`isNotPaid`) 대신 반대 단어
5. **컬렉션은 복수형** — `orders`, `itemsById`. `orderList` · `orderArr` X
6. **메서드는 동사로** — `cancelOrder`, `findByEmail`, `toResponse`. 게터는 `getX` · boolean 은 `isX`
7. **같은 개념 = 같은 단어.** 코드베이스에서 이미 쓰는 단어를 먼저 찾는다 (`grep -r "fetch\|retrieve\|get" src`)

## 3. 절차

1. 대상이 무엇을 다루고 무엇을 하는지 한 문장으로 쓴다
2. 그 문장의 명사 · 동사로 이름을 만든다. 기존 코드에서 같은 개념의 단어를 찾아 맞춘다
3. 1절 모양으로 쓴다
4. 이름을 바꾸는 경우 — 참조를 모두 찾아 같이 바꾼다. public API 면 호환성을 먼저 확인한다

훅이 막으면 메시지의 **제안 이름**으로 고친다. 제안은 모양만 바꾼 것이므로 단어가 틀렸으면 2절로 다시 짓는다.

## 4. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-java-naming.sh" src/main/java
```

기존 위반은 훅이 막지 않는다 (새로 생긴 것만). 한꺼번에 고칠 때는 위 명령으로 찾는다.
