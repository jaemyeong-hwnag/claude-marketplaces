---
name: typescript-name-create
description: TypeScript 의 interface·type·class·enum·변수·함수·제네릭 이름을 TypeScript 관례로 짓는다. .ts·.tsx 코드를 쓰거나 이름을 짓거나 바꿀 때, props·타입 이름을 정할 때 사용한다. 트리거 — ".ts", ".tsx", "타입스크립트 이름", "interface 이름", "type 이름", "제네릭". 모양은 훅이 막고 단어 선택을 판단한다.
---

# TypeScript 이름 짓기

규칙 원본: [`references/typescript-naming-rules.md`](../../references/typescript-naming-rules.md)
기계 검증: [`scripts/validate-typescript-naming.sh`](../../scripts/validate-typescript-naming.sh)

모양(케이스)은 훅이 막는다. 이 스킬은 **어떤 단어를 쓸지**를 정한다.
파일 이름 · `package.json` · 환경 변수는 이 스킬이 다루지 않는다.

## 1. 모양 — 먼저 맞춘다

| 대상 | 모양 | 예 |
|---|---|---|
| class · interface · type · enum · namespace | PascalCase, interface 에 `I` 없음 | `OrderService`, `OrderProps`, `User` |
| 변수 · 함수 · 매개변수 · 메서드 · 프로퍼티 | camelCase | `cancelOrder`, `orderId` |
| 모듈 수준 상수 | UPPER_SNAKE_CASE 또는 camelCase (프로젝트 관례를 따른다) | `MAX_RETRY_COUNT` |
| React 컴포넌트 · 스키마 값 | PascalCase | `UserCard`, `UserSchema` |
| enum 멤버 | PascalCase (프로젝트가 UPPER_SNAKE 면 그쪽) | `OrderStatus.Paid` |
| 타입 매개변수 | `T` 또는 `T` + PascalCase | `T`, `TKey`, `TResponse` |
| 쓰지 않는 값 | 앞 밑줄 | `_event` |
| 약어 | 한 단어처럼 | `HttpClient`, `userId`, `parseJson` |

## 2. 단어 — 이 순서로 판단한다

1. **무엇을 가리키는지 한 문장으로 말할 수 있는가.** `data` · `info` · `Manager` · `Util` · `handle()` 은 말하지 않는다 → 다루는 것과 하는 일을 넣는다 (`OrderPriceCalculator`, `calculateTotal`)
2. **타입과 값 이름이 부딪치지 않게.** 스키마는 `UserSchema`, 거기서 뽑은 타입은 `User`. 같은 이름의 타입과 값은 의도했을 때만
3. **접미사 = 역할.** 컴포넌트 props 는 `{컴포넌트}Props`, 상태는 `{컴포넌트}State`, 요청 · 응답은 `…Request` · `…Response`. `Service` · `Repository` · `Dto` · `Error` 는 그 역할일 때만
4. **boolean** — `is` · `has` · `can` · `should` + 형용사·과거분사 (`isPaid`, `hasItems`). 부정형(`isNotPaid`) 대신 반대 단어
5. **유니언 리터럴은 한 케이스로.** `"paid" | "canceled"` 처럼 한 유니언 안에서 섞지 않는다. API 가 정한 값이면 그대로
6. **줄임말 금지.** `cnt` · `usr` · `svc` · `btn` X. 업계 표준(`id`, `url`, `api`, `http`, `dto`)만, 한 단어처럼 (`userId` — `userID` X)
7. **컬렉션은 복수형** — `orders`, `ordersById`. `orderList` · `orderArr` X
8. **함수는 동사로** — `cancelOrder`, `fetchUser`, `toResponse`. 이벤트 핸들러는 `handle…`, props 로 넘기는 콜백은 `on…`
9. **API 페이로드의 snake_case** — 경계에서 camelCase 로 바꾼다 (`const { user_id: userId } = body`). 그대로 받아야 하면 interface · type 프로퍼티로 두고 class 필드로 옮기지 않는다
10. **같은 개념 = 같은 단어.** 코드베이스에서 이미 쓰는 단어를 먼저 찾는다 (`grep -rE "fetch|load|get" src`)

## 3. 절차

1. 대상이 무엇을 다루고 무엇을 하는지 한 문장으로 쓴다
2. 그 문장의 명사 · 동사로 이름을 만든다. 기존 코드에서 같은 개념의 단어를 찾아 맞춘다
3. 1절 모양으로 쓴다
4. 이름을 바꾸는 경우 — 참조를 모두 찾아 같이 바꾼다. export 된 이름이면 쓰는 쪽(다른 패키지 · 공개 API)을 먼저 확인한다

훅이 막으면 메시지의 **제안 이름**으로 고친다. 제안은 모양만 바꾼 것이므로 단어가 틀렸으면 2절로 다시 짓는다.

## 4. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-typescript-naming.sh" src
```

기존 위반은 훅이 막지 않는다 (새로 생긴 것만). 한꺼번에 고칠 때는 위 명령으로 찾는다.
