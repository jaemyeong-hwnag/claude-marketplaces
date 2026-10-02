# java-naming

Java 코드의 이름을 Java 컨벤션으로 강제한다 — 패키지 소문자, 타입 UpperCamelCase, public 타입과 파일명, 상수 UPPER_SNAKE_CASE, 메서드·필드 lowerCamelCase.

모양은 훅이 막고, 어떤 단어를 쓸지는 `java-name-create` 스킬이 판단한다. 근거는 Google Java Style Guide 5장 · Oracle Code Conventions 9장이다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install java-naming@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| java-name-create | Java 코드 작성 · 클래스 · 메서드 · 변수 이름 짓기 | 모양 표와 단어 선택 판단 (줄임말 · 역할 접미사 · boolean · 컬렉션) |
| /java-naming-validate | 직접 호출 | 프로젝트 전체 `*.java` 를 검증해 조항별로 보고한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-java-naming.sh | PreToolUse (Write\|Edit) | `*.java` 편집이 **새로 만든** 위반이면 **차단**, 경고 조항은 알림 |

## 주의

- 훅은 편집 전과 뒤를 비교해 **늘어난 위반만** 막는다. 레거시 파일의 다른 줄을 고칠 때 기존 이름 때문에 막히지 않는다. 기존 위반은 `/java-naming-validate` 로 찾는다
- 멤버는 접근 제어자(`public` · `protected` · `private`)로 시작하는 선언만 본다. 지역 변수 · 매개변수 · enum 상수는 스킬이 판단한다
- `static final` 중 원시 타입 · `String` 만 상수로 판정한다. `Logger` · 컬렉션은 상수인지 기계가 모른다
- `build/` · `target/` · `out/` · `.gradle/` · `generated/` 는 보지 않는다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `JN-01` | 패키지 | 소문자, 밑줄 없음 | 대문자 차단 · 밑줄 경고 |
| `JN-02` | 클래스 · 인터페이스 · enum · record · 어노테이션 | UpperCamelCase | 차단 |
| `JN-03` | public 최상위 타입 | 파일 이름과 같다 | 차단 |
| `JN-04` | `static final` 원시 타입 · `String` | UPPER_SNAKE_CASE | 차단 |
| `JN-05` | 메서드 · 필드 | lowerCamelCase (테스트 메서드 밑줄 허용) | 차단 |
| `JN-06` | 타입 이름의 약어 | `HttpClient` (`HTTPClient` X) | 경고 |

원본: [`references/java-naming-rules.md`](references/java-naming-rules.md)

## 사용

```bash
scripts/validate-java-naming.sh src/main/java     # 디렉터리
scripts/validate-java-naming.sh --all .           # 프로젝트 전체
test/validate-java-naming.test.sh                 # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
