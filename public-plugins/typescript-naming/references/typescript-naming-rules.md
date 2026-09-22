# TypeScript 네이밍 규칙 (단일 원본)

TypeScript 소스 안의 **식별자 모양**을 정한다. 기계 검증은 [`scripts/validate-typescript-naming.sh`](../scripts/validate-typescript-naming.sh).

근거는 네 가지다.

- TypeScript 팀 Coding guidelines 의 Names 절 — 타입 이름은 PascalCase, 함수 · 프로퍼티 · 지역 변수는 camelCase, 인터페이스에 `I` 접두사를 붙이지 않는다, enum 값은 PascalCase
- TypeScript Handbook — 타입 매개변수를 `T` · `Type` 처럼 대문자로 시작해 쓰는 예
- typescript-eslint 의 `naming-convention` 규칙 기본값 — 기본은 camelCase, 변수는 camelCase · UPPER_CASE, 타입 계열은 PascalCase, 앞 · 뒤 밑줄 허용
- Google TypeScript Style Guide 의 Identifiers 절 — 클래스 · 인터페이스 · 타입 · enum · 타입 매개변수는 UpperCamelCase, 변수 · 함수 · 프로퍼티는 lowerCamelCase, 전역 상수와 enum 값은 CONSTANT_CASE, `I` 접두사와 앞 밑줄은 쓰지 않는다, 약어는 한 단어처럼(`loadHttpUrl`)

가이드가 한목소리로 정한 것(타입은 PascalCase, 값은 소문자 snake_case 가 아님)만 막는다.
가이드끼리 갈리는 것(enum 멤버 PascalCase 와 CONSTANT_CASE, 타입 매개변수 `T` 와 `TKey`)과 API 페이로드 때문에 예외가 흔한 것(class 멤버)은 경고하고, 단어를 고르는 일은 AI 가 판단한다 (4절).

이 규칙은 **TS 소스의 식별자**만 본다. 파일 이름 · `package.json` · 환경 변수 이름은 다루지 않는다.

## 1. 조항

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `TS-01` | class · abstract class · interface · type alias · enum · namespace (`export` · `export default` · `declare` 포함) | PascalCase — `OrderService`, `UserProps`, `OrderStatus` | 차단 |
| `TS-02` | interface | `I` 접두사를 붙이지 않는다 — `IUser` → `User` | 경고 |
| `TS-03` | `let` · `const` · `var` · `function` · `async function` 로 선언한 이름 | 소문자가 섞인 snake_case(`user_name`) 금지 → camelCase. UPPER_SNAKE 상수 · PascalCase · 앞뒤 밑줄은 허용 | 차단 |
| `TS-04` | enum 멤버 | PascalCase 또는 UPPER_SNAKE_CASE — `Paid`, `IN_PROGRESS` | 경고 |
| `TS-05` | 타입 매개변수 (함수 · class · interface · type 선언의 `<…>`) | `T` 한 글자, `T` + PascalCase(`TKey`), 또는 PascalCase(`Item`) | 경고 |
| `TS-06` | class 멤버 (접근 제어자 · `readonly` 로 시작하는 필드 · 메서드 · 생성자 매개변수 프로퍼티) | snake_case 를 쓰지 않는다 → camelCase | 경고 |

```ts
export interface OrderProps {                       // TS-01 · TS-02
  orderId: string;
}

export enum OrderStatus { Paid, Canceled }          // TS-01 · TS-04

const MAX_RETRY_COUNT = 3;                          // TS-03 (UPPER_SNAKE 허용)

export class OrderService<TOrder extends Order> {   // TS-01 · TS-05
  private readonly cancelCount = 0;                 // TS-06
  constructor(private readonly orderRepository: OrderRepository) {}

  async cancelOrder(orderId: string) {              // TS-03 · TS-06
    const canceledAt = new Date();
  }
}
```

### 예외 — 막지 않는 것

| 경우 | 이유 |
|---|---|
| UPPER_SNAKE 상수 — `const API_BASE_URL` | Google 가이드와 typescript-eslint 기본값이 허용한다 |
| PascalCase 값 — `const UserCard = () => …`, `const UserSchema = z.object(…)` | React 컴포넌트 · 스키마 · 클래스 참조 관례다 |
| 앞뒤 밑줄 — `_unused`, `__dirname` | 쓰지 않는 값 · 런타임이 정한 이름이다. 밑줄을 뺀 나머지만 본다 |
| 구조 분해 — `const { user_id } = body` | 이름이 API 페이로드에서 온다. 바꿔 받으려면 `{ user_id: userId }` — AI 가 판단한다 |
| `declare const` · `declare function` | 밖에서 정해진 이름을 옮긴 것이다 |
| interface · type 의 프로퍼티 — `{ created_at: string }` | API · DB 모양을 그대로 적는 일이 흔하다 |
| 접근 제어자 · `readonly` 없는 class 멤버, 객체 리터럴 키, 매개변수 | 선언을 문법 없이 가려낼 수 없다. AI 가 판단한다 |
| 여러 줄에 걸친 타입 매개변수 목록 · 한 선언의 두 번째 이후 변수(`let a = 1, b_c = 2`) | 줄 단위로 보기 때문이다 |
| `*.d.ts` · `*.d.mts` · `*.d.cts` | 외부 선언을 그대로 옮긴다 |
| `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` · `.git/` | 생성물 · 의존성이다 |

주석 · 문자열 · 템플릿 리터럴 안의 단어는 코드로 읽지 않는다. JSX 본문의 글(`This class is …`)은 선언 모양(`class Name {`)이 아니면 읽지 않는다.

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
| 정량 | `validate-typescript-naming.sh` | `TS-01` ~ `TS-06` — 모양 |
| 판단 | AI (`typescript-name-create` 스킬) | 이름이 무엇을 가리키는지 말하는가, 단어 선택, 타입과 값의 이름, 접미사, boolean, 유니언 리터럴, 약어 |

AI 가 판단할 것:

1. **이름만 보고 무엇인지 말할 수 있는가.** `data`, `info`, `Manager`, `Util`, `handle()` 은 무엇을 다루는지 말하지 않는다
2. **타입과 값의 이름이 부딪치지 않는가.** 같은 이름의 타입과 값(`const Order` + `type Order`)은 스키마에서 타입을 뽑을 때만 쓴다 (`const OrderSchema` → `type Order = z.infer<typeof OrderSchema>`)
3. **접미사가 역할과 맞는가.** React 컴포넌트의 props 는 `{컴포넌트}Props`, 상태는 `{컴포넌트}State`. `…Service` · `…Repository` · `…Dto` · `…Error` 는 그 역할일 때만
4. **boolean 은 참/거짓으로 읽히는가.** `isOpen`, `hasItems`, `canCancel`, `shouldRetry` — `flag`, `status` X. 부정형(`isNotValid`) 피하기
5. **유니언 리터럴 값의 케이스가 한 가지인가.** `type Status = "paid" | "canceled"` — 한 유니언 안에서 `"PAID" | "canceled"` 를 섞지 않는다. API 가 정한 값이면 그대로 둔다
6. **약어는 한 단어처럼.** `HttpClient`, `userId`, `parseJson` (`HTTPClient`, `userID` X). `id` · `url` · `api` · `http` 같은 업계 표준 약어만 쓴다
7. **컬렉션은 복수형, 맵은 `…ById`.** `orders`, `ordersById` — `orderList`, `orderArr` 보다 낫다
8. **같은 개념에 같은 단어를 쓰는가.** 한 코드베이스에서 `fetch` · `get` · `load` 를 섞지 않는다

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-typescript-naming.sh" src/order/order-service.ts  # 파일
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-typescript-naming.sh" src                         # 디렉터리
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-typescript-naming.sh" --all .                     # 프로젝트 전체
```

종료 코드 `2` 가 위반이다. 경고만 있으면 `0` 이다.
