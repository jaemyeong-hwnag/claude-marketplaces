---
name: kotlin-aitest-environment-create
description: Kotlin · Spring Boot(Gradle Kotlin DSL) 프로젝트에 @AiTest 환경이 없을 때 사용한다. 대상 모듈 build.gradle.kts 의 aiTest 블록 · Kotlin 지원 모듈(@AiTest · @AiWebTest · @ServiceConnection 컨테이너) · Docker 준비 스크립트를 만들고 스모크로 검증한다. 트리거 — "Kotlin AiTest 환경 만들어줘", "테스트 인프라 구성", "testcontainers 세팅".
---

# Kotlin @AiTest 환경 생성

규칙 원본: [`references/coverage-rules.md`](../../references/coverage-rules.md) — 컨벤션 · 대상 모듈 · 설정 파일.
파일 골격은 `${CLAUDE_SKILL_DIR}/templates/` 를 Read 해서 채운다. 값은 1절에서 코드 · 설정을 읽어 직접 정한다.

## 인터페이스

- **입력**: 프로젝트 루트 · (선택) 지원 모듈 이름(기본 `test-support`) · 패키지 · 대상 모듈 · 인프라 · 프로파일
- **출력**: `test-support/`(build.gradle.kts + Kotlin) · 대상 모듈 `build.gradle.kts` 끝의 표시 블록 · `scripts/ensure-docker-for-aitest.sh` · `settings.gradle.kts` 의 `include` · 첫 대상 모듈의 `src/aiTest/kotlin/.../TestSupportSmokeAiTest.kt` · (필요하면) `.claude/kotlin-spring-aitest-coverage.json`
- **통과 게이트**: 사용자 확인 뒤 생성 · `{{` 잔재 0 · `compileAiTestKotlin` 성공 · 스모크 `aiTest` PASS

## 1. 감지 (Read · Grep · Glob)

1. **멈출 때** — 하나라도 해당하면 만들지 않는다
   - 어느 `build.gradle.kts` 에 `// >>> kotlin-spring-aitest-coverage` 블록이 있다 · `annotation class AiTest` 가 있다 → 기존 경로를 보고하고 `kotlin-aitest-generate` 로 넘어간다
   - 대상 모듈에 Java 판 환경(`gradle/ai-test.gradle` 적용 · `java-spring-aitest-coverage:aitest-environment` 블록)이 있다 → `aiTest` 태스크가 겹친다고 보고한다
   - `settings.gradle` · `build.gradle`(Groovy DSL)이거나 Gradle 프로젝트가 아니다(Maven 등) → 지원하지 않는다고 보고한다
   - Spring Boot 가 3.1 미만(`@ServiceConnection` 없음)이거나 Kotlin 이 1.x 다 → 지원하지 않는다고 보고한다
2. **모듈**: `settings.gradle.kts` 의 `include(…)` 를 읽는다. 없으면 루트 단일 모듈(대상 = `.`)
3. **앱 모듈 · 패키지**: `@SpringBootApplication` 을 Grep 해 모듈과 `package` 를 모은다. 여럿이면 공통 접두를 `base_package` 로. 대상 모듈 기본값 = 앱 모듈 전부
4. **라이브러리 모듈**: 앱 모듈이 아닌 Kotlin 서브프로젝트 중 앱 모듈 `build.gradle.kts` 에 `project(":<lib>")` 로 들어가는 것 → `libraryModules = { "<lib>": [그것을 쓰는 앱 모듈] }`, 그 앱 모듈 블록의 `LIBRARY_DIRS_QUOTED`
5. **버전**
   - `BOOT_VERSION` = `id("org.springframework.boot") version "…"` · `gradle.properties` · `gradle/libs.versions.toml` 중 찾은 값. `BOOT4` = 4.x — Boot BOM 이 Testcontainers 2 를 고르므로 `TC2` = `BOOT4`
   - `KOTLIN_JVM_PLUGIN` = 루트 `plugins {}` 에 `kotlin("jvm")` 이 있으면(`apply false` 포함) `kotlin("jvm")`, 없으면 `kotlin("jvm") version "<프로젝트의 Kotlin 버전>"`
   - `JDK_VERSION` = `kotlin { jvmToolchain(N) }` · `JavaVersion.VERSION_N` · `jvmTarget` → 설정 `jdkVersion`
6. **인프라**: 루트 · 모듈 `build.gradle.kts`, `libs.versions.toml` 을 Grep
   - `mysql-connector` · `com.mysql` → `MYSQL` · `org.postgresql` → `POSTGRESQL` (`HAS_DB` = 둘 중 하나)
   - `spring-boot-starter-data-redis` · `redisson` · `lettuce` · `jedis` → `REDIS`
   - `spring-boot-starter-amqp` · `spring-rabbit` → `RABBITMQ`
   - `spring-boot-starter-web` · `spring-boot-starter-webmvc` → `HAS_WEB` — `AiWebTest` 도 만든다
   - `kotlinx-coroutines` → `COROUTINES` — `kotlinx-coroutines-test` 를 지원 모듈에 둔다
7. **목 라이브러리**: `io.mockk` · `springmockk` · `mockito-kotlin` 중 프로젝트에 있는 것을 쓴다. 없으면 `ADD_MOCKK` — SpringMockK(Boot 4 → `5.0.1`, Boot 3 → `4.0.2`, MockK 를 같이 가져온다)를 지원 모듈에 둔다. 새 라이브러리이므로 2절 확인 목록에 넣는다
8. **설정 키**: 앱 모듈 `src/main/resources/application*.{yml,yaml,properties}` 를 점 표기 키로 읽는다. `@ServiceConnection` 은 표준 키(`spring.datasource.*` · `spring.data.redis.*` · `spring.rabbitmq.*`)만 덮는다
   - 그 밖의 접속 키(`spring.read.datasource.jdbc-url` · 직접 만든 클라이언트의 host 등)가 있으면 `CUSTOM_PROPS` — Boot 3.4 이상에서만(`DynamicPropertyRegistrar`). 3.1 ~ 3.3 이면 2절에서 알리고 소비 모듈 `src/aiTest/resources/application.yml` 로 막는 방법을 묻는다
9. **프로파일**: 앱 모듈에 `application-local.*` 이 있으면 `PROFILE=local`, `HAS_PROFILE`
10. **저장소**: 지원 모듈에 저장소가 전해지는지 본다 — 루트의 `allprojects { repositories … }` · `subprojects { repositories … }` 나 `settings.gradle.kts` 의 `dependencyResolutionManagement { repositories … }` 가 없으면 `NEED_REPOS`
11. 애매한 값(앱 모듈 일부만 대상일 것 같음, 커스텀 키가 인프라 접속 키인지 불명확 등)은 2절에서 묻는다

## 2. 사용자 확인 (필수)

생성 전에 보여주고 확인받는다 — 만들 파일 목록 · 고칠 `settings.gradle.kts` · 블록을 넣을 `build.gradle.kts` · 대상 모듈 · `libraryModules` · 패키지(`<base_package>.test.support`) · 컨테이너 인프라 · 컨테이너로 덮을 비표준 키 · 지원 모듈에 새로 넣는 라이브러리(SpringMockK · coroutines-test) · Boot · Kotlin · JDK 버전 · 4절에서 Docker 준비 스크립트를 돌릴 때 바뀌는 사용자 전역 상태(데몬이 응답하지 않을 때만: Colima 기동 또는 Docker Desktop 실행 · `docker context use colima` · 홈의 `~/.testcontainers.properties` 에 `testcontainers.reuse.enable=true` 추가). 사용자가 고친 값으로 3절을 한다.

## 3. 생성 (Write · Edit)

### 채우기 규칙

- `{{KEY}}` → 값. `{{#KEY}}…{{/KEY}}` → KEY 가 참이면 안쪽만 남기고 거짓이면 통째로 지운다. `{{^KEY}}…{{/KEY}}` → 반대. 블록은 겹쳐 쓴다(`{{#MYSQL}}{{#TC2}}…{{/TC2}}{{/MYSQL}}`) — 안쪽까지 다 푼다

| KEY | 값 |
|---|---|
| `PACKAGE` · `APP_PACKAGE` | `<base_package>.test.support` · 스모크 테스트를 둘 앱 모듈의 패키지 |
| `SUPPORT_PROJECT` | `:test-support` (사용자 지정 시 그 이름) |
| `BOOT_VERSION` · `JDK_VERSION` · `PROFILE` · `SPRINGMOCKK_VERSION` · `KOTLIN_JVM_PLUGIN` | 1절 값 |
| `MYSQL` · `POSTGRESQL` · `HAS_DB` · `REDIS` · `RABBITMQ` · `HAS_WEB` · `HAS_PROFILE` · `NEED_REPOS` · `BOOT4` · `TC2` · `ADD_MOCKK` · `COROUTINES` · `LIBRARIES` · `CUSTOM_PROPS` | 참 / 거짓 |
| `LIBRARY_DIRS_QUOTED` | 그 대상 모듈이 쓰는 라이브러리 모듈 디렉터리: `"core", "libs/common"` |
| `CUSTOM_PROPS_PARAMS` | 쓰는 컨테이너 빈: `postgresContainer: PostgreSQLContainer<*>` (TC2 는 `<*>` 없음), `redisContainer: GenericContainer<*>` |
| `CUSTOM_PROPS_LINES` | 12칸, 키마다 한 줄: `registry.add("spring.read.datasource.jdbc-url") { postgresContainer.jdbcUrl }` · `username` · `password` · `{ redisContainer.host }` · `{ redisContainer.getMappedPort(6379) }` |
| `IMAGES` | 2칸, 한 줄씩: `"mysql:8.0"` 또는 `"postgres:15-alpine"` · `"redis:7-alpine"` · `"rabbitmq:3.13-alpine"` |

### 만들 파일

| 템플릿 | 경로 | 조건 |
|---|---|---|
| `gradle/module-build.gradle.kts.tmpl` | `<MODULE>/build.gradle.kts` | 항상 |
| `kotlin/AiTest` · `AiTestContainers` | `<MODULE>/src/main/kotlin/<PACKAGE 경로>/<이름>.kt` (프로젝트가 공통 루트 패키지 디렉터리를 생략하면 그 관례를 따른다) | 항상 |
| `kotlin/AiWebTest` | 같은 디렉터리 | `HAS_WEB` |
| `gradle/aitest-block.gradle.kts.tmpl` | 대상 모듈마다 `build.gradle.kts` **끝에** 붙인다 (단일 모듈은 루트) | 항상 |
| `scripts/ensure-docker-for-aitest.sh.tmpl` | `scripts/ensure-docker-for-aitest.sh` (실행 권한) | 파일이 없을 때만 |
| `kotlin/TestSupportSmokeAiTest` | `<첫 대상 모듈>/src/aiTest/kotlin/<APP_PACKAGE 경로>/TestSupportSmokeAiTest.kt` | 항상 |

- `settings.gradle.kts` 끝에 `include("<MODULE>")` (이미 있으면 생략)
- `libraryModules` 가 있거나 JDK 를 고정해야 하면 `.claude/kotlin-spring-aitest-coverage.json` (규칙 원본 5절 형식)
- 이미 있는 파일은 덮어쓰지 않는다. 블록은 대상 모듈 하나에 하나만 둔다 — 블록이 곧 대상 모듈 표시다
- 만든 뒤 `grep -rnE '\{\{[#^/]?[A-Z0-9_]+\}\}' <MODULE> scripts/ensure-docker-for-aitest.sh <대상 build.gradle.kts> <스모크 테스트>` 가 0건이어야 한다 (`{{.Server.Version}}` 같은 docker format 은 잔재가 아니다)

## 4. 검증

1. JDK 를 프로젝트에 맞춘다 (macOS: `export JAVA_HOME=$(/usr/libexec/java_home -v <버전>)`)
2. `./gradlew --warning-mode all :<앱모듈>:compileAiTestKotlin` (단일 모듈은 `./gradlew compileAiTestKotlin`) — 이 블록에서 나온 deprecation 이 없어야 한다
3. `./gradlew :<앱모듈>:aiTest --tests '*TestSupportSmokeAiTest*' -PskipAiTestCoverage` — Docker 데몬이 응답하지 않으면 2절에서 확인받은 경우에만 준비 스크립트가 돈다(`ensureDockerForAiTest`). 확인받지 않았으면 `-PskipDockerEnsure` 로 돌리고 데몬이 필요하다고 보고한다
4. 실패하면 원인별로 고치고 3 을 다시 한다. 고치는 곳은 지원 모듈 · 생성 블록 안뿐이다
   - 원격 호스트 접속 · `UnknownHost` → 그 설정 키가 `@ServiceConnection` 이 덮지 않는 키다. `CUSTOM_PROPS` 에 더한다
   - `Cannot access … it is internal` → 블록의 `associateWith(main)` 이 빠졌다
   - 프로파일 설정이 안 읽힘 → `@AiTest` · `@AiWebTest` 의 `@ActiveProfiles` 와 블록의 `spring.profiles.active` 를 맞춘다
   - 스키마 · 초기 데이터 오류 → 앱 모듈 `src/aiTest/resources/application.yml` 에 최소 override
5. 스모크 PASS 뒤 `TestSupportSmokeAiTest` 를 둘지 지울지 묻는다

## 5. 보고

```
Test-support: <module> | package <pkg> | modules <a,b> | libraryModules <core→a,b> | infra <mysql·redis>
- 생성: N files · 수정: settings.gradle.kts, <a>/build.gradle.kts
- 검증: compileAiTestKotlin PASS · smoke aiTest PASS (<시간>)
- 확인 필요: <추정한 값 · 새로 넣은 라이브러리 · 직접 더한 설정 키>
```

## 금지

- 사용자 확인 없이 생성 · 기존 환경 덮어쓰기 · 프로덕션 코드 수정
- 블록 밖의 빌드 설정 수정 (`include` 한 줄 제외)
- 컨테이너에 운영 · 개발 자격증명 기록 — 컨테이너 기본값만
- `{{` 잔재가 남은 채 완료 · 스모크 실행 없이 완료 보고
