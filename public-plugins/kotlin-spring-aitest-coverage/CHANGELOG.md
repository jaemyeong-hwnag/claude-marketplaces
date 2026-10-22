# CHANGELOG

## 0.1.0

### Added
- Kotlin · Spring Boot(Gradle Kotlin DSL) 프로젝트에서 변경 메서드를 `@AiTest` 로 덮게 하는 public 플러그인 (#134). 컨벤션은 `@AiTest` · JVM Test Suite `aiTest` · `src/aiTest/kotlin`
- 훅 `aitest-coverage-validate.sh` (`UserPromptSubmit` 지문 · `Stop` 게이트) — 변경 Controller 의 aiTest 존재(`C-01`), 변경 메서드 JaCoCo 100%(`C-02`), 판정 도구가 없으면 판정 불가로 막는다(`C-09`). jq 없이 돈다
- 스크립트 `diff-coverage-validate.sh` · `method-coverage-get.sh` — 변경 줄 → 메서드를 클래스 파일의 줄 표(`javap -p -s -l`)로 구하고 `@JvmStatic` 브리지 · 같은 줄의 `$default` · `DefaultConstructorMarker` 생성자 · 주 생성자 줄의 접근자를 뺀다
- 스킬 `kotlin-aitest-generate` — 케이스 매트릭스 · 생성자 주입 · MockK · `runTest` · 백틱 이름으로 `@AiTest` · `@AiWebTest` 작성 · 실행
- 스킬 `kotlin-aitest-environment-create` — 대상 모듈 `build.gradle.kts` 의 표시 블록 · Kotlin 지원 모듈 · `@ServiceConnection` 컨테이너 빈(MySQL · PostgreSQL · Redis · RabbitMQ) · Docker 준비 스크립트 · 스모크 테스트
- 프로젝트 설정 `.claude/kotlin-spring-aitest-coverage.json` — `modules` · `libraryModules` · `jdkVersion`. 상태 · ACK 는 `<Gradle 루트>/.claude/kotlin-spring-aitest-coverage/`
