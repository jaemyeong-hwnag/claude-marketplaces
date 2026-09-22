# @AiTest 커버리지 규칙 (단일 원본)

AI 가 바꾼 Java 코드가 **무엇으로 덮여야 작업이 끝나는가**를 정한다. 스킬 · 훅 · 스크립트는 모두 이 문서를 따른다.
기계 판정은 `scripts/diff-coverage-validate.sh`, 완료 시점 강제는 `scripts/aitest-coverage-validate.sh`(훅).

## 1. 컨벤션

| 항목 | 값 |
|---|---|
| 통합 테스트 | `@AiTest` (`@SpringBootTest` NONE + testcontainer + `@Tag("AI")`) · `@AiWebTest` (MOCK + MockMvc) |
| 파일 | `<module>/src/test/java/**/*AiTest*.java` — 이 패턴만 `aiTest` 소스셋으로 컴파일되고 `test` 태스크에서는 빠진다 |
| 실행 | `./gradlew :<module>:aiTest` (Docker 준비 포함) · `aiTestFast` (준비 생략, `--tests` 로 대상 지정) |
| 리포트 | `<module>/build/reports/jacoco/aiTestCoverageReport/aiTestCoverageReport.xml` |
| 환경 | `gradle/ai-test.gradle` · 루트 `build.gradle` 의 `aiTestModules` · 지원 모듈(기본 `test-support`) |

## 2. 조항

| 조항 | 내용 | 판정 |
|---|---|---|
| `C-01` | 변경된 `*Controller` 마다 같은 모듈에 그 클래스를 다루는 `*AiTest*` 가 있다 — 파일명이 클래스명으로 시작하거나 본문에 클래스명이 단어로 나온다 | 차단 |
| `C-02` | 변경 줄이 속한 메서드의 JaCoCo INSTRUCTION 커버리지가 100% 다. 새 파일은 전 줄이 변경이다 | 차단 |
| `C-03` | 판정에 쓰는 리포트가 로컬 diff 의 main · test 파일보다 새롭다 | 차단 |
| `C-04` | 소비 모듈을 특정할 수 없는 main 변경(설정에 없는 라이브러리 모듈 · mapper 만)은 로컬 diff 에 `*AiTest*` 가 있어야 한다 | 차단 |
| `C-05` | 게이트는 이번 요청에서 대상 경로(`src/main/java` · `src/main/resources` · `src/test/java`)의 diff 가 바뀐 경우에만 돈다 — 질문 · 조회 응답은 막지 않는다 | - |
| `C-06` | `@AiTest` 환경(`gradle/ai-test.gradle` 또는 `@interface AiTest`)이 없는 저장소에서는 게이트가 꺼진다. 세션당 한 번 알린다 | 알림 |
| `C-07` | 면제는 ACK 파일의 `aitest: skip <사유>` 한 줄로만 한다. 사용자에게 알리고 쓴다. 세션 끝까지 유효하다 | - |
| `C-08` | 한 번 막힌 뒤 다시 완료하면(`stop_hook_active`) 허용하고 미충족을 `systemMessage` 로 남긴다 — 무한 루프 방지 | 알림 |

- 판정 기준은 **git 로컬 수정사항**(HEAD 대비 tracked + untracked)이다. 어떤 도구로 고쳤는지, 커밋했는지와 무관하다
- `C-02` 보강은 **최대 3회**다. 3회 보강 뒤에도 100% 가 아니면 멈추고 남은 줄 · 이유(도달 불가 분기, 방어 코드 등)를 사용자에게 보고한다
- `-PskipAiTestCoverage` 는 사용자가 명시로 요청할 때만 쓴다
- 순수 단위 테스트(`*Test.java`)는 좋지만 **게이트는 `aiTest` 리포트만 인정한다**

## 3. 대상 모듈

| 순서 | 출처 | 형식 |
|---|---|---|
| 1 | 설정 `.modules` | `["app-api", "apps:admin"]` |
| 2 | 루트 `build.gradle` 의 `aiTestModules = [...]` | 환경 생성이 쓰는 목록. Gradle 적용 대상과 같다 |
| 3 | 없음 | 루트 단일 모듈(`.`) |

- 모듈 이름은 Gradle 프로젝트 경로에서 앞 `:` 를 뺀 것이다. 디렉터리는 `:` 를 `/` 로 바꾼 경로다 (`apps:admin` → `apps/admin/`)
- 파일은 디렉터리 접두가 가장 긴 모듈에 속한다

## 4. 프로젝트 설정 — `.claude/java-spring-aitest-coverage.json`

없어도 된다. 있으면 `jq` 가 필요하다.

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"], "common": ["app-api"] },
  "javaVersion": "11"
}
```

| 키 | 뜻 | 없으면 |
|---|---|---|
| `modules` | 대상 앱 모듈 | 3절 2 · 3 |
| `libraryModules` | 라이브러리 모듈 → 그 클래스를 쓰는 대상 모듈. 라이브러리 변경은 소비 모듈의 `aiTest` 로 재고, 소비 모듈 리포트에서 판정한다 | 라이브러리 변경은 `C-04` |
| `javaVersion` | `aiTest` 를 돌릴 JDK (macOS `/usr/libexec/java_home -v`) | 현재 `JAVA_HOME` |

`gradle/ai-test.gradle` 의 리포트는 대상 · 지원 모듈이 아닌 java 서브프로젝트의 클래스를 함께 담는다. 그래서 `libraryModules` 에 적은 라이브러리 클래스가 소비 모듈 리포트에 나온다.

## 5. 왜 이렇게 하는가

- **Controller 는 존재, 나머지는 커버리지** — Controller 는 바인딩 · 인증 · 예외 핸들러처럼 서비스 호출로는 안 보이는 경계가 있어 테스트 자체가 있어야 한다. 서비스 · 리포지토리 변경은 어디서 호출되든 메서드가 덮이면 된다
- **메서드 단위 100%** — 변경 줄만 보면 같은 메서드 안에서 새 분기가 기존 경로를 바꾼 경우를 놓친다. 파일 전체를 보면 손대지 않은 레거시가 게이트를 막는다
- **Stop 에서 `--report-only`** — Stop 훅에서 Gradle 을 돌리면 수 분이 걸리고 시간 제한에 걸린다. AI 가 `diff-coverage-validate.sh` 로 리포트를 만들고, 훅은 리포트가 diff 보다 새롭고 100% 인지만 본다
- **환경이 없으면 끄는 이유** — public 플러그인이라 `@AiTest` 를 쓰지 않는 저장소에도 설치될 수 있다. 환경 생성은 빌드 구조를 바꾸므로 사용자 확인 뒤에만 한다
- **testcontainer 를 쓰는 이유** — 내부 서비스 · 리포지토리를 목으로 바꾸면 통합 테스트의 의미가 사라진다. 외부 경계(HTTP 클라이언트 · MQ 발행 · 검색엔진)만 목으로 둔다
- **대상 코드를 고치지 않는 이유** — 테스트 실패는 기존 버그를 드러낸 것일 수 있다. 보고하고 사용자가 정한다
