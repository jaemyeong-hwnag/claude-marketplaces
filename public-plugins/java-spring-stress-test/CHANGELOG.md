# CHANGELOG

## 0.1.2

### Fixed
- `SPR-02` 가 `application.yml` 안 `---` + `on-profile: local` 문서의 `root: DEBUG` 를 막던 것 — dev · local · test 프로필 문서(`---` · `#---`)는 건너뛴다 (#91)
- 훅이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 알아보지 못하던 것 — `common-stress-test` 의 `ST-01` 과 같은 규칙으로 판별한다 (#91)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `java-spring-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/spring-stress-rules.md` (`SPR-01` ~ `SPR-15`), 계측 레시피 `spring-instrumentation-recipe.md`, JMH 절차 `jmh-benchmark.md`
- 무효 설정 탐지기 `scripts/spring-stress-config-validate.sh` — CLI(`[디렉터리]`)와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행일 때만 경고)
- `spring-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
