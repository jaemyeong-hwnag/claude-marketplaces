# CHANGELOG

## 0.1.6

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

## 0.1.5

### Fixed
- 규칙 원본이 `dependency-update` 스킬에 맡긴 "비-common 이 필요한 common 을 빠뜨렸는가" 판단이 스킬 절차에 없던 것 — 1절에 질문을 넣었다 (#205)

## 0.1.4

### Fixed
- eval `cycle-notice` 가 trace 에서 훅 알림을 찾아 훅이 돌아도 실패하던 것 — PostToolUse 알림은 trace 에 남지 않으므로 `last_message` 로 본다 (#122)

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
