# CHANGELOG

## 0.1.1

### Fixed
- 상위 경로에 `test` · `tests` · `spec` · `fixtures` 가 있으면 프로젝트 전체를 테스트로 보고 건너뛰던 것 — git 최상위 기준 상대 경로로 판정한다 (#96). 훅이 받는 절대 경로에 그대로 대 봤다

## 0.1.0

### Added
- 규칙 원본 `references/performance-rules.md` (`PF-01` ~ `PF-47`), 근거 `performance-methods.md` (업계 · 학술 · 표준 · 도구)
- `performance-validate.sh` — 루프 안 쿼리 · 원격 호출 · await 등 20개 패턴 탐지, `--diff` 로 바뀐 줄만 (PostToolUse `Write|Edit|MultiEdit` 알림, CLI)
- `performance-review` 스킬 — 9개 범주 필수 판정, 규모 가정 · 신뢰도 · 검증 방법이 붙은 지적 (#56)
- `/performance-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 알림)
