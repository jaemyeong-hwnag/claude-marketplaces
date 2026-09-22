# Node.js 네이밍 규칙 (단일 원본)

Node.js 프로젝트의 **이름 모양**을 정한다 — `package.json` 의 이름 · npm script, 환경 변수, JavaScript 소스의 식별자와 파일 이름. 기계 검증은 [`scripts/validate-node-naming.sh`](../scripts/validate-node-naming.sh).

근거는 넷이다.

- npm 문서의 package.json `name` 절 — npm 레지스트리가 받는 이름 규칙. npm 의 `validate-npm-package-name` 패키지가 같은 규칙을 코드로 가진다
- Airbnb JavaScript Style Guide 의 Naming Conventions 절 — 변수 · 함수 camelCase, 클래스 PascalCase, 상수 UPPER_SNAKE_CASE
- Node.js · npm 관례 — 파일 이름 kebab-case, npm script 의 `:` 네임스페이스(`test:unit`), npm 이 넣는 `npm_*` 환경 변수
- POSIX 환경 변수 관례 — 대문자 · 숫자 · 밑줄. 프록시 변수(`http_proxy` 등)는 관례상 소문자

기계는 근거가 **분명히 정한 것만** 막는다. 관례가 갈리는 것은 경고하고, 단어를 고르는 일은 AI 가 판단한다 (4절).

관심사 경계: TypeScript 소스(`*.ts` · `*.tsx` · `*.mts` · `*.cts`)의 식별자 · 파일 이름은 `typescript-naming` 이 본다. 이 플러그인은 TS 파일에서 **환경 변수(`ND-03`)만** 본다.

## 1. 조항

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `ND-01` | `package.json` 의 최상위 `name` | npm 규칙 — 214자 이하, 소문자, `.` · `_` 로 시작하지 않음, URL 에 그대로 쓸 수 있는 문자(소문자 · 숫자 · `-` `.` `_`)만, 스코프는 `@scope/name` — `order-service`, `@acme/order-service` | 차단 |
| `ND-02` | `package.json` 의 `scripts` 키 | 소문자 · 숫자를 `-` 와 `:` 로 잇는다 — `test:unit`, `build-prod` | 경고 |
| `ND-03` | `process.env.NAME` · `process.env['NAME']` · `process.env["NAME"]` | UPPER_SNAKE_CASE — `ORDER_DB_URL` | 차단 |
| `ND-04` | JS 의 class 선언 | PascalCase — `OrderService` | 차단 |
| `ND-05` | JS 의 `let` · `const` · `var` · `function` 이름 | 소문자가 섞인 snake_case 금지 → camelCase — `userName`, `loadUser` | 차단 |
| `ND-06` | JS 파일 이름 | kebab-case — `order-service.js`. 첫 조각은 default export 이름을 딴 camelCase · PascalCase(`useOrderQuery.js` · `OrderCard.js`)도 허용. 점으로 붙인 역할 접미사(`.config.js` · `.test.js`) 허용. 밑줄(`order_service.js`)만 경고 | 경고 |

대상 파일: `*.js` · `*.mjs` · `*.cjs` · `*.jsx` · `package.json`, 그리고 `ND-03` 에 한해 `*.ts` · `*.tsx` · `*.mts` · `*.cts`.

```js
// src/order-service.js                              ND-06
const MAX_RETRY_COUNT = 3;                          // ND-05 (상수는 UPPER_SNAKE_CASE 허용)
const dbUrl = process.env.ORDER_DB_URL;             // ND-03 · ND-05

class OrderService {                                // ND-04
  cancelOrder(orderId) { }
}

function findOrders(userId) { }                     // ND-05
```

```json
{
  "name": "@acme/order-service",
  "scripts": { "test:unit": "jest", "build-prod": "tsc -p prod" }
}
```

### 예외 — 막지 않는 것

| 경우 | 이유 |
|---|---|
| `ND-01` — 최상위가 아닌 `name`(`config.name` 등) · `name` 이 없는 `package.json` | npm 이 보는 것은 최상위 `name` 뿐이다. 비공개 패키지는 이름이 없어도 된다 |
| `ND-01` — 편집 뒤 JSON 이 깨져 있는 `package.json` | 무엇이 이름인지 알 수 없다. JSON 오류는 다른 도구가 알린다 |
| `ND-02` — `prepublishOnly` | npm 이 정한 라이프사이클 이름이다 |
| `ND-03` — `npm_*` (`npm_package_version`, `npm_config_…`, `npm_lifecycle_event`) | npm 이 넣는 이름이다 |
| `ND-03` — `http_proxy` · `https_proxy` · `no_proxy` · `all_proxy` | 관례상 소문자다 (도구마다 소문자를 먼저 읽는다) |
| `ND-03` — `process.env.hasOwnProperty(…)` 같은 메서드 호출 | 환경 변수 이름이 아니다 |
| `ND-04` — 이름 없는 클래스 표현식(`class extends Base`) | 이름이 없다 |
| `ND-05` — UPPER_SNAKE_CASE 상수(`MAX_RETRY_COUNT`), PascalCase(`OrderCard` — 컴포넌트 · 생성자) | Airbnb 가이드가 허용한다 |
| `ND-05` — 앞뒤 밑줄(`_private`, `__dirname`) | 앞 밑줄은 관례상 "내부용" 표시다. 밑줄 사이의 snake_case(`_cache_map`)는 막는다 |
| `ND-05` — 구조 분해(`const { user_name } = row`) | 이름을 바깥(DB · API)이 정한다 |
| `ND-05` — 메서드 · 객체 속성 · 매개변수 · 여러 선언의 두 번째 이후(`let a = 1, b_c = 2`) | 선언을 문법 없이 가려낼 수 없다. AI 가 판단한다 |
| `ND-06` — 앞 점(`.eslintrc.cjs`) · 앞 밑줄(`_app.js`) · 대괄호 라우트(`[id].js` · `[...slug].jsx`) · `Gruntfile.js` · `Gulpfile.js` · `Jakefile.js` | 도구가 정한 이름이다 |
| TS 파일의 식별자 · 파일 이름 | `typescript-naming` 이 본다 |
| `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` · `vendor/` · `.git/`, `*.min.js` | 생성물 · 의존성이다 |

주석 · 문자열 리터럴 · 템플릿 문자열의 글자는 코드로 읽지 않는다. 템플릿 문자열의 `${…}` 안은 코드로 읽는다.

### 왜 경고인가

- `ND-02` — npm 은 script 이름에 모양 규칙을 두지 않는다. `:` 구분이 널리 쓰이지만 `buildProd` 를 쓰는 프로젝트도 있다
- `ND-06` — 가이드가 갈린다. Node.js 코어와 npm 생태계는 kebab-case 를 쓰고, Airbnb 가이드는 "파일 이름 = default export 이름"(camelCase · PascalCase)을 권한다. 둘 다 허용하고, 어느 쪽도 아닌 밑줄 이름만 경고한다. 한 프로젝트 안에서 어느 쪽을 쓸지는 스킬이 기존 파일을 보고 맞춘다

## 2. 새로 생긴 위반만 막는다

훅은 편집 **전** 파일과 편집 **뒤** 내용을 둘 다 검사해 **늘어난 위반만** 막는다.

- `Write` — `content` 가 편집 뒤 내용이다. 파일이 이미 있으면 그 내용과 비교한다
- `Edit` — 현재 파일에 `old_string` → `new_string` 치환을 적용해 편집 뒤 내용을 만든다

레거시 파일의 다른 줄을 고치다가 기존 이름 때문에 막히지 않는다. 기존 위반을 고치고 싶으면 CLI 로 찾는다 (5절).
파일 이름 경고(`ND-06`)는 파일을 새로 만들 때만 알린다.

## 3. 차단과 경고

| | 훅 | CLI |
|---|---|---|
| 차단 조항 | 종료 코드 `2` + stderr — Claude 가 제안한 이름으로 다시 쓴다 | `❌` + 종료 코드 `2` |
| 경고 조항 | `additionalContext` 로 알린다 | `⚠️` + 종료 코드 `0` |

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-node-naming.sh` | `ND-01` ~ `ND-06` — 모양 |
| 판단 | AI (`node-name-create` 스킬) | 이름이 무엇을 가리키는지 말하는가, 단어 선택, 줄임말, 환경 변수 접두사, 모듈 파일과 export 이름, CLI bin 이름, 이벤트 이름 |

AI 가 판단할 것:

1. **이름만 보고 무엇인지 말할 수 있는가.** `data`, `info`, `utils`, `helper`, `handle()` 은 무엇을 다루는지 말하지 않는다
2. **줄임말을 쓰지 않았는가.** `cnt` → `count`, `usr` → `user`, `cfg` → `config`. 업계 표준 약어(`id`, `url`, `http`, `api`, `db`)만
3. **환경 변수는 서비스 · 대상 접두사로 묶였는가.** `ORDER_DB_URL`, `ORDER_DB_POOL_SIZE` — `DB_URL` 하나로는 여러 서비스가 한 환경을 쓸 때 부딪친다. 값의 단위를 이름에 넣는다 (`…_TIMEOUT_MS`, `…_TTL_SECONDS`). boolean 은 `…_ENABLED`
4. **모듈 파일 이름과 export 이름이 맞는가.** `order-service.js` 가 `OrderService` 를 export 한다. 한 파일이 여러 개념을 export 하면 파일을 나눌 때다
5. **package 이름과 CLI bin 이름.** `bin` 은 셸에서 치는 명령이므로 소문자 kebab-case 이고 짧다. 패키지 이름과 같게 하거나 겹치지 않는 다른 명령과 부딪치지 않는지 본다
6. **이벤트 이름은 과거형 · 한 가지 모양으로.** `order:created` 나 `orderCreated` 중 하나로 통일한다. `EventEmitter` 의 이름은 문자열이라 기계가 보지 않는다
7. **boolean 은 참/거짓으로 읽히는가.** `isPaid`, `hasItems`, `canCancel` — `flag`, `status` X
8. **컬렉션은 복수형인가.** `orders`, `ordersById` — `orderList` 보다 `orders`
9. **함수는 동사로 시작하는가.** `cancelOrder`, `findByEmail`, `toResponse`. async 함수에 `Async` 접미사를 붙이지 않는다 (Promise 가 기본이다)
10. **같은 개념에 같은 단어를 쓰는가.** 한 코드베이스에서 `fetch` · `get` · `load` 를 섞지 않는다

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-node-naming.sh" src/config.js    # 파일
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-node-naming.sh" src              # 디렉터리
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-node-naming.sh" --all .          # 프로젝트 전체
```

종료 코드 `2` 가 위반이다. 경고만 있으면 `0` 이다.
