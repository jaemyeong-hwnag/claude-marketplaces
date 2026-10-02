# CHANGELOG

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `java-spring-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/spring-stress-rules.md` (`SPR-01` ~ `SPR-15`), 계측 레시피 `spring-instrumentation-recipe.md`, JMH 절차 `jmh-benchmark.md`
- 무효 설정 탐지기 `scripts/spring-stress-config-validate.sh` — CLI(`[디렉터리]`)와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행일 때만 경고)
- `spring-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
