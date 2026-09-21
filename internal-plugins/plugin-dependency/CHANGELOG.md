# CHANGELOG

## 0.1.1

### Added
- eval 케이스 둘 — 스킬 발동 · 훅 차단 (`evals/`). `plugin-workflow` 의 `eval-all.sh` 로 돈다

## 0.1.0

### Added
- 의존성 규칙 원본 `references/dependency-rules.md` (`D-01` ~ `D-11`)
- 검증기 `scripts/validate-dependency.sh` — `--all` · `--dependents` · 플러그인 단위, `PostToolUse` 알림
- 순환 탐지와 버전 범위 교집합(`~` `^` `=` `>=` `<` `x` `*` 와 그 조합)
- `dependency-update` 스킬, `/dependency-validate` 커맨드
