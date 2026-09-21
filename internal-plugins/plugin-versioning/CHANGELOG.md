# CHANGELOG

## 0.2.0

### Added
- `V-14` — 기준 ref 이후 파일이 바뀐 플러그인은 버전을 올려야 한다. `--since <ref>` 모드 (PR 전에 `--since origin/main`)
- 마켓플레이스 루트 `CHANGELOG.md` 도 `V-04` ~ `V-08` 로 본다. 현재 버전은 `metadata.version`

### Changed
- `V-12` 는 태그 **형식만** 본다. 지금은 없는 플러그인의 태그도 통과한다 — 플러그인을 지우면 `--all` 이 영구히 깨지던 것을 고친다
- `V-11` 이 Claude Code 가 받는 범위를 모두 허용한다 — `||`, `^2.0.0-0`, `2.x`, `2.1.*`, `1.2.3 - 2.3.4`, 연산자 뒤 공백
- 릴리즈 순서를 **CHANGELOG 먼저**로 바꾼다. 중간 상태가 `V-06` 을 어기지 않는다. 태그는 main 에서 머지·설치 확인 뒤에
- `0.x` 에서는 호환성을 깨도 MINOR 를 올린다 (규칙 원본에 명시)
- `### Added` / `Changed` / `Removed` / `Fixed` 분류를 권장한다 (강제하지 않는다)

### Fixed
- 범위가 `*` 한 글자면 현재 디렉터리의 파일 이름으로 확장돼 `V-11` 이 잘못 막던 것

회귀 테스트 TC 26건 추가 (91 → 117).

## 0.1.1

- `plugin.json` 에서 `"hooks": "./hooks/hooks.json"` 제거 — 표준 경로는 자동 로드되므로 중복으로 판정돼 **훅 로딩 전체가 실패하고 있었다** (`claude plugin list` 에 `Hook load failed: Duplicate hooks file detected`). 이 버전부터 훅이 실제로 동작한다

## 0.1.0

- 버전 규칙 원본 `references/versioning-rules.md` 추가 (`V-01`~`V-13`)
- 버전 검증기 `scripts/validate-versioning.sh` 추가 — 훅 모드와 CLI 모드(`--all` · `--marketplace` · `--tag`)
- `Write`/`Edit` PreToolUse(차단)·PostToolUse(알림) 훅 연결
- `version-update` 스킬, `/versioning-validate` 커맨드 추가
