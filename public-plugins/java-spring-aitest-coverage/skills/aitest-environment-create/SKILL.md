---
name: aitest-environment-create
description: @AiTest 환경이 없는 Spring Boot(Gradle Groovy) 프로젝트에 테스트 환경을 만들 때 사용한다. test-support 모듈(@AiTest·@AiWebTest, MySQL·PostgreSQL·Redis·RabbitMQ testcontainer)·aiTest 태스크·JaCoCo 리포트·Docker 준비 스크립트를 만들고 스모크로 검증한다. 트리거 — "AiTest 환경 만들어줘", "테스트 인프라 구성", "testcontainers 세팅", "test-support 만들어줘".
---

# @AiTest 환경 생성

규칙 원본: [`references/coverage-rules.md`](../../references/coverage-rules.md) — 컨벤션 · 대상 모듈 · 설정 파일.
파일 골격은 `${CLAUDE_SKILL_DIR}/templates/` 를 Read 해서 채운다. 값은 1절에서 코드 · 설정을 읽어 직접 정한다.

## 인터페이스

- **입력**: 프로젝트 루트 · (선택) 모듈명(기본 `test-support`) · 패키지 · 대상 모듈 · 인프라 · 프로파일
- **출력**: `test-support/`(build.gradle + Java) · `gradle/ai-test.gradle` · `scripts/ensure-docker-for-aitest.sh` · `settings.gradle` · 루트 `build.gradle` 추가 블록 · 첫 대상 모듈의 `TestSupportSmokeAiTest` · (라이브러리 모듈이 있으면) `.claude/java-spring-aitest-coverage.json`
- **통과 게이트**: 사용자 확인 뒤 생성 · `{{` 잔재 0 · `compileAiTestJava` 성공 · 스모크 `aiTestFast` PASS

## 1. 감지 (Read · Grep · Glob)

1. **멈출 때** — 하나라도 해당하면 만들지 않는다
   - `gradle/ai-test.gradle` 이 있다 · `@interface AiTest` 가 있다 · 루트 `build.gradle` 에 `java-spring-aitest-coverage:aitest-environment` 블록이 있다 → 기존 경로를 보고하고 `aitest-generate` 로 넘어간다
   - `settings.gradle.kts` · `build.gradle.kts` 이거나 Gradle 프로젝트가 아니다(Maven 등) → 지원하지 않는다고 보고한다
2. **모듈**: `settings.gradle` 의 `include` 를 읽는다. 있으면 `MULTI=true`, 없으면 단일 모듈
3. **앱 모듈 · 패키지**: `@SpringBootApplication` 을 Grep 해 모듈과 `package` 를 모은다. 여럿이면 공통 접두를 `base_package` 로. 대상 모듈(`aiTestModules`) 기본값 = 앱 모듈 전부
4. **라이브러리 모듈**: 앱 모듈이 아닌 java 서브프로젝트 중 앱 모듈 `build.gradle` 에 `project(':<lib>')` 로 들어가는 것 → `libraryModules = { "<lib>": [그것을 쓰는 앱 모듈] }`
5. **버전**
   - `BOOT_VERSION` = `org.springframework.boot` 플러그인 version · `ext` 변수 · `gradle.properties` · `gradle/libs.versions.toml` 중 찾은 값
   - `TC_VERSION` = testcontainers 버전 변수가 있으면 그 값, 없으면 Boot 2.x → `1.19.7`, Boot 3.x → `1.20.4`, Boot 4.x → Boot BOM 의 `testcontainers.version` (4.0.2 → `2.0.3`)
   - `BOOT4` = Boot 4.x · `TC2` = `TC_VERSION` 이 2.x — 아티팩트 이름(`testcontainers-mysql`) · 패키지(`org.testcontainers.mysql`) · MockMvc 모듈(`spring-boot-webmvc-test`)이 갈린다
   - JDK = `sourceCompatibility` · toolchain → 설정 `javaVersion`
6. **인프라**: 루트 · 모듈 `build.gradle`, `gradle/*.gradle`, `libs.versions.toml` 을 Grep
   - `mysql-connector` · `com.mysql` → `MYSQL` · `org.postgresql` → `POSTGRESQL` (`HAS_DB` = 둘 중 하나)
   - `spring-boot-starter-data-redis` · `redisson` · `lettuce` · `jedis` → `REDIS`
   - `spring-boot-starter-amqp` · `spring-rabbit` → `RABBITMQ`
   - `spring-boot-starter-web` · `spring-boot-starter-webmvc` 가 있으면 `HAS_WEB=true` — `AiWebTest` 도 만든다
7. **설정 키**: 앱 모듈 `src/*/resources/application*.{yml,yaml,properties}`(test 제외)를 점 표기 키로 읽는다
   - datasource: 값이 `jdbc:` 로 시작하는 `…datasource….url|jdbc-url` 키를 **모두** (예 `spring.datasource.url`, `spring.read.datasource.jdbc-url`). 없으면 `spring.datasource` + `url`
   - `DB_NAME` = jdbc URL 경로의 DB 이름, 없으면 `aitest`
   - redis: `…redis….host` 키의 접두를 모두. 없으면 Boot 2 `spring.redis` / Boot 3 `spring.data.redis`
   - rabbitmq: `…rabbitmq….host` 키의 접두를 모두. 없으면 `spring.rabbitmq`
8. **프로파일**: 앱 모듈에 `src/local/resources` 또는 `application-local.*` 이 있으면 `PROFILE=local`, `HAS_PROFILE=true`
9. **저장소**: 지원 모듈에 저장소가 전해지는지 본다 — 루트 `build.gradle` 의 `allprojects { repositories … }` · `subprojects { repositories … }` 나 `settings.gradle` 의 `dependencyResolutionManagement { repositories … }` 가 없으면 `NEED_REPOS=true`. 루트 최상위의 `repositories` 는 루트 프로젝트에만 걸린다
10. 애매한 값(앱 모듈 일부만 대상일 것 같음, 커스텀 키가 인프라 접속 키인지 불명확 등)은 2절에서 묻는다

## 2. 사용자 확인 (필수)

생성 전에 보여주고 확인받는다 — 만들 파일 목록 · 고칠 `settings.gradle` · 루트 `build.gradle` · `aiTestModules` · `libraryModules` · 패키지(`<base_package>.test.support`) · 컨테이너 인프라 · 컨테이너 값으로 덮을 설정 키 · Boot · Testcontainers · JDK 버전. 사용자가 고친 값으로 3절을 한다.

## 3. 생성 (Write · Edit)

### 채우기 규칙

- `{{KEY}}` → 값. `{{#KEY}}…{{/KEY}}` → KEY 가 참이면 안쪽만 남기고 거짓이면 통째로 지운다. `{{^KEY}}…{{/KEY}}` → 반대. 블록은 겹쳐 쓴다(`{{#MYSQL}}{{#TC2}}…{{/TC2}}{{/MYSQL}}`) — 안쪽까지 다 푼다

| KEY | 값 |
|---|---|
| `PACKAGE` · `APP_PACKAGE` | `<base_package>.test.support` · 스모크 테스트를 둘 앱 모듈의 패키지 |
| `MODULE` | `test-support` (사용자 지정 시 그 이름) |
| `BOOT_VERSION` · `TC_VERSION` · `PROFILE` · `DB_NAME` | 1절 값 |
| `MYSQL` · `POSTGRESQL` · `HAS_DB` · `REDIS` · `RABBITMQ` · `HAS_WEB` · `HAS_PROFILE` · `NEED_REPOS` · `MULTI` · `BOOT4` · `TC2` | 참 / 거짓 |
| `INITIALIZERS` | 8칸 들여쓰기, 쉼표 구분: `AiTestPropertyInitializer.class`, `AiTestMainConfigInitializer.class` + 있는 것만 `MySQLTestcontainerInitializer.class` / `PostgreSQLTestcontainerInitializer.class`, `RedisTestcontainerInitializer.class`, `RabbitMQTestcontainerInitializer.class` |
| `DATASOURCE_PROPS` | 16칸, 쉼표 구분. 접두마다 `"<접두>.<url\|jdbc-url>=" + jdbcUrl`, `"<접두>.username=" + DB_USER`, `"<접두>.password=" + DB_PASS` · 끝에 `"spring.datasource.hikari.maximum-pool-size=3"`, `"spring.datasource.hikari.minimum-idle=1"` |
| `REDIS_PROPS` | 16칸, 접두마다 `"<접두>.host=" + host`, `"<접두>.port=" + port` |
| `RABBITMQ_PROPS` | 16칸, 접두마다 `host` · `port` · `"<접두>.username=" + USER` · `"<접두>.password=" + PASS` |
| `MODULES_QUOTED` | `'app-api', 'admin-api'` (중첩 모듈은 `'apps:admin'`) |
| `IMAGES` | 2칸, 한 줄씩: `"mysql:8.0"` 또는 `"postgres:15-alpine"` · `"redis:7-alpine"` · `"rabbitmq:3.13-alpine"` · `TC_VERSION` 이 1.19.x 면 `"testcontainers/ryuk:0.6.0"` |

### 만들 파일

| 템플릿 | 경로 | 조건 |
|---|---|---|
| `gradle/module-build.gradle.tmpl` | `<MODULE>/build.gradle` | 항상 |
| `java/AiTest` · `AiTestPropertyInitializer` · `AiTestMainConfigInitializer` · `DockerEnvironment` | `<MODULE>/src/main/java/<PACKAGE 경로>/<이름>.java` | 항상 |
| `java/AiWebTest` | 같은 디렉터리 | web 의존성 |
| `java/MySQLTestcontainerInitializer` / `PostgreSQLTestcontainerInitializer` | 같은 디렉터리 | 해당 DB |
| `java/RedisTestcontainerInitializer` · `RabbitMQTestcontainerInitializer` | 같은 디렉터리 | 해당 인프라 |
| `gradle/ai-test.gradle.tmpl` | `gradle/ai-test.gradle` | 항상 |
| `scripts/ensure-docker-for-aitest.sh.tmpl` | `scripts/ensure-docker-for-aitest.sh` (실행 권한) | 파일이 없을 때만 |
| `java/TestSupportSmokeAiTest` | `<첫 대상 모듈>/src/test/java/<APP_PACKAGE 경로>/TestSupportSmokeAiTest.java` (단일 모듈이면 루트) | 항상 |

- `settings.gradle` 끝에 `include '<MODULE>'` (이미 있으면 생략, 없으면 파일을 만든다)
- 루트 `build.gradle` 끝에 `gradle/root-block.gradle.tmpl` 을 채운 블록
- `libraryModules` 가 있거나 JDK 를 고정해야 하면 `.claude/java-spring-aitest-coverage.json` (규칙 원본 4절 형식)
- 이미 있는 파일은 덮어쓰지 않는다
- 만든 뒤 `grep -rnE '\{\{[#^/]?[A-Z0-9_]+\}\}' <MODULE> gradle/ai-test.gradle scripts/ensure-docker-for-aitest.sh build.gradle <스모크 테스트>` 가 0건이어야 한다 (`{{.Server.Version}}` 같은 docker format 은 잔재가 아니다)

## 4. 검증

1. JDK 를 프로젝트에 맞춘다 (macOS: `export JAVA_HOME=$(/usr/libexec/java_home -v <버전>)`)
2. `./gradlew :<앱모듈>:compileAiTestJava` (단일 모듈은 `./gradlew compileAiTestJava`)
3. `./gradlew :<앱모듈>:aiTestFast --tests '*TestSupportSmokeAiTest*' -PskipAiTestCoverage` — Docker 가 없으면 `./scripts/ensure-docker-for-aitest.sh` 먼저
4. 실패하면 원인별로 고치고 3 을 다시 한다. 고치는 곳은 지원 모듈 · `gradle/ai-test.gradle` · 생성 블록 안뿐이다
   - 원격 호스트 접속 · `UnknownHost` → 그 설정 키가 initializer 에 없다. 해당 `*TestcontainerInitializer` 의 `TestPropertyValues` 에 더한다
   - 프로파일 설정이 안 읽힘 → `@AiTest` · `@AiWebTest` 의 `@ActiveProfiles` 와 `gradle/ai-test.gradle` 의 `spring.profiles.active` 를 맞춘다
   - 스키마 · 초기 데이터 오류 → 앱 모듈 `src/test/resources/application.yml` 에 최소 override
5. 스모크 PASS 뒤 `TestSupportSmokeAiTest` 를 둘지 지울지 묻는다

## 5. 보고

```
Test-support: <module> | package <pkg> | aiTestModules <a,b> | libraryModules <core→a,b> | infra <mysql·redis>
- 생성: N files · 수정: settings.gradle, build.gradle
- 검증: compileAiTestJava PASS · smoke aiTestFast PASS (<시간>)
- 확인 필요: <추정한 값 · 직접 더한 설정 키>
```

## 금지

- 사용자 확인 없이 생성 · 기존 환경 덮어쓰기 · 프로덕션 코드 수정
- initializer 에 운영 · 개발 자격증명 기록 — 컨테이너 전용 값(`aitest` · `guest`)만
- `{{` 잔재가 남은 채 완료 · 스모크 실행 없이 완료 보고
