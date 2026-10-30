# CHANGELOG

## 0.1.3

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 이름 검사 없이 `Write` · `Edit` 를 통과시키던 것 (#153, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.2

### Fixed
- Windows 가 정한 환경 변수(`SystemRoot` · `ProgramFiles` · `ComSpec` 등)를 ND-03 로 막고 다른 변수가 되는 `SYSTEM_ROOT` 를 제안하던 것 (#116) — 예외로 둔다
- JSX 글 `First class shipping included` 를 클래스 선언으로 읽어 ND-04 로 막던 것 (#116) — 뒤에 `{` · `extends` 가 올 때만 선언으로 본다. 줄 끝이면 다음 줄을 본다
- Expo Router 가 읽는 `export const unstable_settings` 를 ND-05 로 막던 것 (#116)

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `node-naming@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/node-naming-rules.md` (`ND-01` ~ `ND-06`)
- 검증기 `scripts/validate-node-naming.sh` — 훅 모드(PreToolUse `Write|Edit` 에서 새로 생긴 위반만 차단)와 CLI 모드(`<파일|디렉터리>` · `--all`)
- `node-name-create` 스킬, `/node-naming-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
