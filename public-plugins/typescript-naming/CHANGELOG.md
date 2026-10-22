# CHANGELOG

## 0.1.3

### Fixed
- JSX 글이 `class 단어` · `interface 단어` 로 끝나는 줄(`Join our weekly yoga class today`)을 TS-01 로 막던 것 (#116) — 줄 끝이면 다음 줄이 `{` · `extends` · `implements` · `<` 로 시작할 때만 선언으로 본다
- Expo Router 가 읽는 `export const unstable_settings` 를 TS-03 로 막던 것 (#116)
- Relay 생성 파일(`__generated__/`)의 `HomeQuery$data` 를 막고 원래와 같은 이름을 제안하던 것 (#116) — `__generated__/` 를 제외하고, 제안이 원래 이름과 같으면 제안하지 않는다
- eval `bad-name-blocked` 프롬프트에 "막히면 다시 쓰지 말고" 가 없어, 고친 이름으로 다시 쓰면 `not-created` 그레이더가 실패할 수 있던 것 (#116)

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
