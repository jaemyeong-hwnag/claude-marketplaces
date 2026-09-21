# Go 네이밍 규칙 (단일 원본)

Go 코드의 **식별자 모양**을 정한다. 기계 검증은 [`scripts/validate-go-naming.sh`](../scripts/validate-go-naming.sh).

근거는 Effective Go 의 Names 절(패키지 이름 · 게터 · 인터페이스 이름 · MixedCaps), Go Code Review Comments 의 Initialisms · Receiver Names · Package Names 절, Go 블로그 글 "Package names", staticcheck 의 ST1003 검사다.
기계는 이 가이드들이 **분명히 정한 것만** 막는다. 관례가 갈리거나 오탐 가능성이 있는 것은 경고하고, 단어를 고르는 일은 AI 가 판단한다 (4절).

## 1. 조항

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `GO-01` | `package` 이름 | 소문자 한 단어 — `order`, `httputil`. 밑줄 · 대문자 X. 외부 테스트 패키지의 `_test` 접미사는 허용 | 차단 |
| `GO-02` | 함수 · 메서드 · 타입 · 최상위 `var` / `const` (괄호 블록 안 포함) · 구조체 필드 · 인터페이스 메서드 · 함수 안의 `type` | 밑줄 없는 MixedCaps — `CreateOrder`, `maxRetryCount`. 제안은 첫 글자의 대소문자(공개 여부)를 유지한다 | 차단 |
| `GO-03` | 선언한 이름 안의 이니셜리즘 | 대소문자를 한 가지로 — `userID`, `HTTPClient`, `apiURL` (`userId` · `HttpClient` X) | 경고 |
| `GO-04` | 매개변수 없는 메서드 `GetX()` | 게터에 `Get` 을 붙이지 않는다 — `Owner()`, 세터는 `SetOwner()` | 경고 |
| `GO-05` | 파일 이름 | 소문자 · 숫자 · 밑줄 — `order_service.go`. 대문자 · 하이픈 X | 경고 |
| `GO-06` | 메서드 리시버 이름 | `this` · `self` 대신 타입의 짧은 약자 — `func (o *Order)` | 경고 |

`GO-03` 이 보는 이니셜리즘: `Url` · `Http` · `Https` · `Id` · `Json` · `Api` · `Sql` · `Html` · `Xml` · `Uri` · `Uuid` · `Ip` · `Tcp` · `Udp` · `Rpc` · `Ssh` · `Tls` · `Ttl` · `Cpu` · `Dns`. 뒤에 대문자가 오거나 이름이 끝날 때만 본다 (`Identity` · `Ids` · `Idle` 은 보지 않는다).

```go
package order // GO-01 — order_service.go (GO-05)

const maxRetryCount = 3 // GO-02 (MAX_RETRY_COUNT X)

type OrderService struct { // GO-02
	client  *http.Client
	baseURL string // GO-03
}

func (s *OrderService) Owner() string { return "" }         // GO-04 · GO-06
func (s *OrderService) CancelOrder(orderID int64) error { … } // GO-02 · GO-03
```

### 예외 — 막지 않는 것

| 경우 | 이유 |
|---|---|
| 빈 식별자 `_` | 이름이 아니다 |
| `_test.go` 의 `Test*` · `Benchmark*` · `Example*` · `Fuzz*` 함수의 밑줄 — `TestCancel_whenPaid`, `ExampleOrder_Cancel` | `go test` 가 이름으로 찾고, `Example` 은 밑줄로 대상을 가리킨다 |
| 외부 테스트 패키지 `package order_test` | 언어가 정한 형태다 |
| 지역 변수 · 매개변수 · `:=` · 결과 이름 | 짧은 이름이 관례이고 문법 없이 선언을 가려낼 수 없다. AI 가 판단한다 |
| 구조체 임베딩 `*Base` · `pkg.Type`, `import` 별칭, 구조체 태그 | 필드 이름이 아니다 · 태그는 문자열이다 |
| 매개변수가 있는 `Get…(x)` · 함수(리시버 없음) `GetX()` | 조회 연산이지 필드 게터가 아닐 수 있다 |
| 이름 없는 리시버 `func (*Order)` | 이름이 없다 |
| 생성 파일 — `package` 앞 주석에 `// Code generated ... DO NOT EDIT.` | 생성기가 쓴 이름이다. 편집 **뒤** 내용으로 판단한다 |
| `vendor/` · `testdata/` · `node_modules/` · `.git/` | 의존성 · 테스트 입력이다 |

주석 · 문자열 · 룬 리터럴 · raw string(여러 줄 포함) 안의 단어는 코드로 읽지 않는다.

### 왜 차단 / 경고로 갈랐나

- `GO-01` · `GO-02` 는 Effective Go 와 Code Review Comments 가 예외 없이 정하고 staticcheck ST1003 이 잡는다 — 차단
- `GO-03` 은 이니셜리즘 목록이 프로젝트마다 다르고 (`Id` 가 "identity" 뜻일 수도 있다) 공개 API 이름을 바꾸면 호환성이 깨진다 — 경고
- `GO-04` 는 매개변수 없는 `GetX()` 가 원격 조회일 수도 있다 — 경고
- `GO-05` 는 공식 문서가 권장만 한다 (`go build` 는 대문자 파일 이름을 받는다) — 경고
- `GO-06` 은 Code Review Comments 의 권고이고 컴파일과 무관하다 — 경고

## 2. 새로 생긴 위반만 막는다

훅은 편집 **전** 파일과 편집 **뒤** 내용을 둘 다 검사해 **늘어난 위반만** 막는다.

- `Write` — `content` 가 편집 뒤 내용이다. 파일이 이미 있으면 그 내용과 비교한다
- `Edit` — 현재 파일에 `old_string` → `new_string` 치환을 적용해 편집 뒤 내용을 만든다

레거시 파일의 다른 줄을 고치다가 기존 이름 때문에 막히지 않는다. 파일 이름 경고(`GO-05`)는 새 파일을 만들 때만 나온다. 기존 위반을 고치고 싶으면 CLI 로 찾는다 (5절).

## 3. 차단과 경고

| | 훅 | CLI |
|---|---|---|
| 차단 조항 | 종료 코드 `2` + stderr — Claude 가 제안한 이름으로 다시 쓴다 | `❌` + 종료 코드 `2` |
| 경고 조항 | `additionalContext` 로 알린다 | `⚠️` + 종료 코드 `0` |

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-go-naming.sh` | `GO-01` ~ `GO-06` — 모양 |
| 판단 | AI (`go-name-create` 스킬) | 패키지 이름 반복, 인터페이스 이름, 지역 변수 길이, 공개 여부, 패키지 이름의 뜻 |

AI 가 판단할 것:

1. **패키지 이름을 반복하지 않는다.** 호출부는 `패키지.이름` 으로 읽는다 — `http.HTTPServer` → `http.Server`, `order.OrderService` → `order.Service`, `list.NewList()` → `list.New()`
2. **패키지 이름은 무엇을 제공하는지 말한다.** `util` · `common` · `helpers` · `misc` · `base` · `types` 는 말하지 않는다 → 쓰임새로 나눈다 (`strutil` 보다 `strings` 에 붙일 수 있는지 먼저 본다). 복수형 X (`orders` → `order`)
3. **한 메서드 인터페이스는 메서드 이름 + `-er`.** `Reader`, `Stringer`, `OrderCanceler`. 표준 메서드 이름(`Read` · `Write` · `Close` · `String`)은 표준과 같은 뜻 · 시그니처일 때만 쓴다
4. **지역 변수는 짧게, 멀리 쓰일수록 길게.** 루프 `i`, 리더 `r`, 컨텍스트 `ctx`, 에러 `err`. 패키지 수준 · 공개 이름은 뜻이 드러나게
5. **공개 여부는 첫 글자로 정한다.** 패키지 밖에서 쓸 것만 대문자로 시작한다. 필요 없으면 소문자
6. **게터는 필드 이름 그대로, 세터는 `Set`.** `Owner()` / `SetOwner()`. boolean 은 `IsX` · `HasX` · `CanX` 도 된다
7. **에러** — 변수는 `ErrNotFound` (`Err` 접두사), 타입은 `NotFoundError` (`Error` 접미사). 에러 문자열은 소문자로 시작하고 마침표 없이
8. **생성자는 `New` · `NewX`.** 패키지가 한 타입만 만들면 `order.New()`, 여럿이면 `order.NewService()`
9. **줄임말은 관례로 굳은 것만.** `ctx` · `err` · `buf` · `cfg` · `req` · `resp` 는 지역 범위에서 괜찮다. 공개 이름에는 풀어 쓴다

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-go-naming.sh" internal/order/service.go   # 파일
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-go-naming.sh" internal                    # 디렉터리
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-go-naming.sh" --all .                     # 프로젝트 전체
```

종료 코드 `2` 가 위반이다. 경고만 있으면 `0` 이다.
