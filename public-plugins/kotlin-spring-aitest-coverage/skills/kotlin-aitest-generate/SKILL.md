---
name: kotlin-aitest-generate
description: Kotlin · Spring Boot 코드를 고친 뒤 테스트를 쓰거나 케이스를 설계할 때 사용한다. 변경 메서드마다 성공·실패·경계 케이스 매트릭스로 @AiTest(testcontainer 통합) · @AiWebTest(MockMvc) 를 Kotlin 으로 작성·실행하고 변경 메서드 JaCoCo 100% 를 맞춘다. 트리거 — "테스트 만들어줘", "통합 테스트", "AiTest", "커버리지 올려", 완료 보류(kotlin-spring-aitest-coverage).
---

# Kotlin @AiTest 생성

규칙 원본: [`references/coverage-rules.md`](../../references/coverage-rules.md) — 게이트 조항 `C-01` ~ `C-09`, 변경 줄 → 메서드, 설정 파일, 반복 상한.
코드 형태 · 시드 함정: [examples.md](examples.md) — 테스트를 실제로 쓸 때 연다.

| 애노테이션 | webEnvironment | 언제 |
|---|---|---|
| `@AiTest` | NONE | 기본. 서비스 · 리포지토리를 생성자로 주입받은 실제 빈으로 직접 호출 |
| `@AiWebTest` | MOCK + MockMvc | 컨트롤러 경계 — 파라미터 바인딩 · 인증 · 예외 핸들러 · 응답 JSON 계약 |

`@SpringBootTest` · `@ActiveProfiles` · 컨테이너를 직접 조립하지 않는다 — 메타 애노테이션이 다 묶고 있고, `@TestConstructor(ALL)` 이 들어 있어 생성자 `val` 로 주입받는다.

## 인터페이스

- **입력**: 대상 메서드 · 클래스, `git diff <기준>`, 소속 모듈 — `<기준>` 은 Stop 차단 메시지가 알려준 ref (막히기 전이고 요청 안에서 커밋하지 않았으면 `HEAD`)
- **출력**: `<module>/src/aiTest/kotlin/<대상과 같은 패키지 디렉터리>/<대상 클래스>AiTest.kt` — 만든 뒤 **실행해 통과 확인**
- **통과 게이트**: `aiTest` PASS · 변경 메서드 JaCoCo 100% · `"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" <기준>` PASS
- **불변**: 프로덕션 코드 수정 금지(버그를 찾으면 보고만) · 프로젝트에 없는 테스트 라이브러리를 몰래 넣지 않기 · `Thread.sleep` 금지

## 0. 환경 확인

`build.gradle.kts` 에 `// >>> kotlin-spring-aitest-coverage` 블록이 없으면 테스트를 쓰기 전에 `kotlin-aitest-environment-create` 로 환경을 만든다 (사용자 확인 필요).

## 1. 대상 분석

- `git diff <기준>` 과 untracked 파일로 바뀐 `.kt` 와 **모듈**을 확정한다. 한 파일에 클래스 · 최상위 함수 · companion 이 섞여 있으니 바뀐 **줄**이 어느 함수에 속하는지 본다 — `init` 블록 · 프로퍼티 초기화식은 생성자, 람다 본문 · 로컬 함수는 그 자체가 판정 대상이다 (규칙 원본 3절)
- 기본 인자의 기본값 식 · 시그니처 줄을 바꿨으면 **기본값을 생략한 호출**도 케이스로 둔다 (`name$default` 가 판정된다)
- 라이브러리 모듈(core · common 등) 변경이면 테스트는 **소비 모듈**에 만든다. 소비 모듈이 `.claude/kotlin-spring-aitest-coverage.json` 의 `libraryModules` 에 없으면 추가를 제안한다 (`C-04`)
- 같은 클래스의 기존 aiTest 를 먼저 찾는다 (`grep -rl '<Class>' <module>/src/aiTest/kotlin`) — 있으면 보강, 없으면 새로

## 2. 케이스 설계 (필수)

대상 메서드마다 아래 분류를 **전부 훑고**, 해당하는 케이스는 모두 테스트로 만든다. 성공 케이스 하나로 끝내지 않는다.

| 분류 | 반드시 볼 것 |
|---|---|
| **성공** | 대표 정상 입력 · 분기별 정상 경로(타입 · 상태 · 옵션이 갈리면 **각각**, `when` 분기마다) · 반환값 · 저장 결과 · 상태 변경을 모두 검증 |
| **실패** | 없는 ID · 권한 · 소유자 불일치 · 허용되지 않는 상태(취소 · 삭제 · 만료) · 중복 · 충돌 · `require` · `check` 위반 — **예외 타입 · 메시지(에러 코드)**, 그리고 **부작용 없음**(저장 · 발행 안 됨)까지 |
| **경계** | `null`(nullable 파라미터 · `?.` · `?:` 경로) · 빈 문자열 · 공백 · 빈 리스트 / 1건 / 여러 건 · 0 · 음수 · 최대값 · 날짜 경계(당일 · 자정 · 기간 시작 / 끝 포함 여부) · 페이지 첫 / 마지막 / 범위 밖 · 조회 0건 · 기본 인자 생략 |
| **데이터 상태** | 연관 데이터 없음(LEFT JOIN null) · soft delete · 비노출 행 섞임 · 정렬 · 중복 제거 · 다른 소유자 데이터가 섞여도 걸러지는지 |
| **하위호환** | 새 · 바뀐 필드가 **빠진 요청**(구버전 클라이언트, Kotlin 기본값 · nullable 로 받는지) · 기존 응답 필드 유지 |
| **부작용 · 외부 경계** | MQ 발행 · HTTP 클라이언트 호출 여부 · 횟수 · 인자(`@MockkBean` 의 `verify` · `coVerify`) · 외부 실패 시 롤백 · 보상 · 캐시 무효화 |
| **동시성 · 멱등** | 같은 요청 2회 · 락 · 유니크 제약 충돌 · 코루틴 취소 — 코드에 그 장치가 있을 때만 |

- 해당하지 않는 분류는 건너뛰되 **왜 해당 없는지** 보고에 한 줄 남긴다
- 입력만 다르고 검증 형태가 같으면 `@ParameterizedTest`(`@ValueSource` · `@CsvSource` · `@EnumSource` · `@MethodSource` — companion 의 `@JvmStatic` 함수)로 묶는다. 검증 흐름이 다르면(예외 vs 정상 반환) 나눈다
- 요구사항 · 티켓에 적힌 규칙은 규칙마다 최소 1케이스
- 한 테스트는 **한 동작**. 이름은 백틱 한국어 문장 `` fun `결제된 주문을 취소하면 409`() ``

## 3. 애노테이션 · 목 선택

- 기본은 `@AiTest` — 서비스를 직접 호출하는 쪽이 시드 · 검증이 단순하다
- 파라미터 바인딩 · 인증 경로 · 예외 핸들러 응답 · 응답 JSON 계약 중 하나라도 검증 대상이면 `@AiWebTest`. MockMvc 는 Kotlin DSL(`mvc.get(url) { … }.andExpect { … }`)로 쓴다
- 변경된 Controller 는 `C-01` 때문에 `src/aiTest/kotlin` 에 그 클래스 이름이 나와야 한다 — 클래스 이름을 `<Controller>AiTest` 로 짓는다
- 목은 **외부 경계**에만 — 내부 서비스 · 리포지토리를 목으로 바꾸지 않는다. 프로젝트에 있는 것을 쓴다: SpringMockK `@MockkBean`(MockK, Kotlin final 클래스 그대로) → 없으면 `@MockitoBean`(Boot 3.4+) + mockito-kotlin. 둘 다 없으면 환경 생성이 넣은 SpringMockK 를 쓴다
- `suspend` 함수는 `runTest { }` 로 부르고 목은 `coEvery` · `coVerify`. `Dispatchers.IO` 로 넘기는 코드는 가상 시간이 적용되지 않는다 — 디스패처를 주입받는 생성자가 있으면 `StandardTestDispatcher` 를 넘긴다

## 4. 작성

- 클래스에 `@DisplayName` 한국어 + KDoc 한 줄로 **검증 대상 메서드**
- 의존성은 생성자 `val` 로 받는다 (`lateinit var` 필드 주입 대신)
- given – when – then 구획
- 시드는 테스트 안에서 명시적으로. ID · 코드는 다른 aiTest 와 겹치지 않는 대역을 `companion object { const val … }` 로 — 한 모듈의 aiTest 는 한 JVM · 공유 컨테이너에서 돈다
- `@Transactional` 롤백이 기본(DB 가 있을 때). 트랜잭션 밖 부작용 검증만 `@Commit` + 직접 정리
- private 함수를 직접 테스트하지 않는다 — public 진입점으로. `internal` 은 aiTest 에서 보이지만(`associateWith`) 같은 원칙이다

## 5. 실행

```bash
./gradlew :<module>:aiTest --tests '<패키지>.<클래스>AiTest' -PskipAiTestCoverage   # 반복 실행
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" <기준>                    # 완료 전 — aiTest + JaCoCo + 판정
```

- JDK 는 프로젝트 `jvmToolchain` 에 맞춘다 (설정 `jdkVersion`). Docker 가 필요하다
- 실패하면 테스트를 통과시키려고 **대상 코드를 고치지 않는다** — 원인을 보고하고 사용자가 정한다
- `FAIL … → NN%` 가 나오면 JaCoCo HTML(`<module>/build/reports/jacoco/aiTestReport/html/`)에서 빨간 줄을 보고 그 분기의 케이스를 더한다. 메서드 이름이 `name$default` 면 기본값 생략 호출, `$lambda$N` 이면 그 람다가 실제로 실행되는 경로다. **최대 3회** 보강 뒤에도 미달이면 멈추고 보고한다
- `UNDECIDABLE … javap` · `클래스 파일 없음` (`C-09`) 이면 JDK 를 맞추고 `diff-coverage-validate.sh <기준>` 을 다시 돌린다

## 6. 보고

```
Tests: <module> | added N | PASS | changed methods 100%
- 케이스: 성공 n · 실패 n · 경계 n · 기타 n
- 해당 없음: <분류> — <이유>
- 제외: <케이스> — <이유>
```

실제 실행 결과 숫자만 쓴다.

## 금지

- 대상 코드 수정(테스트 통과 목적) · 프로젝트에 없는 테스트 라이브러리 추가 · `Thread.sleep` 기반 비동기 검증
- `@SpringBootTest` 단독 사용 — 반드시 `@AiTest` / `@AiWebTest`
- `-PskipAiTestCoverage` · `aitest: skip` 면제를 사용자 요청 없이 완료 판정에 쓰기
- 성공 케이스만 쓰고 끝내기 — 2절의 실패 · 경계 분류를 보지 않은 테스트는 미완료다
