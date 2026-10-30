# CHANGELOG

## 0.3.0

### Added
- `A-29` 세 언어 README 가 서로를 링크한다 · `A-30` 루트 README 세 개가 모든 public 플러그인을 싣는다 (`--all`) (#229)

### Changed
- `A-20` ~ `A-28` 을 `README.md`(영어) · `README.ko.md` · `README.zh-CN.md` 마다 그 언어의 절 제목으로 본다 — 영어판 README 는 `## Installation` · `## Dependencies` … 를 요구한다 (#229)
- README 를 영어 · 한국어 · 중국어 간체로 나눴다. 훅 표의 Pre 대상을 "`Write` 로 쓰는 파일" 로, 조항 범위를 "스킬·커맨드·에이전트·참조" 로 바로잡았다 (#229)

## 0.2.0

### Changed
- 스킬 `document-create` 를 `plugin-document-create` 로 이름을 바꿨다 (#201) — 일반 문서가 아니라 플러그인의 SKILL.md · 커맨드 · 에이전트 · README 를 다룬다는 것이 이름에 드러나게. `/plugin-authoring:document-create` 로 부르던 것은 `/plugin-authoring:plugin-document-create` 로 부른다

## 0.1.5

### Fixed
- `PreToolUse` 훅에 `"onFailure": "block"` — 스크립트가 깨지면 프런트매터 · README 검사 없이 `Write` 가 통과하던 것 (#164, `plugin-enforcement-effectiveness` `EF-07`)

## 0.1.4

### Fixed
- README 절을 나눌 때 코드 펜스 안의 `# 주석` 에서 절이 끝나 A-28 로 막고, 펜스 안 `## …` 도 절 제목으로 세던 것 (#88)
- `--all` 이 플러그인을 하나도 찾지 못해도(마켓플레이스 루트가 아니거나 없는 경로) 통과하던 것을 실행 오류(1)로 낸다 (#88). README 사용 예도 저장소 루트 기준 경로로 고쳤다

## 0.1.3

### Changed
- 마켓플레이스 이름이 `plugin-marketplace` 에서 `jaemyeong-hwnag-plugins` 로 바뀌었다 (#44) — 설치 명령은 `plugin-authoring@jaemyeong-hwnag-plugins`

## 0.1.2

### Fixed
- 스킬만 있거나 커맨드만 있는 플러그인에서 A-22(`## 포함된 스킬` 절 요구)를 놓치던 것 (#8) — `ls` 에 글롭을 여럿 주면 하나만 없어도 실패했다. 픽스처가 늘 둘 다 가져서 드러나지 않았다

## 0.1.1

### Added
- eval 케이스 둘 — 스킬 발동 · 훅 차단 (`evals/`). `plugin-workflow` 의 `eval-all.sh` 로 돈다

## 0.1.0

### Added
- 작성 규칙 원본 `references/authoring-rules.md` (`A-01` ~ `A-09` 스킬·커맨드·에이전트·참조, `A-20` ~ `A-28` README)
- 검증기 `scripts/validate-authoring.sh` — 훅 모드(PreToolUse 차단 · PostToolUse 알림)와 CLI 모드(`--all`)
- `document-create` 스킬, `/authoring-validate` 커맨드
