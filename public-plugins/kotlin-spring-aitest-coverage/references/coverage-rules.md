# Kotlin @AiTest 커버리지 규칙 (단일 원본)

AI 가 바꾼 Kotlin 코드가 **무엇으로 덮여야 작업이 끝나는가**를 정한다. 스킬 · 훅 · 스크립트는 모두 이 문서를 따른다.
기계 판정은 `scripts/diff-coverage-validate.sh` · `scripts/method-coverage-get.sh`, 완료 시점 강제는 `scripts/aitest-coverage-validate.sh`(훅).

## 1. 컨벤션

| 항목 | 값 |
|---|---|
| 통합 테스트 | `@AiTest` (`@SpringBootTest` NONE + `@ServiceConnection` 컨테이너 + 생성자 주입) · `@AiWebTest` (MOCK + MockMvc) |
| 파일 | `<module>/src/aiTest/kotlin/**/*.kt` — JVM Test Suite `aiTest` 의 소스. `test` 태스크와 섞이지 않는다 |
| 실행 | `./gradlew :<module>:compileAiTestKotlin :<module>:aiTest` — 끝나면 `aiTestReport` 가 따라 돈다. Docker 데몬이 응답하지 않으면 준비 스크립트가 먼저 돈다 |
| 리포트 | `<module>/build/reports/jacoco/aiTestReport/aiTestReport.xml` (JaCoCo 0.8.15) |
| 환경 | 대상 모듈 `build.gradle.kts` 의 `// >>> kotlin-spring-aitest-coverage` … `// <<< kotlin-spring-aitest-coverage` 블록 · 지원 모듈(기본 `test-support`) |
| 대상 소스 | `src/main/kotlin/**/*.kt` · `src/main/java/**/*.kt` · `src/main/resources/**/*[Mm]apper*.xml`. `.java` 는 보지 않는다 (`java-spring-aitest-coverage` 의 몫) |

## 2. 조항

| 조항 | 내용 | 판정 |
|---|---|---|
| `C-01` | 변경 파일 안의 `@RestController` · `@Controller` 클래스마다 같은 모듈 `src/aiTest/kotlin` 본문에 그 클래스 이름이 단어로, 또는 `<클래스 이름>…AiTest` 식별자로 나온다. 파일 이름은 보지 않는다. 지운 파일은 대상이 아니다 | 차단 |
| `C-02` | 변경 실행 줄이 속한 메서드(3절)의 JaCoCo INSTRUCTION 커버리지가 100% 다. 새 파일은 전 줄이 변경이다 | 차단 |
| `C-03` | 판정에 쓰는 리포트가 로컬 diff 의 그 모듈 `src/` · 소비하는 라이브러리 `src/main/` 파일보다 새롭다 | 차단 |
| `C-04` | 소비 모듈을 특정할 수 없는 main 변경(설정에 없는 라이브러리 모듈 · mapper 만)은 로컬 diff 에 `src/aiTest/kotlin` 변경이 있어야 한다 | 차단 |
| `C-05` | 게이트는 이번 요청에서 대상 경로(`src/main/kotlin` · `src/main/java` · `src/main/resources` · `src/aiTest`)의 diff 가 바뀐 경우에만 돈다 — 질문 · 조회 응답은 막지 않는다 | - |
| `C-06` | 환경 블록이 있는 `build.gradle.kts` 가 없는 저장소에서는 게이트가 꺼진다. 세션당 한 번 알린다. Gradle Kotlin DSL 이 아닌 저장소(Gradle 루트에 `settings.gradle.kts` · `build.gradle.kts` 가 없음)는 알리지도 않는다 | 알림 |
| `C-07` | 면제는 ACK 파일의 `aitest: skip <사유>` 한 줄로만 한다. 사용자에게 알리고 쓴다. 세션 끝까지 유효하다 | - |
| `C-08` | 한 번 막힌 뒤 다시 완료하면(`stop_hook_active`) 허용하고 미충족을 `systemMessage` 로 남긴다 — 무한 루프 방지 | 알림 |
| `C-09` | 판정 도구가 없으면(javap · 리포트에 나온 클래스의 클래스 파일) 판정 불가로 막는다. 조용히 통과하지 않는다 | 차단 |

- 판정 기준은 **요청 시작 때의 HEAD 대비** 수정사항(tracked + untracked)이다. 어떤 도구로 고쳤는지, 요청 안에서 커밋 · push 했는지와 무관하다
  - 요청 시작 HEAD 와 지금 작업 트리의 **내용 차이**로 본다 — amend · squash · 리베이스로 커밋이 바뀌어도 요청 전에 있던 코드는 이번 변경이 아니다
  - 요청 시작 때의 원격 기본 브랜치가 지금 HEAD 에 합쳐져 있으면 그 원격과도 다른 파일만 본다 — 요청 전에 받아둔 원격을 합치거나 그 위로 리베이스해도 원격 변경은 뺀다. 요청 안에서 받아온(fetch · pull) 커밋은 push 와 구별할 수 없어 이번 변경으로 본다
- 경로는 Gradle 루트 기준이다 — 프로젝트 디렉터리에서 git 루트까지 올라가며 `settings.gradle(.kts)` · `gradlew` 가 있는 가장 가까운 곳. git 루트가 그 위에 있어도(모노레포), 모듈 디렉터리에서 세션을 열어도 같다
- `C-02` 보강은 **최대 3회**다. 3회 보강 뒤에도 100% 가 아니면 멈추고 남은 줄 · 이유(도달 불가 분기, 방어 코드 등)를 사용자에게 보고한다
- `-PskipAiTestCoverage` 는 사용자가 명시로 요청할 때만 쓴다
- 순수 단위 테스트(`src/test/kotlin`)는 좋지만 **게이트는 `aiTest` 리포트만 인정한다**

## 3. 변경 줄 → 메서드

한 `.kt` 파일은 여러 JVM 클래스가 된다(`Foo` · `Foo$Companion` · `FooKt` · 다른 최상위 클래스). 그래서 파일 단위로 본다.

1. 리포트에서 소스의 `package` 선언(없으면 루트) 패키지의 `sourcefilename` 이 그 파일인 클래스를 모두 후보로 본다
2. 변경 실행 줄 = 변경 줄 ∩ 리포트 `sourcefile` 의 `mi + ci > 0` 줄
3. 후보 클래스마다 `<모듈>/build/classes/kotlin/main/<클래스>.class` 를 `javap -p -s -l` 로 읽어 메서드별 줄 집합을 만든다. 파일 줄 수를 넘는 줄(인라인 코드의 SMAP 줄)은 버린다
4. 변경 실행 줄마다 그 줄을 가진 메서드 중 리포트에서 명령이 있는 것(JaCoCo 가 걸러내지 않은 것)을 고르고, 아래를 뺀다. 빼고 나서 하나도 안 남으면 뺀 것을 되살린다 (브리지는 되살리지 않는다)

| 뺄 것 | 알아보는 법 | 이유 |
|---|---|---|
| `@JvmStatic` 브리지 | 바깥 클래스의 static 메서드 중 `<클래스>$Companion` 에 같은 이름 · desc 가 있는 것 — 어느 줄이든 | JaCoCo 0.8.15 에서도 미커버로 남고, 브리지만 가진 줄(닫는 `}`)이 있다. companion 메서드로 판정한다 |
| `name$default` | 같은 줄에 `name` 이 있을 때 | 본문을 바꿨을 때 기본값 생략 호출까지 요구하지 않는다. 기본값 식 · 시그니처 줄에는 `name$default` 만 있어 그 줄을 바꾸면 생략 호출을 요구한다 |
| `<init>(…, DefaultConstructorMarker)` | 같은 줄에 다른 `<init>` 이 있을 때 | 위와 같다 |
| 줄이 그 줄 하나뿐인 `get*` · `set*` · `is*` | 같은 줄에 접근자 아닌 메서드가 남아 있을 때 | 주 생성자 · data class 헤더 줄을 바꾸면 쓰지 않는 접근자까지 100% 를 요구한다 |

5. 고른 메서드마다 리포트의 같은 `name` + `desc` 의 INSTRUCTION `missed == 0` 이면 통과다

- `init` 블록 · 프로퍼티 초기화식은 주 생성자 `<init>` 으로, 람다 본문은 `<바깥>$lambda$N` 으로, 로컬 함수는 `<바깥>$<로컬>` 로, 최상위 함수는 `<파일>Kt` 로 판정된다
- open 클래스의 `suspend` 함수 본문은 `name$suspendImpl` 에 있다
- 표시 이름에서 `internal` 의 `$<Kotlin 모듈 이름>` 과 value class 의 `-<hash>` 는 뗀다
- `javap` 은 `$AITEST_JAVAP` → 설정 `jdkVersion` 의 JDK(`JAVA_HOME`) → `PATH` 순으로 찾는다

## 4. 대상 모듈

| 순서 | 출처 | 형식 |
|---|---|---|
| 1 | 설정 `.modules` | `["app-api", "apps:admin"]` |
| 2 | 환경 블록이 있는 `build.gradle.kts` 의 디렉터리 | 환경 생성이 블록을 넣은 모듈 |
| 3 | 없음 | 루트 단일 모듈(`.`) |

- 모듈 이름은 Gradle 프로젝트 경로에서 앞 `:` 를 뺀 것이다. 디렉터리는 `:` 를 `/` 로 바꾼 경로다 (`apps:admin` → `apps/admin/`)
- 파일은 디렉터리 접두가 가장 긴 모듈에 속한다

## 5. 프로젝트 설정 — `.claude/kotlin-spring-aitest-coverage.json`

Gradle 루트에 둔다. 없어도 된다. 있으면 `jq` 가 필요하다 (훅 자체는 jq 없이 돈다).

```json
{
  "modules": ["app-api", "admin-api"],
  "libraryModules": { "core": ["app-api", "admin-api"], "common": ["app-api"] },
  "jdkVersion": "17"
}
```

| 키 | 뜻 | 없으면 |
|---|---|---|
| `modules` | 대상 앱 모듈 | 4절 2 · 3 |
| `libraryModules` | 라이브러리 모듈 → 그 클래스를 쓰는 대상 모듈. 라이브러리 변경은 소비 모듈의 `aiTest` 로 재고, 소비 모듈 리포트에서 판정한다 | 라이브러리 변경은 `C-04` |
| `jdkVersion` | `aiTest` · `javap` 를 돌릴 JDK (macOS `/usr/libexec/java_home -v`) | 현재 `JAVA_HOME` |

상태(`<세션>.base` · `.turn` · `.noenv`)와 ACK(`<세션>.ack`)는 `<Gradle 루트>/.claude/kotlin-spring-aitest-coverage/` 에 둔다. 디렉터리 안의 `.gitignore` 가 전부 무시한다.

## 6. 왜 이렇게 하는가

- **Controller 는 존재, 나머지는 커버리지** — Controller 는 바인딩 · 인증 · 예외 핸들러처럼 서비스 호출로는 안 보이는 경계가 있어 테스트 자체가 있어야 한다. 서비스 · 리포지토리 변경은 어디서 호출되든 메서드가 덮이면 된다
- **메서드 단위 100%** — 변경 줄만 보면 같은 메서드 안에서 새 분기가 기존 경로를 바꾼 경우를 놓친다. 파일 전체를 보면 손대지 않은 레거시가 게이트를 막는다
- **줄 표로 메서드를 고르는 이유** — Kotlin 은 시작 줄 정렬이 틀린다. `init` 블록은 앞 메서드 사이에 흩어져 있고, 로컬 함수는 바깥 함수보다 앞줄에서 시작하고, 람다 · `$default` · 접근자는 같은 줄에 겹친다
- **판정 도구가 없으면 막는 이유** — 판정을 건너뛰면 게이트가 조용히 꺼진다. 막고 무엇이 없는지 알린다
- **Stop 에서 `--report-only`** — Stop 훅에서 Gradle 을 돌리면 수 분이 걸리고 시간 제한에 걸린다. AI 가 `diff-coverage-validate.sh` 로 리포트를 만들고, 훅은 리포트가 diff 보다 새롭고 100% 인지만 본다
- **환경이 없으면 끄는 이유** — public 플러그인이라 `@AiTest` 를 쓰지 않는 저장소에도 설치될 수 있다. 환경 생성은 빌드 구조를 바꾸므로 사용자 확인 뒤에만 한다
- **testcontainer 를 쓰는 이유** — 내부 서비스 · 리포지토리를 목으로 바꾸면 통합 테스트의 의미가 사라진다. 외부 경계(HTTP 클라이언트 · MQ 발행 · 검색엔진)만 목으로 둔다
- **대상 코드를 고치지 않는 이유** — 테스트 실패는 기존 버그를 드러낸 것일 수 있다. 보고하고 사용자가 정한다
- **Java 판과 이름을 나누는 이유** — 상태 · 설정 · 환경 표시 · 스킬 이름이 같으면 두 판을 같이 설치했을 때 한쪽을 지우면 다른 쪽이 깨진다
