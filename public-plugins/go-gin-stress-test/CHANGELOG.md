# CHANGELOG

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `go-gin-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/gin-stress-rules.md` (`GIN-01` ~ `GIN-12` 기계 판정, `GIN-20` ~ `GIN-26` AI 판단)
- 계측 레시피 `references/gin-instrumentation-recipe.md`, 마이크로벤치마크 절차 `references/go-microbenchmark.md`
- 무효 설정 탐지기 `scripts/gin-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 에서 부하 도구 실행 때 경고)
- `gin-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
