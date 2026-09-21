# kotlin-naming

Kotlin 코드의 이름을 Kotlin 컨벤션으로 강제한다 — 패키지 소문자, 타입 UpperCamelCase, 클래스 하나뿐인 파일과 파일명, const val SCREAMING_SNAKE_CASE, 함수·프로퍼티 lowerCamelCase.

모양은 훅이 막고, 어떤 단어를 쓸지는 `kotlin-name-create` 스킬이 판단한다. 근거는 Kotlin 공식 Coding conventions 의 Naming rules 절이고, Android Kotlin style guide 는 참고만 한다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install kotlin-naming@plugin-marketplace
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| kotlin-name-create | Kotlin 코드 작성 · data class · 확장 함수 · 프로퍼티 이름 짓기 | 모양 표와 단어 선택 판단 (확장 함수 · Boolean · Flow · suspend · 팩터리 · 테스트 이름) |
| /kotlin-naming-validate | 직접 호출 | 프로젝트 전체 `*.kt` 를 검증해 조항별로 보고한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-kotlin-naming.sh | PreToolUse (Write\|Edit) | `*.kt` 편집이 **새로 만든** 위반이면 **차단**, 경고 조항은 알림 |

## 주의

- 훅은 편집 전과 뒤를 비교해 **늘어난 위반만** 막는다. 레거시 파일의 다른 줄을 고칠 때 기존 이름 때문에 막히지 않는다. 기존 위반은 `/kotlin-naming-validate` 로 찾는다
- `*.kts`(`build.gradle.kts` 등)는 보지 않는다
- `val` · `var` 는 소문자로 시작하는 snake_case 만 막는다. SCREAMING_SNAKE_CASE 가 깊이 불변 값인지, UpperCamelCase 가 싱글턴 참조인지는 기계가 모른다
- 대문자로 시작하는 함수는 `@Composable` 과 반환 타입이 같은 팩터리 함수만 허용한다. 테스트 경로의 함수 이름은 밑줄을 허용한다
- 매개변수 · enum 상수 · 람다 매개변수는 스킬이 판단한다
- `build/` · `target/` · `out/` · `.gradle/` · `generated/` 는 보지 않는다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `KN-01` | 패키지 | 조각은 소문자로 시작 (camelCase 허용), 밑줄 없음 | 대문자 시작 차단 · 밑줄 경고 |
| `KN-02` | class · interface · object · enum / annotation / data / sealed / value class · fun interface · typealias | UpperCamelCase | 차단 |
| `KN-03` | 파일 이름 | 최상위 선언이 클래스류 하나뿐이면 그 이름, 그 밖에는 UpperCamelCase | 하나뿐일 때 차단 · 그 밖은 경고 |
| `KN-04` | `const val` | SCREAMING_SNAKE_CASE | 차단 |
| `KN-05` | `fun` | lowerCamelCase (백틱 · `@Composable` · 팩터리 · 테스트 밑줄 예외) | 차단 |
| `KN-06` | `val` · `var` | 소문자로 시작하는 snake_case 금지 (`_name` · SCREAMING · UpperCamel 허용) | 차단 |
| `KN-07` | 타입 이름의 약어 | `HttpClient` (`HTTPClient` X, `IOStream` 은 된다) | 경고 |

원본: [`references/kotlin-naming-rules.md`](references/kotlin-naming-rules.md)

## 사용

```bash
scripts/validate-kotlin-naming.sh src/main/kotlin   # 디렉터리
scripts/validate-kotlin-naming.sh --all .           # 프로젝트 전체
test/validate-kotlin-naming.test.sh                 # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
