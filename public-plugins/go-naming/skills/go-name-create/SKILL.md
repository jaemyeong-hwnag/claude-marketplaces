---
name: go-name-create
description: Go 패키지·함수·타입·변수·리시버 이름을 Go 컨벤션으로 짓는다. Go 코드를 새로 쓰거나 이름을 짓거나 바꿀 때, exported 이름과 패키지 이름을 정할 때 사용한다. 트리거 — ".go", "고 이름", "golang 네이밍", "패키지 이름", "리시버 이름", "exported". 모양은 훅이 막고 단어 선택을 판단한다.
---

# Go 이름 짓기

규칙 원본: [`references/go-naming-rules.md`](../../references/go-naming-rules.md)
기계 검증: [`scripts/validate-go-naming.sh`](../../scripts/validate-go-naming.sh)

모양(밑줄 · 대소문자 · 파일 이름)은 훅이 막는다. 이 스킬은 **어떤 단어를 쓸지**를 정한다.

## 1. 모양 — 먼저 맞춘다

| 대상 | 모양 | 예 |
|---|---|---|
| 패키지 | 소문자 한 단어, 밑줄 · 복수형 X | `order`, `httputil` |
| 파일 | 소문자 · 밑줄 | `order_service.go`, `order_test.go` |
| 공개 이름 (패키지 밖에서 씀) | 대문자로 시작하는 MixedCaps | `CancelOrder`, `OrderService` |
| 비공개 이름 | 소문자로 시작하는 MixedCaps | `cancelOrder`, `maxRetryCount` |
| 상수 | 변수와 같은 MixedCaps (UPPER_SNAKE X) | `MaxRetryCount`, `defaultTimeout` |
| 이니셜리즘 | 대소문자 한 가지 | `userID`, `HTTPClient`, `apiURL`, `xmlParser` |
| 리시버 | 타입의 한두 글자, 메서드마다 같게 | `func (o *Order)`, `func (sc *ServerConfig)` |
| 테스트 함수 | `TestX_조건` 밑줄 허용 | `TestCancel_whenPaid` |

## 2. 단어 — 이 순서로 판단한다

1. **패키지 이름을 반복하지 않는다.** 호출부는 `패키지.이름` 으로 읽는다 — `http.HTTPServer` → `http.Server`, `order.OrderService` → `order.Service`, `list.NewList()` → `list.New()`
2. **패키지는 제공하는 것으로 이름 짓는다.** `util` · `common` · `helpers` · `misc` · `base` · `types` X → 쓰임새대로 나눈다 (`stringutil` 보다 쓰는 곳 가까이 둘 수 있는지 먼저 본다)
3. **한 메서드 인터페이스는 `메서드 + -er`.** `Reader`, `Stringer`, `OrderCanceler`. `Read` · `Write` · `Close` · `String` 은 표준과 같은 뜻 · 시그니처일 때만
4. **범위가 좁으면 짧게.** 루프 `i`, 리더 `r`, `ctx`, `err`, `buf`. 패키지 수준 · 공개 이름은 뜻이 드러나게 풀어 쓴다
5. **공개는 필요할 때만.** 패키지 밖에서 쓰지 않으면 소문자로 시작한다
6. **게터는 필드 이름, 세터는 `Set`.** `Owner()` / `SetOwner()`. boolean 은 `IsPaid` · `HasItems`
7. **에러** — 변수 `ErrNotFound`, 타입 `NotFoundError`
8. **생성자** — 타입이 하나면 `order.New()`, 여럿이면 `order.NewService()`
9. **같은 개념 = 같은 단어.** 코드베이스에서 이미 쓰는 단어를 먼저 찾는다 (`grep -rn "func (.*) Fetch\|func (.*) Load" --include=*.go .`)

## 3. 절차

1. 대상이 무엇을 다루고 무엇을 하는지 한 문장으로 쓴다
2. 호출부에서 어떻게 읽힐지 쓴다 — `order.Service.Cancel(ctx, id)`. 패키지 이름과 겹치는 단어를 뺀다
3. 공개 여부를 정하고 1절 모양으로 쓴다
4. 이름을 바꾸는 경우 — 참조를 모두 찾아 같이 바꾼다 (`gopls rename` 이 있으면 쓴다). 공개 이름은 다른 모듈의 호출부 호환성을 먼저 확인한다

훅이 막으면 메시지의 **제안 이름**으로 고친다. 제안은 모양만 바꾼 것이므로 단어가 틀렸으면 2절로 다시 짓는다.

## 4. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-go-naming.sh" ./internal
```

기존 위반은 훅이 막지 않는다 (새로 생긴 것만). 한꺼번에 고칠 때는 위 명령으로 찾는다.
