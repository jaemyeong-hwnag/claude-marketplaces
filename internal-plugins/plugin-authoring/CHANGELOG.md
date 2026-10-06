# CHANGELOG

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
