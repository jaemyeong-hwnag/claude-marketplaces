# CHANGELOG

## 0.1.3

### Fixed
- `--all` 이 플러그인을 하나도 찾지 못해도(마켓플레이스 루트가 아니거나 없는 경로) 통과하던 것을 실행 오류(1)로 낸다 (#88). README 사용 예도 저장소 루트 기준 경로로 고쳤다

## 0.1.2

### Fixed
- 분석(jq)이 실패하면 아무 조항도 보고하지 않고 통과하던 것을 오류로 보고한다 (#60)
- `version` 이 문자열이 아닌 의존이 분석 전체를 멈추던 것 — `D-09` 는 문자열 범위만 본다

## 0.1.1

### Added
- eval 케이스 둘 — 스킬 발동 · 훅 차단 (`evals/`). `plugin-workflow` 의 `eval-all.sh` 로 돈다

## 0.1.0

### Added
- 의존성 규칙 원본 `references/dependency-rules.md` (`D-01` ~ `D-11`)
- 검증기 `scripts/validate-dependency.sh` — `--all` · `--dependents` · 플러그인 단위, `PostToolUse` 알림
- 순환 탐지와 버전 범위 교집합(`~` `^` `=` `>=` `<` `x` `*` 와 그 조합)
- `dependency-update` 스킬, `/dependency-validate` 커맨드
