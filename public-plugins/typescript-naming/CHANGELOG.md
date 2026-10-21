# CHANGELOG

## 0.1.2

### Fixed
- 정규식 리터럴을 처리하지 않아 `/\/*$/` 의 `/*` 를 블록 주석 시작으로 읽고 뒤의 코드를 전부 건너뛰던 것 (#89) — `node-naming` 의 정규식 판별을 옮겼다

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `typescript-naming@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/typescript-naming-rules.md` (`TS-01` ~ `TS-06`)
- 검증기 `scripts/validate-typescript-naming.sh` — 훅 모드(PreToolUse `Write|Edit` 에서 새로 생긴 위반만 차단)와 CLI 모드(`<파일|디렉터리>` · `--all`)
- `typescript-name-create` 스킬, `/typescript-naming-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
