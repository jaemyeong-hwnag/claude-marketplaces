# java-spring-aitest-coverage

Java · Spring Boot(Gradle) 프로젝트에서 **AI 가 바꾼 코드를 `@AiTest` 로 덮게** 한다 — 변경 메서드 케이스 매트릭스 테스트 생성, testcontainer 테스트 환경 생성, 작업 완료 시 변경 메서드 JaCoCo 100% 게이트.

AI 가 코드를 고치고 테스트 없이, 또는 성공 케이스 하나만 쓰고 "완료" 라고 하는 것을 막는다. 판정 기준은 git 로컬 diff 다.

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install java-spring-aitest-coverage@plugin-marketplace --scope project
```

설치한 뒤 `@AiTest` 환경이 없으면 "AiTest 환경 만들어줘" 로 `aitest-environment-create` 를 부른다. 환경이 생기기 전에는 게이트가 꺼져 있다.

필요한 것: `git`, `jq`, JDK, Docker(testcontainer), Gradle Wrapper(`./gradlew`).

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| aitest-generate | 테스트 작성, 통합 테스트, 커버리지 올려, 완료 보류 | 변경 메서드마다 성공 · 실패 · 경계 · 데이터 상태 · 하위호환 · 부작용 · 동시성 매트릭스로 `@AiTest` · `@AiWebTest` · 단위 테스트 작성 → 실행 → 변경 메서드 100% |
| aitest-environment-create | AiTest 환경, 테스트 인프라, testcontainers 세팅 | 프로젝트를 읽어 test-support 모듈 · `gradle/ai-test.gradle` · Docker 준비 스크립트 · 스모크 테스트를 만들고 스모크까지 돌린다 (사용자 확인 뒤) |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| aitest-coverage-validate.sh | UserPromptSubmit | 요청 시작 시점의 `src/main` · `src/test` diff 지문을 남긴다 |
| aitest-coverage-validate.sh | Stop | 이번 요청에서 diff 가 바뀌었으면 변경 Controller 의 `@AiTest`(`C-01`) · 수정 메서드 JaCoCo 100%(`C-02`) · 리포트 최신(`C-03`)을 보고 미충족이면 **완료를 막는다** (exit 2) |

## 주의

- 게이트는 `gradle/ai-test.gradle` 또는 `@interface AiTest` 가 있는 저장소에서만 돈다. 없으면 세션당 한 번 알리기만 한다
- Stop 훅은 Gradle 을 돌리지 않고 **기존 리포트**로 판정한다. 코드를 고친 뒤 `scripts/diff-coverage-validate.sh HEAD` 로 리포트를 갱신해야 통과한다 — `aitest-generate` 가 한다
- 한 번 막힌 뒤 다시 완료하면 허용하고 경고만 남긴다(무한 루프 방지). 주석 · 포맷만 바꾼 경우 등은 `aitest: skip <사유>` 면제를 쓴다 — 게이트 메시지가 ACK 파일 경로를 알려준다
- 지원 범위: Gradle **Groovy DSL** · Spring Boot 2.x / 3.x · Gradle 7 ~ 9 · MySQL · PostgreSQL · Redis · RabbitMQ. Kotlin DSL · Maven · Kotlin 소스(`src/main/kotlin`)는 보지 않는다

## 게이트 조항

| 조항 | 내용 |
|---|---|
| `C-01` | 변경 Controller 마다 그 클래스를 다루는 `*AiTest*` (파일명이 클래스명으로 시작하거나 본문에 단어로 등장) |
| `C-02` | 변경 줄이 속한 메서드의 JaCoCo INSTRUCTION 100% |
| `C-03` | 리포트가 로컬 diff 보다 새롭다 |
| `C-04` | 소비 모듈을 모르는 main 변경은 `*AiTest*` diff 가 있어야 한다 |
| `C-05` ~ `C-08` | 이번 요청에서 diff 가 바뀐 경우만 · 환경 없으면 꺼짐 · 면제 · 무한 루프 방지 |

전체는 [`references/coverage-rules.md`](references/coverage-rules.md).

## 프로젝트 설정

`.claude/java-spring-aitest-coverage.json` — 없어도 된다.

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"] },
  "javaVersion": "11"
}
```

- `modules` 가 없으면 루트 `build.gradle` 의 `aiTestModules`, 그것도 없으면 루트 단일 모듈
- `libraryModules` — core · common 같은 라이브러리 모듈이 바뀌면 소비 모듈의 `aiTest` 로 재고 소비 모듈 리포트에서 판정한다

## 파일

| 경로 | 역할 |
|---|---|
| `references/coverage-rules.md` | 규칙 원본 — 컨벤션 · 조항 · 대상 모듈 · 설정 · 이유 |
| `scripts/aitest-coverage-validate.sh` | 훅 — 지문(`snapshot`) · Stop 게이트 |
| `scripts/diff-coverage-validate.sh` | 로컬 diff 기준 `aiTest` 실행 + 판정 (`--check-only` · `--report-only`) |
| `scripts/method-coverage-get.sh` | 변경 메서드별 JaCoCo % |
| `skills/aitest-environment-create/templates/` | test-support 모듈 · Gradle · Docker 스크립트 골격 |
| `skills/aitest-generate/examples.md` | 테스트 코드 형태 · 시드 함정 |
| `test/` | 스크립트 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 스킬 발동 · 게이트 차단 |

## 사용

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" HEAD               # aiTest + JaCoCo + 판정
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-coverage-validate.sh" --check-only HEAD  # Controller @AiTest 존재만
test/diff-coverage-validate.test.sh                                           # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
