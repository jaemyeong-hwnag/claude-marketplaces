---
name: node-name-create
description: Node.js 프로젝트의 npm 패키지 이름 · npm script · 환경 변수 · JS 변수 · 함수 · 클래스 · 파일 이름을 npm 규칙과 JS 관례로 짓는다. package.json 을 만들거나 .js · .mjs 코드를 쓰거나 환경 변수 이름을 정할 때 사용한다. 트리거 — "package.json", "npm 패키지 이름", "npm script", "환경 변수 이름", "process.env", ".js", ".mjs".
---

# Node.js 이름 짓기

규칙 원본: [`references/node-naming-rules.md`](../../references/node-naming-rules.md)
기계 검증: [`scripts/validate-node-naming.sh`](../../scripts/validate-node-naming.sh)

모양(케이스 · npm 규칙)은 훅이 막는다. 이 스킬은 **어떤 단어를 쓸지**를 정한다.
TypeScript 소스의 식별자는 `typescript-naming` 이 맡는다. 여기서는 TS 의 환경 변수만 본다.

## 1. 모양 — 먼저 맞춘다

| 대상 | 모양 | 예 |
|---|---|---|
| npm 패키지 (`package.json` 의 `name`) | 소문자 kebab-case, 214자 이하, 스코프는 `@scope/name` | `order-service`, `@acme/order-service` |
| npm script | 소문자, `-` 와 `:` 로 잇는다 | `test:unit`, `build-prod`, `db:migrate` |
| CLI 명령 (`bin` 키) | 소문자 kebab-case, 짧게 | `order-cli` |
| 환경 변수 | UPPER_SNAKE_CASE, 서비스 접두사 | `ORDER_DB_URL`, `ORDER_API_TIMEOUT_MS` |
| 변수 · 함수 · 매개변수 | camelCase | `userName`, `cancelOrder` |
| 상수 (모듈 최상위의 고정값) | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 클래스 · 생성자 · 컴포넌트 | PascalCase | `OrderService`, `OrderCard` |
| 파일 | kebab-case 또는 export 이름(camelCase · PascalCase) — 프로젝트의 기존 관례를 따른다. 역할은 점 접미사. 밑줄 X | `order-service.js`, `OrderCard.js`, `order-service.test.js` |
| React 컴포넌트 파일 (`.jsx`) | PascalCase 도 된다 — 프로젝트 관례를 따른다 | `OrderCard.jsx` |
| 약어 | 변수 · 함수에서는 한 단어처럼 | `userId`, `apiUrl`, `parseJson` |

## 2. 단어 — 이 순서로 판단한다

1. **무엇을 가리키는지 한 문장으로 말할 수 있는가.** `data` · `info` · `utils` · `helper` · `handle()` 은 말하지 않는다 → 다루는 것과 하는 일을 넣는다 (`orderPriceCalculator`, `calculateTotal`)
2. **줄임말 금지.** `cnt` · `usr` · `cfg` · `msg` X. 업계 표준(`id`, `url`, `http`, `api`, `db`, `env`)만
3. **환경 변수는 접두사로 서비스 · 대상을 구분한다.** `ORDER_DB_URL` · `ORDER_DB_POOL_SIZE` — 같은 대상은 같은 접두사로 묶는다. 단위를 이름에 넣는다 (`…_TIMEOUT_MS`, `…_TTL_SECONDS`), 켜고 끄는 값은 `…_ENABLED`. `NODE_ENV` · `PORT` 처럼 플랫폼이 정한 이름은 그대로 쓴다
4. **모듈 파일 이름 = 대표 export.** `order-service.js` → `OrderService`, `format-price.js` → `formatPrice`. 파일 하나가 여러 개념을 export 하면 나눈다
5. **패키지 · CLI 이름.** 패키지 이름은 레지스트리에서 찾을 단어로 짓고, 조직 패키지는 스코프로 묶는다. `bin` 명령은 셸의 다른 명령과 겹치지 않는지 본다 (`test`, `build` 같은 일반 명령 X)
6. **이벤트 이름은 일어난 일을 과거형으로, 한 모양으로.** `order:created` 나 `orderCreated` 중 하나로 통일한다. 기존 코드의 `emit(` · `on(` 을 먼저 찾는다
7. **boolean** — `is` · `has` · `can` · `should` + 형용사·과거분사 (`isPaid`, `hasItems`). 부정형(`isNotPaid`) 대신 반대 단어
8. **컬렉션은 복수형** — `orders`, `ordersById`. `orderList` · `orderArr` X
9. **함수는 동사로** — `cancelOrder`, `findByEmail`, `toResponse`. Promise 를 돌려준다고 `Async` 를 붙이지 않는다
10. **같은 개념 = 같은 단어.** 코드베이스에서 이미 쓰는 단어를 먼저 찾는다 (`grep -rE "fetch|load|get" src`)

## 3. 절차

1. 대상이 무엇을 다루고 무엇을 하는지 한 문장으로 쓴다
2. 그 문장의 명사 · 동사로 이름을 만든다. 기존 코드 · `package.json` · `.env.example` 에서 같은 개념의 단어와 접두사를 찾아 맞춘다
3. 1절 모양으로 쓴다
4. 이름을 바꾸는 경우 — 참조를 모두 찾아 같이 바꾼다. 환경 변수는 배포 설정(`.env.example`, CI, 컨테이너 설정)도, 패키지 이름은 import 하는 쪽과 레지스트리도 같이 본다

훅이 막으면 메시지의 **제안 이름**으로 고친다. 제안은 모양만 바꾼 것이므로 단어가 틀렸으면 2절로 다시 짓는다.

## 4. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-node-naming.sh" src package.json
```

기존 위반은 훅이 막지 않는다 (새로 생긴 것만). 한꺼번에 고칠 때는 위 명령이나 `--all .` 로 찾는다.
