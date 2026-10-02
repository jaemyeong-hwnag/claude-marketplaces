# go-naming

Go 코드의 이름을 Go 컨벤션으로 강제한다 — 패키지 소문자 한 단어, 함수·타입·변수·상수·필드 MixedCaps(밑줄 금지), 이니셜리즘 대문자, 게터 `Get` 생략, 파일 이름 소문자, 리시버 짧은 약자.

모양은 훅이 막고, 어떤 단어를 쓸지는 `go-name-create` 스킬이 판단한다. 근거는 Effective Go 의 Names 절 · Go Code Review Comments · Go 블로그 "Package names" · staticcheck ST1003 이다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install go-naming@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| go-name-create | Go 코드 작성 · 패키지 · 함수 · 타입 · 리시버 이름 짓기 | 모양 표와 단어 선택 판단 (패키지 이름 반복 · `-er` 인터페이스 · 짧은 지역 변수 · 공개 여부) |
| /go-naming-validate | 직접 호출 | 프로젝트 전체 `*.go` 를 검증해 조항별로 보고한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-go-naming.sh | PreToolUse (Write\|Edit) | `*.go` 편집이 **새로 만든** 위반이면 **차단**, 경고 조항은 알림 |

## 주의

- 훅은 편집 전과 뒤를 비교해 **늘어난 위반만** 막는다. 레거시 파일의 다른 줄을 고칠 때 기존 이름 때문에 막히지 않는다. 기존 위반은 `/go-naming-validate` 로 찾는다
- 문법 분석기 없이 줄 단위로 본다. 지역 변수 · 매개변수 · `:=` 는 보지 않고, 한 줄에 쓴 구조체(`struct{ A_b int }`)의 필드도 보지 않는다
- 상수도 MixedCaps 다 — `MAX_SIZE` 는 막힌다 (`MaxSize`). cgo · syscall 상수처럼 C 이름을 따라야 하면 생성 파일로 두거나 기존 파일에 둔다
- `vendor/` · `testdata/` 와 `// Code generated ... DO NOT EDIT.` 표시가 있는 파일은 보지 않는다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `GO-01` | `package` 이름 | 소문자 한 단어 (`_test` 접미사 허용) | 차단 |
| `GO-02` | 함수 · 메서드 · 타입 · 최상위 var/const · 구조체 필드 | 밑줄 없는 MixedCaps (`_test.go` 의 `Test*` 등 허용) | 차단 |
| `GO-03` | 이름 안의 이니셜리즘 | `userID` · `HTTPClient` (`userId` X) | 경고 |
| `GO-04` | 매개변수 없는 `GetX()` 메서드 | 게터에 `Get` 을 붙이지 않는다 (`Owner()`) | 경고 |
| `GO-05` | 파일 이름 | 소문자 · 숫자 · 밑줄 (`order_service.go`) | 경고 |
| `GO-06` | 메서드 리시버 | `this` · `self` X → `func (o *Order)` | 경고 |

원본: [`references/go-naming-rules.md`](references/go-naming-rules.md)

## 사용

```bash
scripts/validate-go-naming.sh ./internal     # 디렉터리
scripts/validate-go-naming.sh --all .        # 프로젝트 전체
test/validate-go-naming.test.sh              # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
