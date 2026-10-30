# kotlin-spring-aitest-coverage

[English](README.md) · **한국어** · [简体中文](README.zh-CN.md)

Kotlin · Spring Boot(Gradle Kotlin DSL) 프로젝트에서 **AI 가 바꾼 코드를 `@AiTest` 로 덮게** 한다 — 변경 메서드 케이스 매트릭스 테스트 생성, testcontainer 테스트 환경 생성, 작업 완료 시 변경 메서드 JaCoCo 100% 게이트.

AI 가 코드를 고치고 테스트 없이, 또는 성공 케이스 하나만 쓰고 "완료" 라고 하는 것을 막는다. 판정 기준은 git 로컬 diff 다.

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install kotlin-spring-aitest-coverage@jaemyeong-hwnag-plugins --scope project
```

설치한 뒤 `@AiTest` 환경이 없으면 "Kotlin AiTest 환경 만들어줘" 로 `kotlin-aitest-environment-create` 를 부른다. 환경이 생기기 전에는 게이트가 꺼져 있다.

필요한 것: `git`, JDK(`javap` 포함), Docker(testcontainer), Gradle Wrapper(`./gradlew`). 설정 파일(`.claude/kotlin-spring-aitest-coverage.json`)을 쓰면 `jq` 도 필요하다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| kotlin-aitest-generate | 테스트 작성, 통합 테스트, 커버리지 올려, 완료 보류 | 변경 메서드마다 성공 · 실패 · 경계 · 데이터 상태 · 하위호환 · 부작용 · 동시성 매트릭스로 `@AiTest` · `@AiWebTest` 를 Kotlin(생성자 주입 · MockK · `runTest` · 백틱 이름)으로 작성 → 실행 → 변경 메서드 100% |
| kotlin-aitest-environment-create | Kotlin AiTest 환경, 테스트 인프라, testcontainers 세팅 | 프로젝트를 읽어 대상 모듈 `build.gradle.kts` 의 `aiTest` 블록 · Kotlin 지원 모듈 · Docker 준비 스크립트 · 스모크 테스트를 만들고 스모크까지 돌린다 (사용자 확인 뒤) |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| aitest-coverage-validate.sh | UserPromptSubmit | 요청 시작 시점의 `src/main` · `src/aiTest` diff 지문을 남긴다 |
| aitest-coverage-validate.sh | Stop | 이번 요청에서 diff 가 바뀌었으면 변경 Controller 의 aiTest(`C-01`) · 변경 메서드 JaCoCo 100%(`C-02`) · 리포트 최신(`C-03`) · 소비 모듈을 모르는 main 변경의 aiTest diff(`C-04`) · 판정 도구(`C-09`)를 보고 미충족이면 **완료를 막는다** (exit 2) |

## 주의

- 게이트는 `build.gradle.kts` 에 `// >>> kotlin-spring-aitest-coverage` 블록이 있는 저장소에서만 돈다. 없으면 세션당 한 번 알리기만 한다. Gradle Groovy DSL 저장소에서는 아무것도 하지 않는다
- Stop 훅은 Gradle 을 돌리지 않고 **기존 리포트와 클래스 파일**로 판정한다. 코드를 고친 뒤 `scripts/diff-coverage-validate.sh <기준>` 으로 리포트를 갱신해야 통과한다 — `kotlin-aitest-generate` 가 한다. `<기준>` 은 차단 메시지가 알려준 ref 다 (요청 안에서 커밋했으면 `HEAD` 로는 diff 가 비어 통과해 버린다)
- 변경 줄이 어느 메서드인지는 클래스 파일의 줄 표(`javap`)로 정한다. `javap` 이나 클래스 파일이 없으면 판정 불가로 막는다
- 한 번 막힌 뒤 다시 완료하면 허용하고 경고만 남긴다(무한 루프 방지). 주석 · 포맷만 바꾼 경우 등은 `aitest: skip <사유>` 면제를 쓴다 — 게이트 메시지가 ACK 파일 경로(`<Gradle 루트>/.claude/kotlin-spring-aitest-coverage/`)를 알려준다
- `.kt` 만 본다. `.java` 는 `java-spring-aitest-coverage` 가 본다 — 두 판은 같이 설치해도 상태 · 설정 · 스킬 이름이 겹치지 않는다. 한 모듈에 두 판의 `aiTest` 환경을 같이 둘 수는 없다
- 지원 범위: Kotlin 2.x · Spring Boot 3.1 ~ 4.x · Gradle 8 · 9 (Kotlin DSL) · JDK 17+ · MockMvc · MySQL · PostgreSQL · Redis · RabbitMQ. WebFlux(`WebTestClient`) · Groovy DSL · Maven · Boot 2 는 보지 않는다
- 실측한 조합 (`test/README.md` 수동 확인)

  | Boot | Gradle | Kotlin | JDK | Testcontainers | 구성 | 인프라 | 확인한 것 |
  |---|---|---|---|---|---|---|---|
  | 3.5.16 | 8.14.4 | 2.2.21 | 17 | 1.21 (Boot BOM) | 멀티 모듈 + 라이브러리 | PostgreSQL | 환경 생성 → 스모크 → 차단 → 75% FAIL → 100% PASS · 훅 통과 · 라이브러리 `C-04` · `C-03` · `C-02` |
  | 4.1.1 | 9.8.0 | 2.4.21 | 17 | 2.0.5 (Boot BOM) | 단일 모듈 · 패키지 ≠ 디렉터리 | MySQL · Redis | 환경 생성 → 스모크 → 차단(파일 이름과 다른 Controller) → 50% FAIL → 100% PASS(`suspend` 포함) · 훅 통과 · `C-03` · aiTest 만 변경 |

## 게이트 조항

| 조항 | 내용 |
|---|---|
| `C-01` | 변경 Controller(`@RestController` · `@Controller`)마다 `src/aiTest/kotlin` 본문에 그 클래스 이름 |
| `C-02` | 변경 줄이 속한 메서드의 JaCoCo INSTRUCTION 100% — `@JvmStatic` 브리지 · 같은 줄의 `$default` · 주 생성자 줄의 접근자는 뺀다 |
| `C-03` | 리포트가 로컬 diff 보다 새롭다 |
| `C-04` | 소비 모듈을 모르는 main 변경은 aiTest diff 가 있어야 한다 |
| `C-05` ~ `C-08` | 이번 요청에서 diff 가 바뀐 경우만 · 환경 없으면 꺼짐 · 면제 · 무한 루프 방지 |
| `C-09` | 판정 도구(`javap` · 클래스 파일)가 없으면 판정 불가로 막는다 |

전체는 [`references/coverage-rules.md`](references/coverage-rules.md).

## 프로젝트 설정

`.claude/kotlin-spring-aitest-coverage.json` — 없어도 된다.

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"] },
  "jdkVersion": "17"
}
```

- `modules` 가 없으면 환경 블록이 있는 `build.gradle.kts` 의 모듈, 그것도 없으면 루트 단일 모듈
- `libraryModules` — core · common 같은 라이브러리 모듈이 바뀌면 소비 모듈의 `aiTest` 로 재고 소비 모듈 리포트에서 판정한다

## 파일

| 경로 | 역할 |
|---|---|
| `references/coverage-rules.md` | 규칙 원본 — 컨벤션 · 조항 · 변경 줄 → 메서드 · 대상 모듈 · 설정 · 이유 |
| `scripts/aitest-coverage-validate.sh` | 훅 — 지문(`snapshot`) · Stop 게이트 |
| `scripts/diff-coverage-validate.sh` | 로컬 diff 기준 `aiTest` 실행 + 판정 (`--check-only` · `--report-only`) |
| `scripts/method-coverage-get.sh` | 변경 메서드별 JaCoCo % (`javap` 줄 표) |
| `skills/kotlin-aitest-environment-create/templates/` | Gradle 블록 · 지원 모듈 · Docker 스크립트 골격 |
| `skills/kotlin-aitest-generate/examples.md` | 테스트 코드 형태 · 시드 함정 |
| `test/` | 스크립트 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 스킬 발동 · 게이트 차단 |

## 사용

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" <기준>               # aiTest + JaCoCo + 판정 (<기준> = 차단 메시지의 ref)
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" --check-only <기준>  # Controller aiTest 존재만
test/diff-coverage-validate.test.sh                                           # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
