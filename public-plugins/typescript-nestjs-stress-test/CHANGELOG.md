# CHANGELOG

## 0.1.2

### Fixed
- 훅이 `uv run` · `poetry run` · `python -m` · `timeout N` · `sh -c` 로 감싸거나 한 줄 `for … do` · `if … then` 안의 부하 명령을 알아보지 못하던 것 — `common-stress-test` 의 `ST-01` 과 같은 규칙으로 판별한다 (#91)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `typescript-nestjs-stress-test@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/nestjs-stress-rules.md` (`NST-01` ~ `NST-20`)
- 계측 · 마이크로벤치마크 레시피 `references/nestjs-stress-recipes.md`
- 무효 설정 탐지기 `scripts/nestjs-stress-config-validate.sh` — CLI 모드와 훅 모드(PreToolUse `Bash` 에서 부하 명령이면 경고)
- `nestjs-stress-test-apply` 스킬
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 경고)
