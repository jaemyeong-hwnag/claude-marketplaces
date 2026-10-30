# CHANGELOG

## 0.1.5

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 1건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.4

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 이름 검사 없이 Write · Edit 가 통과하던 것 (#151, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.3

### Fixed
- 텍스트 블록(`"""`) 안의 글(`class handles …`)을 코드로 읽어 JN-02 로 막던 것 (#116) — 블록 주석처럼 줄을 넘어 블록 안을 건너뛴다

## 0.1.2

### Fixed
- 변수 이름 `record` 뒤의 `instanceof` 를 record 선언으로 읽어 JN-02 로 막던 것 (#89) — `record 이름(` · `record 이름<` 일 때만 선언으로 본다
- 메서드 이름의 밑줄을 경로와 상관없이 허용해 main 코드의 `cancel_order()` 를 놓치던 것 (#89) — 테스트 경로(`/test/` · `…Test/` 소스셋 · `*Test.java` · `*Tests.java`)에서만 허용한다

## 0.1.1

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `java-naming@jaemyeong-hwnag-plugins`

## 0.1.0

### Added
- 규칙 원본 `references/java-naming-rules.md` (`JN-01` ~ `JN-06`)
- 검증기 `scripts/validate-java-naming.sh` — 훅 모드(PreToolUse `Write|Edit` 에서 새로 생긴 위반만 차단)와 CLI 모드(`<파일|디렉터리>` · `--all`)
- `java-name-create` 스킬, `/java-naming-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
