# CHANGELOG

## 0.1.0

### Added
- 변경 메서드를 `@AiTest` 로 덮게 하는 public 플러그인 (#20). 컨벤션은 `@AiTest` · `aiTest` 태스크 · `*AiTest*.java`
- 스킬 `aitest-generate` — 변경 메서드별 케이스 매트릭스로 `@AiTest` · `@AiWebTest` · 단위 테스트 작성 · 실행
- 스킬 `aitest-environment-create` — test-support 모듈 · `gradle/ai-test.gradle` · Docker 준비 스크립트 · 스모크 테스트 생성 (MySQL · PostgreSQL · Redis · RabbitMQ)
- 훅 `aitest-coverage-validate.sh` (`UserPromptSubmit` 지문 · `Stop` 게이트) — 변경 Controller 의 `@AiTest` 존재, 수정 메서드 JaCoCo 100%
- 스크립트 `diff-coverage-validate.sh` · `method-coverage-get.sh`
- 프로젝트 설정 `.claude/java-spring-aitest-coverage.json` — 라이브러리 모듈 → 소비 모듈 매핑, JDK 버전
- 단일 모듈 · 중첩 모듈(`apps:api`) 프로젝트 지원, 라이브러리 모듈 클래스를 소비 모듈 JaCoCo 리포트에 포함
